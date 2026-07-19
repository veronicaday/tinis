begin;

alter table public.venues
  add column if not exists google_place_id text;

create unique index if not exists venues_club_google_place_id_key
  on public.venues(club_id, google_place_id)
  where google_place_id is not null;

drop function if exists public.save_rating(
  uuid, text, text, numeric, numeric, numeric,
  numeric, numeric, text, text, text, numeric
);
drop function if exists public.save_rating(
  uuid, text, text, numeric, numeric, numeric,
  numeric, numeric, text, text, text, numeric, text, text
);

create function public.save_rating(
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
  p_serving_style text default null,
  p_price numeric default null,
  p_google_place_id text default null,
  p_full_address text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_venue_id uuid;
  new_rating_id uuid;
  normalized_place_id text := nullif(trim(p_google_place_id), '');
  normalized_address text := nullif(trim(p_full_address), '');
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
    and (
      (normalized_place_id is not null and google_place_id = normalized_place_id)
      or (
        lower(name) = lower(trim(p_venue_name))
        and lower(city) = lower(trim(coalesce(p_location, '')))
      )
    )
  order by
    case when normalized_place_id is not null and google_place_id = normalized_place_id then 0 else 1 end,
    created_at
  limit 1;

  if target_venue_id is null then
    insert into public.venues (
      club_id, created_by, name, address, city, google_place_id
    ) values (
      p_club_id, auth.uid(), trim(p_venue_name), coalesce(normalized_address, ''),
      trim(coalesce(p_location, '')), normalized_place_id
    )
    returning id into target_venue_id;
  else
    update public.venues
    set
      google_place_id = coalesce(google_place_id, normalized_place_id),
      address = case
        when nullif(address, '') is null then coalesce(normalized_address, address)
        else address
      end
    where id = target_venue_id;
  end if;

  insert into public.ratings (
    club_id, venue_id, user_id, score, dirtiness, chilliness,
    uniqueness, spirit_forward, spirit, garnish, serving_style, price
  ) values (
    p_club_id, target_venue_id, auth.uid(), p_score, p_dirtiness, p_chilliness,
    p_uniqueness, p_spirit_forward, p_spirit, p_garnish, p_serving_style, p_price
  ) returning id into new_rating_id;

  insert into public.personal_venue_ranks (user_id, venue_id)
  values (auth.uid(), target_venue_id)
  on conflict (user_id, venue_id) do nothing;

  return new_rating_id;
end;
$$;

revoke all on function public.save_rating(
  uuid, text, text, numeric, numeric, numeric,
  numeric, numeric, text, text, text, numeric, text, text
) from public, anon;
grant execute on function public.save_rating(
  uuid, text, text, numeric, numeric, numeric,
  numeric, numeric, text, text, text, numeric, text, text
) to authenticated;

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
  ), '{}'::text[]) as companions,
  (select count(*)::integer from public.rating_cheers c where c.rating_id = r.id) as cheers_count,
  exists (
    select 1 from public.rating_cheers c
    where c.rating_id = r.id and c.user_id = auth.uid()
  ) as cheered_by_me,
  v.google_place_id,
  nullif(v.address, '') as full_address
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
    (array_agg(l.user_id order by (l.user_id = auth.uid()) desc, l.visited_at desc))[1] as detail_user_id,
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
  ), '{}'::text[]) as companions,
  s.detail_rating_id,
  s.detail_user_id,
  (s.detail_user_id = auth.uid()) as is_own_rating,
  v.google_place_id,
  nullif(v.address, '') as full_address
from venue_scores s
join club_average a using (club_id)
join public.venues v on v.id = s.venue_id;

grant select on public.friend_feed, public.club_leaderboard to authenticated;

commit;
