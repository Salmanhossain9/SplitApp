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

-- ---------------------------------------------------------------------------
-- Rate limits for the edge functions (scan-receipt): fixed window per user and bucket.
-- ---------------------------------------------------------------------------
create table rate_limits (
  user_id uuid not null,
  bucket text not null,
  window_start timestamptz not null default now(),
  hits int not null default 0,
  primary key (user_id, bucket)
);
alter table rate_limits enable row level security;  -- no policies: service role only
revoke all on rate_limits from anon, authenticated;

create or replace function take_rate_limit(p_user uuid, p_bucket text, p_max int, p_window_seconds int)
returns boolean language plpgsql security definer set search_path = public as $$
declare r rate_limits%rowtype;
begin
  insert into rate_limits (user_id, bucket) values (p_user, p_bucket)
  on conflict (user_id, bucket) do nothing;
  select * into r from rate_limits where user_id = p_user and bucket = p_bucket for update;
  if r.window_start < now() - make_interval(secs => p_window_seconds) then
    update rate_limits set window_start = now(), hits = 1 where user_id = p_user and bucket = p_bucket;
    return true;
  end if;
  if r.hits >= p_max then return false; end if;
  update rate_limits set hits = hits + 1 where user_id = p_user and bucket = p_bucket;
  return true;
end $$;

-- Lock the server functions to the service role.
revoke all on function finalize_bill_apply(uuid, uuid, split_mode, extras_mode, jsonb, jsonb, text) from public, anon, authenticated;
revoke all on function share_view(text) from public, anon, authenticated;
revoke all on function take_rate_limit(uuid, text, int, int) from public, anon, authenticated;
grant execute on function finalize_bill_apply(uuid, uuid, split_mode, extras_mode, jsonb, jsonb, text) to service_role;
grant execute on function share_view(text) to service_role;
grant execute on function take_rate_limit(uuid, text, int, int) to service_role;
