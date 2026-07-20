begin;

-- A venue belongs to the club, not permanently to the member who first added it.
-- Keep shared venue history when that member deletes their account.
alter table public.venues
  drop constraint if exists venues_created_by_fkey;

alter table public.venues
  alter column created_by drop not null;

alter table public.venues
  add constraint venues_created_by_fkey
  foreign key (created_by)
  references public.profiles(id)
  on delete set null;

commit;
