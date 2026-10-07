-- SplitUp database setup. Paste this whole file into the Supabase SQL editor and run it ONCE
-- on a new project. It is generated from supabase/migrations by tool/build_setup_sql.sh.

-- ======================================================================
-- 20260101000001_init.sql
-- ======================================================================
-- SplitUp schema. All money columns are bigint integer poisha (1 taka = 100 poisha).
-- Never numeric or float.

create extension if not exists pgcrypto;

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  email text unique,                       -- copied from auth.users by a trigger, not trusted from the client
  avatar_color text not null default 'lavender' check (avatar_color in ('lavender','lime','sky','coral')),
  bkash_number text,                       -- shown to friends on the share page
  push_token text,                         -- FCM token
  created_at timestamptz not null default now()
);

create table groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) > 0),
  owner_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- A "friend" can be an app user or a guest (name only, maybe phone).
create table friends (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  user_id uuid references profiles(id) on delete set null,   -- null for guests
  name text not null check (length(btrim(name)) > 0),
  phone text,                                                -- optional, unverified, WhatsApp links only
  avatar_color text not null default 'lavender' check (avatar_color in ('lavender','lime','sky','coral')),
  created_at timestamptz not null default now(),
  unique (owner_id, user_id)
);

create table group_members (
  group_id uuid references groups(id) on delete cascade,
  friend_id uuid references friends(id) on delete cascade,
  primary key (group_id, friend_id)
);

create type split_mode as enum ('items','equally','custom');
create type extras_mode as enum ('equally','by_items');
create type bill_status as enum ('draft','open','settled');

create table bills (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references groups(id) on delete set null,
  place text not null check (length(btrim(place)) > 0),
  created_by uuid not null references profiles(id),
  currency text not null default 'BDT',
  subtotal bigint not null default 0 check (subtotal >= 0),
  total bigint not null default 0 check (total >= 0),
  split_mode split_mode not null default 'items',
  extras_mode extras_mode not null default 'equally',
  status bill_status not null default 'draft',
  share_token text unique,                 -- public share link token (22 url-safe chars)
  billed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index bills_created_by_idx on bills (created_by, billed_at desc);

-- Who is on this bill (host included).
create table bill_participants (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references bills(id) on delete cascade,
  friend_id uuid references friends(id) on delete set null,  -- null for the host row
  user_id uuid references profiles(id) on delete set null,   -- set for the host / app users
  name text not null,
  is_host boolean not null default false,
  position int not null default 0,
  in_split boolean not null default true,                    -- "equally" mode: false = not sharing this bill
  custom_amount bigint check (custom_amount is null or custom_amount >= 0)  -- "custom" mode: the typed share
);
create index bill_participants_bill_idx on bill_participants (bill_id);
create index bill_participants_user_idx on bill_participants (user_id) where user_id is not null;
create unique index bill_participants_one_host on bill_participants (bill_id) where is_host;

create table items (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references bills(id) on delete cascade,
  name text not null,
  qty int not null default 1 check (qty > 0),
  unit_price bigint not null check (unit_price >= 0),   -- line total = qty * unit_price
  position int not null default 0
);
create index items_bill_idx on items (bill_id);

create table claims (
  item_id uuid references items(id) on delete cascade,
  participant_id uuid references bill_participants(id) on delete cascade,
  primary key (item_id, participant_id)
);

create type charge_type as enum ('vat','service');
create table charges (
  bill_id uuid references bills(id) on delete cascade,
  type charge_type not null,
  rate_bp int check (rate_bp is null or rate_bp >= 0),   -- basis points (5.9% = 590); null if flat
  amount bigint not null check (amount >= 0),
  primary key (bill_id, type)
);

-- Written only by finalize-bill (service role). The client never writes shares.
create table shares (
  bill_id uuid references bills(id) on delete cascade,
  participant_id uuid references bill_participants(id) on delete cascade,
  items_amount bigint not null default 0 check (items_amount >= 0),
  extras_amount bigint not null default 0 check (extras_amount >= 0),
  total bigint not null default 0 check (total >= 0),
  primary key (bill_id, participant_id)
);

create type pay_method as enum ('cash','bkash','bank','owes_me');
create type settle_status as enum ('pending','paid','tab');
create table settlements (
  bill_id uuid references bills(id) on delete cascade,
  participant_id uuid references bill_participants(id) on delete cascade,
  method pay_method,
  paid_amount bigint not null default 0 check (paid_amount >= 0),
  owed_amount bigint not null default 0 check (owed_amount >= 0),     -- open tab when > 0
  covered_amount bigint not null default 0 check (covered_amount >= 0), -- host cover (stepper)
  status settle_status not null default 'pending',
  settled_at timestamptz,
  last_reminded_at timestamptz,
  primary key (bill_id, participant_id)
);
create index settlements_open_tabs_idx on settlements (bill_id) where owed_amount > 0;

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  kind text not null,                      -- 'remind', 'bill_shared', 'tab_paid'
  payload jsonb not null default '{}',
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on notifications (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- Copy the email from auth.users so the client cannot spoof it.
create or replace function profiles_set_email() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  select email into new.email from auth.users where id = new.id;
  return new;
end $$;
create trigger profiles_set_email_trg before insert on profiles
for each row execute function profiles_set_email();

-- Integrity: shares must add up to the bill total when a bill is opened.
create or replace function assert_shares_sum() returns trigger language plpgsql as $$
declare s bigint;
begin
  if new.status = 'open' and old.status = 'draft' then
    select coalesce(sum(total), 0) into s from shares where bill_id = new.id;
    if s <> new.total or new.total = 0 then
      raise exception 'shares (%) do not add up to bill total (%)', s, new.total;
    end if;
  end if;
  return new;
end $$;
create trigger bills_shares_sum before update on bills
for each row execute function assert_shares_sum();

-- Bills are void-and-recreate after finalize: items, claims, charges and participants
-- only change while the bill is a draft.
create or replace function assert_bill_is_draft() returns trigger language plpgsql as $$
declare b uuid; st bill_status;
begin
  if tg_table_name = 'claims' then
    select i.bill_id into b from items i where i.id = coalesce(new.item_id, old.item_id);
  else
    b := coalesce(new.bill_id, old.bill_id);
  end if;
  select status into st from bills where id = b;
  -- If the parent is gone (cascade delete) there is nothing to protect.
  if st is not null and st <> 'draft' then
    raise exception 'bill % is % and can no longer be edited, void and re-create it', b, st;
  end if;
  return coalesce(new, old);
end $$;
create trigger items_draft_only before insert or update or delete on items
for each row execute function assert_bill_is_draft();
create trigger claims_draft_only before insert or update or delete on claims
for each row execute function assert_bill_is_draft();
create trigger charges_draft_only before insert or update or delete on charges
for each row execute function assert_bill_is_draft();
create trigger participants_draft_only before insert or update or delete on bill_participants
for each row execute function assert_bill_is_draft();

-- ======================================================================
-- 20260101000002_rls.sql
-- ======================================================================
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

-- ======================================================================
-- 20260101000003_realtime.sql
-- ======================================================================
-- The app listens live to these tables: the host's settle screen watches settlements, and the
-- notifications tab watches notifications (RLS still decides who sees which rows).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table settlements;
    alter publication supabase_realtime add table notifications;
  end if;
end $$;

-- ======================================================================
-- 20260101000004_functions.sql
-- ======================================================================
-- Server-side functions. Everything here is callable by the service role only (the edge
-- functions); the app never calls them directly.

-- ---------------------------------------------------------------------------
-- finalize_bill_apply: one transaction that stores the recomputed shares, creates the
-- settlement rows, opens the bill and stores the share token.
-- The edge function does the maths (packages/split) and passes the result in; this function
-- re-checks the invariants so a bug there can never store a bill that does not add up.
-- ---------------------------------------------------------------------------
create or replace function finalize_bill_apply(
  p_bill_id uuid,
  p_user_id uuid,
  p_split_mode split_mode,
  p_extras_mode extras_mode,
  p_charges jsonb,   -- [{type, rate_bp, amount}]
  p_shares jsonb,    -- [{participant_id, items_amount, extras_amount, total}]
  p_token text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  b bills%rowtype;
  v_subtotal bigint;
  v_extras bigint;
  v_total bigint;
  v_sum bigint;
  v_count int;
begin
  select * into b from bills where id = p_bill_id for update;
  if not found then raise exception 'bill not found'; end if;
  if b.created_by <> p_user_id then raise exception 'not your bill'; end if;
  if b.status <> 'draft' then raise exception 'bill is already %', b.status; end if;
  if p_token is null or length(p_token) < 16 then raise exception 'bad share token'; end if;

  select coalesce(sum(qty::bigint * unit_price), 0) into v_subtotal from items where bill_id = p_bill_id;
  if v_subtotal = 0 then raise exception 'bill has no items'; end if;

  delete from charges where bill_id = p_bill_id;
  insert into charges (bill_id, type, rate_bp, amount)
  select p_bill_id, (c->>'type')::charge_type, nullif(c->>'rate_bp','')::int, (c->>'amount')::bigint
  from jsonb_array_elements(p_charges) c;
  select coalesce(sum(amount), 0) into v_extras from charges where bill_id = p_bill_id;
  v_total := v_subtotal + v_extras;

  -- Every share must belong to this bill, and exactly one per participant.
  select count(*) into v_count from bill_participants where bill_id = p_bill_id;
  if jsonb_array_length(p_shares) <> v_count then
    raise exception 'expected % shares, got %', v_count, jsonb_array_length(p_shares);
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_shares) s
    where not exists (
      select 1 from bill_participants bp
      where bp.bill_id = p_bill_id and bp.id = (s->>'participant_id')::uuid)
  ) then
    raise exception 'share for a participant that is not on this bill';
  end if;

  delete from shares where bill_id = p_bill_id;
  insert into shares (bill_id, participant_id, items_amount, extras_amount, total)
  select p_bill_id, (s->>'participant_id')::uuid, (s->>'items_amount')::bigint,
         (s->>'extras_amount')::bigint, (s->>'total')::bigint
  from jsonb_array_elements(p_shares) s;

  select coalesce(sum(total), 0) into v_sum from shares where bill_id = p_bill_id;
  if v_sum <> v_total then
    raise exception 'shares (%) do not add up to bill total (%)', v_sum, v_total;
  end if;
  if exists (select 1 from shares where total <> items_amount + extras_amount and bill_id = p_bill_id) then
    raise exception 'a share total differs from items + extras';
  end if;

  -- One settlement per friend. The host paid at the restaurant, so the host has none.
  delete from settlements where bill_id = p_bill_id;
  insert into settlements (bill_id, participant_id)
  select p_bill_id, bp.id from bill_participants bp where bp.bill_id = p_bill_id and not bp.is_host;

  update bills
     set subtotal = v_subtotal, total = v_total, split_mode = p_split_mode,
         extras_mode = p_extras_mode, share_token = p_token, status = 'open'
   where id = p_bill_id;

  return jsonb_build_object('bill_id', p_bill_id, 'subtotal', v_subtotal, 'total', v_total, 'share_token', p_token);
end $$;

-- ---------------------------------------------------------------------------
-- Settlements stay consistent with the share they settle.
--   method null            -> pending, nothing paid or owed
--   method set             -> paid + owed must equal the friend's share
--   owed > 0               -> tab
-- ---------------------------------------------------------------------------
create or replace function settlements_consistency() returns trigger language plpgsql as $$
declare share_total bigint;
begin
  select total into share_total from shares where bill_id = new.bill_id and participant_id = new.participant_id;
  if share_total is null then raise exception 'no share for this participant'; end if;

  if new.method is null then
    new.paid_amount := 0; new.owed_amount := 0; new.covered_amount := 0;
    new.status := 'pending'; new.settled_at := null;
  else
    if new.paid_amount + new.owed_amount <> share_total then
      raise exception 'paid (%) + owed (%) must equal the share (%)', new.paid_amount, new.owed_amount, share_total;
    end if;
    if new.covered_amount > share_total then raise exception 'cover is more than the share'; end if;
    new.status := case when new.owed_amount > 0 then 'tab' else 'paid' end;
    new.settled_at := coalesce(new.settled_at, now());
  end if;
  return new;
end $$;
create trigger settlements_consistency_trg before update on settlements
for each row execute function settlements_consistency();

-- ---------------------------------------------------------------------------
-- share_view: what the public share page may show. No emails, no phone numbers.
-- ---------------------------------------------------------------------------
create or replace function share_view(p_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'place', b.place,
    'currency', b.currency,
    'billed_at', b.billed_at,
    'status', b.status,
    'subtotal', b.subtotal,
    'total', b.total,
    'host_name', host.name,
    'host_bkash', hp.bkash_number,
    'people', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', bp.name,
        'is_host', bp.is_host,
        'items_amount', s.items_amount,
        'extras_amount', s.extras_amount,
        'total', s.total,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object('name', i.name, 'qty', i.qty) order by i.position)
          from claims c join items i on i.id = c.item_id
          where c.participant_id = bp.id), '[]'::jsonb)
      ) order by bp.position)
      from bill_participants bp join shares s on s.participant_id = bp.id and s.bill_id = b.id
      where bp.bill_id = b.id), '[]'::jsonb)
  )
  from bills b
  join bill_participants host on host.bill_id = b.id and host.is_host
  left join profiles hp on hp.id = b.created_by
  where b.share_token = p_token and b.status in ('open', 'settled');
$$;

-- Lock the server functions to the service role.
revoke all on function finalize_bill_apply(uuid, uuid, split_mode, extras_mode, jsonb, jsonb, text) from public, anon, authenticated;
revoke all on function share_view(text) from public, anon, authenticated;
grant execute on function finalize_bill_apply(uuid, uuid, split_mode, extras_mode, jsonb, jsonb, text) to service_role;
grant execute on function share_view(text) to service_role;
