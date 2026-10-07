-- Receipt photos: private bucket, path {user_id}/{bill_id}/{file}. Only the owner can touch
-- their folder. The scan-receipt function reads with the service role.
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

create policy receipts_owner_select on storage.objects for select
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy receipts_owner_insert on storage.objects for insert
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy receipts_owner_update on storage.objects for update
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy receipts_owner_delete on storage.objects for delete
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);

-- The host app listens to settlements for the bill on screen.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table settlements;
  end if;
end $$;
