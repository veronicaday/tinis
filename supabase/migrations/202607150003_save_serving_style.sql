begin;

drop function if exists public.save_rating(
  uuid, text, text, numeric, numeric, numeric,
  numeric, numeric, text, text, numeric
);

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
  p_serving_style text default null,
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
  numeric, numeric, text, text, text, numeric
) from public, anon;

grant execute on function public.save_rating(
  uuid, text, text, numeric, numeric, numeric,
  numeric, numeric, text, text, text, numeric
) to authenticated;

commit;
