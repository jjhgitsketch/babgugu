-- BabGuGu storage buckets and policies
-- Safe to run repeatedly.

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('meeting-images', 'meeting-images', true),
  ('settlement-images', 'settlement-images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "avatars public read" on storage.objects;
drop policy if exists "avatars upload" on storage.objects;
drop policy if exists "avatars update" on storage.objects;
drop policy if exists "meeting images public read" on storage.objects;
drop policy if exists "meeting images upload" on storage.objects;
drop policy if exists "meeting images update" on storage.objects;
drop policy if exists "settlement images public read" on storage.objects;
drop policy if exists "settlement images upload" on storage.objects;
drop policy if exists "settlement images update" on storage.objects;

create policy "avatars public read"
on storage.objects for select
using (bucket_id = 'avatars');

create policy "avatars upload"
on storage.objects for insert
to authenticated
with check (bucket_id = 'avatars');

create policy "avatars update"
on storage.objects for update
to authenticated
using (bucket_id = 'avatars')
with check (bucket_id = 'avatars');

create policy "meeting images public read"
on storage.objects for select
using (bucket_id = 'meeting-images');

create policy "meeting images upload"
on storage.objects for insert
to authenticated
with check (bucket_id = 'meeting-images');

create policy "meeting images update"
on storage.objects for update
to authenticated
using (bucket_id = 'meeting-images')
with check (bucket_id = 'meeting-images');

create policy "settlement images public read"
on storage.objects for select
using (bucket_id = 'settlement-images');

create policy "settlement images upload"
on storage.objects for insert
to authenticated
with check (bucket_id = 'settlement-images');

create policy "settlement images update"
on storage.objects for update
to authenticated
using (bucket_id = 'settlement-images')
with check (bucket_id = 'settlement-images');