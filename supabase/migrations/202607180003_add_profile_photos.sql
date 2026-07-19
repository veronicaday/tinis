begin;

alter table public.profiles
  add column if not exists avatar_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos',
  'profile-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists profile_photos_read_club on storage.objects;
create policy profile_photos_read_club on storage.objects
for select to authenticated
using (
  bucket_id = 'profile-photos'
  and exists (
    select 1
    from public.profiles p
    where p.avatar_path = storage.objects.name
      and public.shares_club_with(p.id)
  )
);

drop policy if exists profile_photos_insert_self on storage.objects;
create policy profile_photos_insert_self on storage.objects
for insert to authenticated
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists profile_photos_update_self on storage.objects;
create policy profile_photos_update_self on storage.objects
for update to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists profile_photos_delete_self on storage.objects;
create policy profile_photos_delete_self on storage.objects
for delete to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

commit;
