begin;

update public.club_invites invite
set code_hash = extensions.crypt('DIRTY', extensions.gen_salt('bf'))
from public.clubs club
where invite.club_id = club.id
  and club.name = 'tini''s martini club';

commit;
