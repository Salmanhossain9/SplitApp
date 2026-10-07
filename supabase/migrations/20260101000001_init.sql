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
  receipt_path text,                       -- storage path in the private receipts bucket
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
