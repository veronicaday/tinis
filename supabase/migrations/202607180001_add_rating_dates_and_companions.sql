begin;

create table if not exists public.rating_companions (
  rating_id uuid not null references public.ratings(id) on delete cascade,
  companion_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (rating_id, companion_id)
);

alter table public.rating_companions enable row level security;

create policy rating_companions_read_club on public.rating_companions
for select to authenticated
using (
  exists (
    select 1 from public.ratings r
    where r.id = rating_companions.rating_id
      and public.is_club_member(r.club_id)
  )
);

create policy rating_companions_insert_self on public.rating_companions
for insert to authenticated
with check (
  exists (
    select 1
    from public.ratings r
    join public.club_memberships companion_membership
      on companion_membership.club_id = r.club_id
     and companion_membership.user_id = rating_companions.companion_id
    where r.id = rating_companions.rating_id
      and r.user_id = auth.uid()
  )
);

create policy rating_companions_delete_self on public.rating_companions
for delete to authenticated
using (
  exists (
    select 1 from public.ratings r
    where r.id = rating_companions.rating_id
      and r.user_id = auth.uid()
  )
);

grant select, insert, delete on public.rating_companions to authenticated;

create or replace view public.friend_feed with (security_invoker = true) as
select
  r.id, r.club_id, r.user_id, p.display_name, p.avatar_path,
  r.venue_id, v.name as venue_name, v.city, v.region, r.score,
  r.dirtiness, r.chilliness, r.uniqueness, r.spirit_forward,
  r.public_note, r.photo_path, r.visited_at, r.created_at,
  r.spirit, r.garnish, r.serving_style, r.price,
  coalesce((
    select array_agg(companion.display_name order by companion.display_name)
    from public.rating_companions rc
    join public.profiles companion on companion.id = rc.companion_id
    where rc.rating_id = r.id
  ), '{}'::text[]) as companions
from public.ratings r
join public.profiles p on p.id = r.user_id
join public.venues v on v.id = r.venue_id;

create or replace view public.club_leaderboard with (security_invoker = true) as
with latest_per_member as (
  select distinct on (r.club_id, r.user_id, r.venue_id)
    r.id as rating_id, r.club_id, r.user_id, r.venue_id, r.score, r.dirtiness,
    r.chilliness, r.uniqueness, r.spirit_forward, r.spirit,
    r.garnish, r.serving_style, r.price, r.public_note, r.visited_at
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
    avg(l.spirit_forward)::numeric as spirit_forward,
    (array_agg(l.rating_id order by (l.user_id = auth.uid()) desc, l.visited_at desc))[1] as detail_rating_id,
    (array_agg(l.spirit order by (l.user_id = auth.uid()) desc, l.visited_at desc))[1] as spirit,
    (array_agg(l.garnish order by (l.user_id = auth.uid()) desc, l.visited_at desc))[1] as garnish,
    (array_agg(l.serving_style order by (l.user_id = auth.uid()) desc, l.visited_at desc))[1] as serving_style,
    (array_agg(l.price order by (l.user_id = auth.uid()) desc, l.visited_at desc))[1] as price,
    (array_agg(l.public_note order by (l.user_id = auth.uid()) desc, l.visited_at desc))[1] as public_note,
    max(l.visited_at) as latest_visit
  from latest_per_member l group by l.club_id, l.venue_id
)
select s.club_id, s.venue_id, v.name as venue_name, v.city, v.region,
  round(((s.score_sum + (2 * a.score)) / (s.rating_count + 2)), 1) as score,
  s.rating_count, round(s.dirtiness, 1) as dirtiness,
  round(s.chilliness, 1) as chilliness, round(s.uniqueness, 1) as uniqueness,
  round(s.spirit_forward, 1) as spirit_forward,
  s.latest_visit, s.spirit, s.garnish, s.serving_style, s.price, s.public_note,
  coalesce((
    select array_agg(companion.display_name order by companion.display_name)
    from public.rating_companions rc
    join public.profiles companion on companion.id = rc.companion_id
    where rc.rating_id = s.detail_rating_id
  ), '{}'::text[]) as companions
from venue_scores s
join club_average a using (club_id)
join public.venues v on v.id = s.venue_id;

grant select on public.friend_feed, public.club_leaderboard to authenticated;

commit;
