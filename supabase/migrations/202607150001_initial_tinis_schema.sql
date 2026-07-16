-- tini's v1 backend
-- Run this once in the Supabase SQL editor, or apply it with the Supabase CLI.

begin;

create extension if not exists pgcrypto with schema extensions;

create type public.club_role as enum ('owner', 'member');
create type public.report_status as enum ('open', 'reviewed', 'closed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  created_at timestamptz not null default now()
);

create table public.club_memberships (
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.club_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

create table public.club_invites (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  code_hash text not null,
  max_uses integer not null default 10 check (max_uses > 0),
  uses integer not null default 0 check (uses >= 0),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.venues (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  created_by uuid not null default auth.uid() references public.profiles(id),
  name text not null check (char_length(name) between 1 and 120),
  address text not null default '',
  city text not null default '',
  region text not null default '',
  latitude double precision,
  longitude double precision,
  mapkit_identifier text,
  created_at timestamptz not null default now()
);

create unique index venues_club_mapkit_identifier_key
  on public.venues(club_id, mapkit_identifier)
  where mapkit_identifier is not null;

create index venues_club_name_idx on public.venues(club_id, lower(name));

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  score numeric(3,1) not null check (score between 1.0 and 10.0),
  dirtiness numeric(2,1) check (dirtiness between 0 and 4),
  chilliness numeric(2,1) check (chilliness between 0 and 4),
  uniqueness numeric(2,1) check (uniqueness between 0 and 4),
  spirit_forward numeric(2,1) check (spirit_forward between 0 and 4),
  spirit text check (spirit in ('gin', 'vodka', 'both', 'unknown')),
  garnish text,
  serving_style text check (serving_style in ('up', 'rocks', 'other')),
  price numeric(8,2) check (price is null or price >= 0),
  would_order_again boolean,
  public_note text check (char_length(public_note) <= 500),
  photo_path text,
  visited_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index ratings_club_created_idx on public.ratings(club_id, created_at desc);
create index ratings_user_venue_visited_idx on public.ratings(user_id, venue_id, visited_at desc);

create table public.rating_private_notes (
  rating_id uuid primary key references public.ratings(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  note text not null check (char_length(note) <= 2000),
  updated_at timestamptz not null default now()
);

create table public.personal_venue_ranks (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  elo integer not null default 1500 check (elo between 0 and 4000),
  comparison_count integer not null default 0 check (comparison_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, venue_id)
);

create table public.comparisons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  new_venue_id uuid not null references public.venues(id) on delete cascade,
  past_venue_id uuid not null references public.venues(id) on delete cascade,
  result text not null check (result in ('new', 'past', 'tie')),
  created_at timestamptz not null default now(),
  check (new_venue_id <> past_venue_id)
);

create table public.blocks (
  blocker_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  rating_id uuid references public.ratings(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  reason text not null check (char_length(reason) between 1 and 500),
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  check (rating_id is not null or reported_user_id is not null)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger ratings_set_updated_at before update on public.ratings
for each row execute function public.set_updated_at();
create trigger private_notes_set_updated_at before update on public.rating_private_notes
for each row execute function public.set_updated_at();
create trigger ranks_set_updated_at before update on public.personal_venue_ranks
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      split_part(coalesce(new.email, 'martini-lover'), '@', 1)
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_club_member(requested_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.club_memberships
    where club_id = requested_club_id and user_id = auth.uid()
  );
$$;

create or replace function public.shares_club_with(other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() = other_user_id or exists (
    select 1
    from public.club_memberships mine
    join public.club_memberships theirs using (club_id)
    where mine.user_id = auth.uid() and theirs.user_id = other_user_id
  );
$$;

create or replace function public.join_club(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  matched_invite public.club_invites%rowtype;
  assigned_role public.club_role;
begin
  if auth.uid() is null then raise exception 'You must be signed in'; end if;

  select * into matched_invite
  from public.club_invites
  where extensions.crypt(upper(trim(invite_code)), code_hash) = code_hash
    and uses < max_uses
    and (expires_at is null or expires_at > now())
  order by created_at desc
  limit 1
  for update;

  if matched_invite.id is null then
    raise exception 'That invite code is invalid or expired';
  end if;

  if exists (
    select 1 from public.club_memberships
    where club_id = matched_invite.club_id and user_id = auth.uid()
  ) then
    return matched_invite.club_id;
  end if;

  select case when exists (
    select 1 from public.club_memberships where club_id = matched_invite.club_id
  ) then 'member'::public.club_role else 'owner'::public.club_role end
  into assigned_role;

  insert into public.club_memberships (club_id, user_id, role)
  values (matched_invite.club_id, auth.uid(), assigned_role);
  update public.club_invites set uses = uses + 1 where id = matched_invite.id;
  return matched_invite.club_id;
end;
$$;

create or replace function public.save_rating(
  p_club_id uuid,
  p_venue_name text,
  p_location text,
  p_score numeric,
  p_dirtiness numeric default null,
  p_chilliness numeric default null,
  p_uniqueness numeric default null,
  p_spirit_forward numeric default null,
  p_spirit text default null,
  p_garnish text default null,
  p_price numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_venue_id uuid;
  new_rating_id uuid;
begin
  if auth.uid() is null or not public.is_club_member(p_club_id) then
    raise exception 'You are not a member of this club';
  end if;
  if nullif(trim(p_venue_name), '') is null then
    raise exception 'A venue name is required';
  end if;

  select id into target_venue_id
  from public.venues
  where club_id = p_club_id
    and lower(name) = lower(trim(p_venue_name))
    and lower(city) = lower(trim(coalesce(p_location, '')))
  order by created_at
  limit 1;

  if target_venue_id is null then
    insert into public.venues (club_id, created_by, name, city)
    values (p_club_id, auth.uid(), trim(p_venue_name), trim(coalesce(p_location, '')))
    returning id into target_venue_id;
  end if;

  insert into public.ratings (
    club_id, venue_id, user_id, score, dirtiness, chilliness,
    uniqueness, spirit_forward, spirit, garnish, price
  ) values (
    p_club_id, target_venue_id, auth.uid(), p_score, p_dirtiness, p_chilliness,
    p_uniqueness, p_spirit_forward, p_spirit, p_garnish, p_price
  ) returning id into new_rating_id;

  insert into public.personal_venue_ranks (user_id, venue_id)
  values (auth.uid(), target_venue_id)
  on conflict (user_id, venue_id) do nothing;

  return new_rating_id;
end;
$$;

alter table public.profiles enable row level security;
alter table public.clubs enable row level security;
alter table public.club_memberships enable row level security;
alter table public.club_invites enable row level security;
alter table public.venues enable row level security;
alter table public.ratings enable row level security;
alter table public.rating_private_notes enable row level security;
alter table public.personal_venue_ranks enable row level security;
alter table public.comparisons enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;

create policy profiles_read_club on public.profiles for select to authenticated
using (public.shares_club_with(id));
create policy profiles_update_self on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());
create policy clubs_read_members on public.clubs for select to authenticated
using (public.is_club_member(id));
create policy memberships_read_members on public.club_memberships for select to authenticated
using (public.is_club_member(club_id));
create policy invites_owner_read on public.club_invites for select to authenticated
using (exists (
  select 1 from public.club_memberships
  where club_id = club_invites.club_id and user_id = auth.uid() and role = 'owner'
));
create policy venues_read_members on public.venues for select to authenticated
using (public.is_club_member(club_id));
create policy venues_insert_members on public.venues for insert to authenticated
with check (created_by = auth.uid() and public.is_club_member(club_id));
create policy venues_update_members on public.venues for update to authenticated
using (public.is_club_member(club_id)) with check (public.is_club_member(club_id));
create policy ratings_read_members on public.ratings for select to authenticated
using (public.is_club_member(club_id));
create policy ratings_insert_self on public.ratings for insert to authenticated
with check (
  user_id = auth.uid() and public.is_club_member(club_id)
  and exists (select 1 from public.venues where id = ratings.venue_id and club_id = ratings.club_id)
);
create policy ratings_update_self on public.ratings for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid() and public.is_club_member(club_id));
create policy ratings_delete_self on public.ratings for delete to authenticated
using (user_id = auth.uid());
create policy private_notes_self on public.rating_private_notes for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy ranks_read_club on public.personal_venue_ranks for select to authenticated
using (public.shares_club_with(user_id));
create policy ranks_write_self on public.personal_venue_ranks for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy comparisons_self on public.comparisons for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy blocks_self on public.blocks for all to authenticated
using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy reports_insert_self on public.reports for insert to authenticated
with check (reporter_id = auth.uid());
create policy reports_read_self on public.reports for select to authenticated
using (reporter_id = auth.uid());

create or replace view public.friend_feed with (security_invoker = true) as
select
  r.id, r.club_id, r.user_id, p.display_name, p.avatar_path,
  r.venue_id, v.name as venue_name, v.city, v.region, r.score,
  r.dirtiness, r.chilliness, r.uniqueness, r.spirit_forward,
  r.public_note, r.photo_path, r.visited_at, r.created_at
from public.ratings r
join public.profiles p on p.id = r.user_id
join public.venues v on v.id = r.venue_id;

create or replace view public.club_leaderboard with (security_invoker = true) as
with latest_per_member as (
  select distinct on (r.club_id, r.user_id, r.venue_id)
    r.club_id, r.user_id, r.venue_id, r.score, r.dirtiness,
    r.chilliness, r.uniqueness, r.spirit_forward, r.visited_at
  from public.ratings r
  order by r.club_id, r.user_id, r.venue_id, r.visited_at desc, r.created_at desc
),
club_average as (
  select club_id, avg(score)::numeric as score from latest_per_member group by club_id
),
venue_scores as (
  select l.club_id, l.venue_id, count(*)::integer as rating_count,
    sum(l.score)::numeric as score_sum, avg(l.dirtiness)::numeric as dirtiness,
    avg(l.chilliness)::numeric as chilliness, avg(l.uniqueness)::numeric as uniqueness,
    avg(l.spirit_forward)::numeric as spirit_forward, max(l.visited_at) as latest_visit
  from latest_per_member l group by l.club_id, l.venue_id
)
select s.club_id, s.venue_id, v.name as venue_name, v.city, v.region,
  round(((s.score_sum + (2 * a.score)) / (s.rating_count + 2)), 1) as score,
  s.rating_count, round(s.dirtiness, 1) as dirtiness,
  round(s.chilliness, 1) as chilliness, round(s.uniqueness, 1) as uniqueness,
  round(s.spirit_forward, 1) as spirit_forward, s.latest_visit
from venue_scores s
join club_average a using (club_id)
join public.venues v on v.id = s.venue_id;

revoke all on all tables in schema public from anon;
grant select, insert, update, delete on public.profiles to authenticated;
grant select on public.clubs, public.club_memberships, public.club_invites to authenticated;
grant select, insert, update, delete on public.venues, public.ratings,
  public.rating_private_notes, public.personal_venue_ranks, public.comparisons,
  public.blocks, public.reports to authenticated;
grant select on public.friend_feed, public.club_leaderboard to authenticated;
revoke all on function public.join_club(text) from public, anon;
grant execute on function public.join_club(text) to authenticated;
revoke all on function public.save_rating(uuid, text, text, numeric, numeric, numeric, numeric, numeric, text, text, numeric) from public, anon;
grant execute on function public.save_rating(uuid, text, text, numeric, numeric, numeric, numeric, numeric, text, text, numeric) to authenticated;

insert into public.clubs (name) values ('tini''s martini club');
insert into public.club_invites (club_id, code_hash, max_uses)
select id, extensions.crypt('DIRTY', extensions.gen_salt('bf')), 10
from public.clubs where name = 'tini''s martini club';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('rating-photos', 'rating-photos', false, 10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif'])
on conflict (id) do nothing;

create policy rating_photos_read_club on storage.objects for select to authenticated
using (bucket_id = 'rating-photos'
  and public.is_club_member(((storage.foldername(name))[1])::uuid));
create policy rating_photos_insert_self on storage.objects for insert to authenticated
with check (bucket_id = 'rating-photos'
  and public.is_club_member(((storage.foldername(name))[1])::uuid)
  and (storage.foldername(name))[2] = auth.uid()::text);
create policy rating_photos_update_self on storage.objects for update to authenticated
using (bucket_id = 'rating-photos' and (storage.foldername(name))[2] = auth.uid()::text)
with check (bucket_id = 'rating-photos' and (storage.foldername(name))[2] = auth.uid()::text);
create policy rating_photos_delete_self on storage.objects for delete to authenticated
using (bucket_id = 'rating-photos' and (storage.foldername(name))[2] = auth.uid()::text);

commit;
