-- Row Level Security on every table. The app talks to Postgres directly, so these policies
-- are the access control. Guests never touch the database: they use the share-view function.

-- Helper functions are security definer so policies can look across tables without
-- recursing into each other's RLS. They only ever answer questions about auth.uid().
create or replace function is_bill_owner(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from bills where id = b and created_by = auth.uid());
$$;

create or replace function is_bill_participant(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from bill_participants where bill_id = b and user_id = auth.uid());
$$;

create or replace function can_read_bill(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_bill_owner(b) or is_bill_participant(b);
$$;

create or replace function owns_group(g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from groups where id = g and owner_id = auth.uid());
$$;

create or replace function owns_friend(f uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from friends where id = f and owner_id = auth.uid());
$$;

create or replace function item_bill(i uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select bill_id from items where id = i;
$$;

alter table profiles enable row level security;
alter table groups enable row level security;
alter table friends enable row level security;
alter table group_members enable row level security;
alter table bills enable row level security;
alter table bill_participants enable row level security;
alter table items enable row level security;
alter table claims enable row level security;
alter table charges enable row level security;
alter table shares enable row level security;
alter table settlements enable row level security;
alter table notifications enable row level security;

-- profiles: own row only. Other people's name and colour come through public_profiles.
create policy profiles_select_own on profiles for select using (id = auth.uid());
create policy profiles_insert_own on profiles for insert with check (id = auth.uid());
create policy profiles_update_own on profiles for update using (id = auth.uid()) with check (id = auth.uid());

create view public_profiles as
select p.id, p.name, p.avatar_color
from profiles p
where p.id = auth.uid()
   or exists (
        select 1
        from bills b join bill_participants bp on bp.bill_id = b.id
        where (b.created_by = p.id and bp.user_id = auth.uid())
           or (b.created_by = auth.uid() and bp.user_id = p.id)
           or (bp.user_id = p.id and exists (
                 select 1 from bill_participants me where me.bill_id = b.id and me.user_id = auth.uid()))
      );

-- friends, groups, group_members: owner only.
create policy friends_all_own on friends for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy groups_all_own on groups for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy group_members_all_own on group_members for all
  using (owns_group(group_id)) with check (owns_group(group_id) and owns_friend(friend_id));

-- bills: the creator has full access, app-user participants read only.
create policy bills_select on bills for select using (created_by = auth.uid() or is_bill_participant(id));
create policy bills_insert on bills for insert with check (created_by = auth.uid());
create policy bills_update on bills for update using (created_by = auth.uid()) with check (created_by = auth.uid());
create policy bills_delete on bills for delete using (created_by = auth.uid());

create policy participants_select on bill_participants for select using (can_read_bill(bill_id));
create policy participants_write on bill_participants for all
  using (is_bill_owner(bill_id)) with check (is_bill_owner(bill_id));

create policy items_select on items for select using (can_read_bill(bill_id));
create policy items_write on items for all
  using (is_bill_owner(bill_id)) with check (is_bill_owner(bill_id));

create policy claims_select on claims for select using (can_read_bill(item_bill(item_id)));
create policy claims_write on claims for all
  using (is_bill_owner(item_bill(item_id))) with check (is_bill_owner(item_bill(item_id)));

create policy charges_select on charges for select using (can_read_bill(bill_id));
create policy charges_write on charges for all
  using (is_bill_owner(bill_id)) with check (is_bill_owner(bill_id));

-- shares: read only for everyone. The owner sees all of them, a participant only their own.
-- There is no insert/update/delete policy: only the service role (finalize-bill) writes shares.
create policy shares_select on shares for select using (
  is_bill_owner(bill_id)
  or participant_id in (select id from bill_participants where bill_id = shares.bill_id and user_id = auth.uid())
);

-- settlements: the host reads and updates (ticking off cash/bKash/bank, covers, tabs).
-- A participant reads only their own row. Rows are created by finalize-bill.
create policy settlements_select on settlements for select using (
  is_bill_owner(bill_id)
  or participant_id in (select id from bill_participants where bill_id = settlements.bill_id and user_id = auth.uid())
);
create policy settlements_update on settlements for update
  using (is_bill_owner(bill_id)) with check (is_bill_owner(bill_id));

-- notifications: the owner reads them and marks them read. Rows are inserted by send-reminders.
create policy notifications_select_own on notifications for select using (user_id = auth.uid());
create policy notifications_update_own on notifications for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Grants. Supabase's anon/authenticated roles get nothing by default beyond RLS-guarded
-- table access; make that explicit and keep write access off the server-owned tables.
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
grant select on public_profiles to authenticated;
grant select, insert, update, delete on profiles, groups, friends, group_members,
  bills, bill_participants, items, claims, charges to authenticated;
grant select on shares to authenticated;
grant select, update on settlements to authenticated;
grant select, update on notifications to authenticated;
revoke insert, update, delete on shares from authenticated;
revoke insert, delete on settlements from authenticated;
revoke delete on profiles from authenticated;
