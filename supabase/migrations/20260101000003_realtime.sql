-- The app listens live to these tables: the host's settle screen watches settlements, and the
-- notifications tab watches notifications (RLS still decides who sees which rows).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table settlements;
    alter publication supabase_realtime add table notifications;
  end if;
end $$;
