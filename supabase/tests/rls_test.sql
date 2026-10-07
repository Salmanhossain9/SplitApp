-- RLS and server function tests. Plain SQL (no pgTAP) so they run on any Postgres and against
-- `supabase start`. Every check prints "ok - ..." or aborts the run with "not ok - ...".
\set ON_ERROR_STOP on
set client_min_messages = notice;

create schema t;
grant usage on schema t to public;

create function t.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is not true then raise exception 'not ok - %', msg; end if;
  raise notice 'ok - %', msg;
end $$;

-- The statement must raise an error whose message contains `pattern`.
create function t.throws(q text, pattern text, msg text) returns void language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    if position(lower(pattern) in lower(sqlerrm)) = 0 then
      raise exception 'not ok - % (wrong error: %)', msg, sqlerrm;
    end if;
    raise notice 'ok - % [%]', msg, sqlerrm;
    return;
  end;
  raise exception 'not ok - % (expected an error)', msg;
end $$;

-- The statement must succeed but touch exactly n rows (RLS hides rows instead of raising).
create function t.affects(q text, n int, msg text) returns void language plpgsql as $$
declare c int;
begin
  execute q;
  get diagnostics c = row_count;
  if c <> n then raise exception 'not ok - % (touched % rows, wanted %)', msg, c, n; end if;
  raise notice 'ok - %', msg;
end $$;

create function t.as_user(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', uid::text, false);
  execute 'set role authenticated';
end $$;

create function t.as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', false);
  execute 'set role anon';
end $$;

create function t.as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', false);
  execute 'set role service_role';
end $$;

-- ---------------------------------------------------------------------------
-- Fixtures. Alice hosts, Bob is an app user on the bill, Rafi is a guest, Carol is a stranger.
-- ---------------------------------------------------------------------------
\set a '''00000000-0000-0000-0000-00000000000a'''
\set b '''00000000-0000-0000-0000-00000000000b'''
\set c '''00000000-0000-0000-0000-00000000000c'''
\set d '''00000000-0000-0000-0000-00000000000d'''
\set bill '''11111111-1111-1111-1111-111111111111'''
\set bill2 '''22222222-2222-2222-2222-222222222222'''
\set bill4 '''44444444-4444-4444-4444-444444444444'''
\set bill5 '''55555555-5555-5555-5555-555555555555'''
\set pa '''a0000000-0000-0000-0000-000000000001'''
\set pb '''a0000000-0000-0000-0000-000000000002'''
\set pr '''a0000000-0000-0000-0000-000000000003'''
\set fb '''f0000000-0000-0000-0000-000000000001'''
\set fr '''f0000000-0000-0000-0000-000000000002'''
\set tok '''TOKEN_abcdefghijklmnop'''

insert into auth.users values (:a, 'alice@x.test'), (:b, 'bob@x.test'), (:c, 'carol@x.test'), (:d, 'dave@x.test');
insert into profiles (id, name, bkash_number) values
  (:a, 'Alice', '01700000000'), (:b, 'Bob', null), (:c, 'Carol', null);

-- Alice builds her data through RLS, as the app would.
select t.as_user(:a);
insert into friends (id, owner_id, user_id, name, phone) values
  (:fb, :a, :b, 'Bob', null), (:fr, :a, null, 'Rafi', '01811111111');
insert into groups (id, name, owner_id) values ('90000000-0000-0000-0000-000000000001', 'NSU boys', :a);
insert into group_members values ('90000000-0000-0000-0000-000000000001', :fb), ('90000000-0000-0000-0000-000000000001', :fr);
insert into bills (id, place, created_by) values (:bill, 'Chillox', :a), (:bill2, 'Pizza Roma', :a), (:bill4, 'Star Kabab', :a);
insert into bill_participants (id, bill_id, friend_id, user_id, name, is_host, position) values
  (:pa, :bill, null, :a, 'Alice', true, 0),
  (:pb, :bill, :fb, :b, 'Bob', false, 1),
  (:pr, :bill, :fr, null, 'Rafi', false, 2);
insert into items (id, bill_id, name, qty, unit_price, position) values
  ('c0000000-0000-0000-0000-000000000001', :bill, 'Chicken burger', 1, 34500, 0),
  ('c0000000-0000-0000-0000-000000000002', :bill, 'Beef kala bhuna', 1, 114500, 1),
  ('c0000000-0000-0000-0000-000000000003', :bill, 'Coke', 3, 9000, 2);
insert into claims values
  ('c0000000-0000-0000-0000-000000000001', :pa),
  ('c0000000-0000-0000-0000-000000000002', :pb), ('c0000000-0000-0000-0000-000000000002', :pr),
  ('c0000000-0000-0000-0000-000000000003', :pa), ('c0000000-0000-0000-0000-000000000003', :pb), ('c0000000-0000-0000-0000-000000000003', :pr);
-- bill2: only Alice and the guest, still a draft. bill4: for the finalize guard tests.
insert into bill_participants (id, bill_id, user_id, name, is_host) values
  ('a0000000-0000-0000-0000-000000000011', :bill2, :a, 'Alice', true);
insert into items (bill_id, name, unit_price) values (:bill2, 'Margherita', 90000);
insert into bill_participants (id, bill_id, user_id, name, is_host) values
  ('a0000000-0000-0000-0000-000000000041', :bill4, :a, 'Alice', true);
insert into bill_participants (id, bill_id, friend_id, name, is_host) values
  ('a0000000-0000-0000-0000-000000000042', :bill4, :fr, 'Rafi', false);
insert into items (bill_id, name, unit_price) values (:bill4, 'Kabab', 100000);
-- bill5: a draft Bob is on, to prove participants cannot edit even a draft (RLS, not the open-bill lock).
insert into bills (id, place, created_by) values (:bill5, 'Draft with Bob', :a);
insert into bill_participants (id, bill_id, friend_id, user_id, name, is_host) values
  ('a0000000-0000-0000-0000-000000000051', :bill5, null, :a, 'Alice', true),
  ('a0000000-0000-0000-0000-000000000052', :bill5, :fb, :b, 'Bob', false);
insert into items (id, bill_id, name, unit_price) values ('c0000000-0000-0000-0000-000000000051', :bill5, 'Tea', 5000);
reset role;

-- Finalize as the edge function does: service role, shares recomputed by packages/split.
select t.as_service();
select t.ok(
  (finalize_bill_apply(
    :bill, :a, 'items', 'equally',
    '[{"type":"vat","rate_bp":590,"amount":10384},{"type":"service","rate_bp":590,"amount":10384}]',
    jsonb_build_array(
      jsonb_build_object('participant_id', :pa, 'items_amount', 43500, 'extras_amount', 6923, 'total', 50423),
      jsonb_build_object('participant_id', :pb, 'items_amount', 66250, 'extras_amount', 6923, 'total', 73173),
      jsonb_build_object('participant_id', :pr, 'items_amount', 66250, 'extras_amount', 6922, 'total', 73172)),
    :tok) ->> 'total')::bigint = 196768,
  'finalize_bill_apply opens the bill with total 196768');
reset role;

select t.ok((select status from bills where id = :bill) = 'open', 'bill is open after finalize');
select t.ok((select share_token from bills where id = :bill) = :tok, 'share token stored');
select t.ok((select count(*) from settlements where bill_id = :bill) = 2, 'one settlement per friend, none for the host');
select t.ok((select email from profiles where id = :a) = 'alice@x.test', 'profile email copied from auth.users');

-- ---------------------------------------------------------------------------
-- Stranger (Carol) sees nothing of Alice's.
-- ---------------------------------------------------------------------------
select t.as_user(:c);
select t.ok((select count(*) from bills) = 0, 'stranger cannot read bills');
select t.ok((select count(*) from items) = 0, 'stranger cannot read items');
select t.ok((select count(*) from shares) = 0, 'stranger cannot read shares');
select t.ok((select count(*) from settlements) = 0, 'stranger cannot read settlements');
select t.ok((select count(*) from bill_participants) = 0, 'stranger cannot read participants');
select t.ok((select count(*) from friends) = 0, 'stranger cannot read friends');
select t.ok((select count(*) from groups) = 0, 'stranger cannot read groups');
select t.ok((select count(*) from profiles) = 1, 'stranger reads only their own profile');
select t.ok((select count(*) from public_profiles) = 1, 'stranger sees only themselves in public_profiles');
select t.throws(format('insert into bills (place, created_by) values (''x'', %L)', :a), 'row-level security', 'cannot create a bill as someone else');
select t.throws(format('insert into items (bill_id, name, unit_price) values (%L, ''x'', 1)', :bill2), 'row-level security', 'cannot add items to a bill that is not theirs');
select t.throws(format('insert into bill_participants (bill_id, name) values (%L, ''Eve'')', :bill2), 'row-level security', 'cannot add participants to a bill that is not theirs');
select t.affects(format('update bills set place = ''hacked'' where id = %L', :bill), 0, 'cannot update another user''s bill');
select t.affects(format('delete from bills where id = %L', :bill), 0, 'cannot delete another user''s bill');
select t.affects(format('update profiles set name = ''hacked'' where id = %L', :a), 0, 'cannot edit another user''s profile');
-- Carol's own group may not include Alice's friend.
insert into groups (id, name, owner_id) values ('90000000-0000-0000-0000-000000000009', 'Carol crew', :c);
select t.throws(format('insert into group_members values (%L, %L)', '90000000-0000-0000-0000-000000000009', :fr), 'row-level security', 'cannot put someone else''s friend in my group');
select t.throws(format('insert into group_members values (%L, %L)', '90000000-0000-0000-0000-000000000001', :fr), 'row-level security', 'cannot add members to someone else''s group');
reset role;

-- ---------------------------------------------------------------------------
-- Participant (Bob, an app user): read only, and only their own share and settlement.
-- ---------------------------------------------------------------------------
select t.as_user(:b);
select t.ok((select count(*) from bills) = 2, 'participant reads the bills they are on (and nothing else)');
select t.ok((select count(*) from items where bill_id = :bill) = 3, 'participant reads the items');
select t.ok((select count(*) from bill_participants where bill_id = :bill) = 3, 'participant reads who is on the bill');
select t.ok((select count(*) from shares) = 1 and (select total from shares) = 73173, 'participant reads only their own share');
select t.ok((select count(*) from settlements) = 1, 'participant reads only their own settlement');
select t.ok((select count(*) from public_profiles) = 2 and not exists (select 1 from public_profiles where name = 'Carol'), 'participant sees themselves and the host in public_profiles, not strangers');
select t.ok((select count(*) from profiles) = 1, 'participant cannot read the host profile row (bKash lives behind share-view)');
select t.affects(format('update bills set place = ''x'' where id = %L', :bill), 0, 'participant cannot edit the bill');
select t.affects(format('delete from bills where id = %L', :bill), 0, 'participant cannot delete the bill');
select t.throws(format('insert into items (bill_id, name, unit_price) values (%L, ''x'', 1)', :bill5), 'row-level security', 'participant cannot add items to a draft they are on');
select t.throws(format('insert into claims values (%L, %L)', 'c0000000-0000-0000-0000-000000000051', 'a0000000-0000-0000-0000-000000000052'), 'row-level security', 'participant cannot add claims');
select t.throws(format('insert into bill_participants (bill_id, name) values (%L, ''Eve'')', :bill5), 'row-level security', 'participant cannot add participants');
select t.affects(format('update items set unit_price = 1 where bill_id = %L', :bill5), 0, 'participant cannot edit items');
select t.affects(format('update settlements set method = ''cash'' where bill_id = %L', :bill), 0, 'participant cannot tick off settlements');
select t.throws(format('insert into shares values (%L, %L, 1, 1, 2)', :bill, :pb), 'permission denied', 'participant cannot write shares');
reset role;

-- ---------------------------------------------------------------------------
-- Guests and the anon role never touch tables. They use share_view through the edge function.
-- ---------------------------------------------------------------------------
select t.as_anon();
select t.throws('select count(*) from bills', 'permission denied', 'anon cannot read bills');
select t.throws('select count(*) from shares', 'permission denied', 'anon cannot read shares');
select t.throws(format('select share_view(%L)', :tok), 'permission denied', 'anon cannot call share_view directly');
select t.throws('select count(*) from rate_limits', 'permission denied', 'anon cannot read rate limits');
reset role;

select t.as_user(:b);
select t.throws(format('select share_view(%L)', :tok), 'permission denied', 'a signed-in user cannot call share_view either (edge function only)');
select t.throws('select count(*) from rate_limits', 'permission denied', 'rate limits are off limits to signed-in users');
reset role;

select t.as_service();
select t.ok((share_view(:tok) ->> 'place') = 'Chillox', 'share token returns that bill');
select t.ok(jsonb_array_length(share_view(:tok) -> 'people') = 3, 'share view lists everyone with their share');
select t.ok((share_view(:tok) ->> 'host_bkash') = '01700000000', 'share view shows the host bKash number');
select t.ok((share_view(:tok) ->> 'host_name') = 'Alice', 'share view shows the host name');
select t.ok(position('01811111111' in share_view(:tok)::text) = 0, 'share view leaks no guest phone number');
select t.ok(position('@x.test' in share_view(:tok)::text) = 0, 'share view leaks no email');
select t.ok(share_view('not-a-real-token') is null, 'unknown token returns nothing');
select t.ok(share_view(null) is null, 'null token returns nothing');
reset role;

-- ---------------------------------------------------------------------------
-- Host (Alice).
-- ---------------------------------------------------------------------------
select t.as_user(:a);
select t.ok((select count(*) from shares where bill_id = :bill) = 3, 'host reads every share');
select t.throws(format('insert into shares values (%L, %L, 1, 1, 2)', :bill2, 'a0000000-0000-0000-0000-000000000011'), 'permission denied', 'host cannot write shares either (server only)');
select t.throws(format('insert into settlements (bill_id, participant_id) values (%L, %L)', :bill2, 'a0000000-0000-0000-0000-000000000011'), 'permission denied', 'host cannot create settlements (server only)');
select t.throws(format('insert into notifications (user_id, kind) values (%L, ''remind'')', :b), 'permission denied', 'clients cannot create notifications');
select t.throws(format('update bills set status = ''open'' where id = %L', :bill2), 'do not add up', 'host cannot open a bill without finalize-bill');
select t.throws(format('update items set name = ''x'' where bill_id = %L', :bill), 'can no longer be edited', 'items are frozen once the bill is open');
select t.throws(format('insert into claims values (%L, %L)', 'c0000000-0000-0000-0000-000000000001', :pr), 'can no longer be edited', 'claims are frozen once the bill is open');
select t.throws(format('delete from items where bill_id = %L', :bill), 'can no longer be edited', 'items cannot be deleted from an open bill');
select t.throws(format('insert into bill_participants (bill_id, name) values (%L, ''Late'')', :bill), 'can no longer be edited', 'nobody can join an open bill');

-- Ticking off settlements. Rafi pays cash in full.
select t.affects(format('update settlements set method = ''cash'', paid_amount = 73172 where bill_id = %L and participant_id = %L', :bill, :pr), 1, 'host marks Rafi paid in cash');
select t.ok((select status from settlements where participant_id = :pr) = 'paid', 'settlement status follows: paid');
-- Wrong totals are rejected.
select t.throws(format('update settlements set method = ''bkash'', paid_amount = 100 where bill_id = %L and participant_id = %L', :bill, :pb), 'must equal the share', 'paid + owed must equal the share');
-- Bob owes 200 on his tab: 53173 in bKash, 20000 open tab (host cover).
select t.affects(format('update settlements set method = ''owes_me'', paid_amount = 53173, owed_amount = 20000, covered_amount = 20000 where bill_id = %L and participant_id = %L', :bill, :pb), 1, 'host puts 200 of Bob''s share on a tab');
select t.ok((select status from settlements where participant_id = :pb) = 'tab', 'settlement with an open tab has status tab');
select t.ok((select count(*) from settlements where bill_id = :bill and owed_amount > 0) = 1, 'one open tab');
select t.throws(format('update settlements set method = ''cash'', paid_amount = 1, owed_amount = 0, covered_amount = 99999999 where bill_id = %L and participant_id = %L', :bill, :pb), 'must equal the share', 'cover cannot exceed the share');
select t.affects(format('update bills set status = ''settled'' where id = %L', :bill), 1, 'host marks the bill settled (tabs stay open)');
select t.ok((select count(*) from settlements where bill_id = :bill and owed_amount > 0) = 1, 'the tab survives finishing the bill');

-- Voiding a draft is allowed.
select t.affects(format('delete from bills where id = %L', :bill2), 1, 'host can void a draft bill');
reset role;

-- Bob now sees his updated settlement but still cannot edit it.
select t.as_user(:b);
select t.ok((select status from settlements) = 'tab', 'participant sees their own tab');
reset role;

-- ---------------------------------------------------------------------------
-- finalize_bill_apply guards (service role).
-- ---------------------------------------------------------------------------
select t.as_service();
select t.throws(format($q$select finalize_bill_apply(%L, %L, 'items', 'equally', '[]',
  jsonb_build_array(
    jsonb_build_object('participant_id', 'a0000000-0000-0000-0000-000000000041', 'items_amount', 50000, 'extras_amount', 0, 'total', 50000),
    jsonb_build_object('participant_id', 'a0000000-0000-0000-0000-000000000042', 'items_amount', 50001, 'extras_amount', 0, 'total', 50001)), %L)$q$,
  :bill4, :a, 'TOKEN_zzzzzzzzzzzzzzzz'), 'do not add up', 'finalize rejects shares that do not add up');
select t.throws(format($q$select finalize_bill_apply(%L, %L, 'items', 'equally', '[]',
  jsonb_build_array(
    jsonb_build_object('participant_id', 'a0000000-0000-0000-0000-000000000041', 'items_amount', 100000, 'extras_amount', 0, 'total', 100000)), %L)$q$,
  :bill4, :a, 'TOKEN_zzzzzzzzzzzzzzzz'), 'expected 2 shares', 'finalize needs one share per participant');
select t.throws(format($q$select finalize_bill_apply(%L, %L, 'items', 'equally', '[]',
  jsonb_build_array(
    jsonb_build_object('participant_id', 'a0000000-0000-0000-0000-000000000041', 'items_amount', 50000, 'extras_amount', 0, 'total', 50000),
    jsonb_build_object('participant_id', %L, 'items_amount', 50000, 'extras_amount', 0, 'total', 50000)), %L)$q$,
  :bill4, :a, :pb, 'TOKEN_zzzzzzzzzzzzzzzz'), 'not on this bill', 'finalize rejects a share for someone not on the bill');
select t.throws(format($q$select finalize_bill_apply(%L, %L, 'items', 'equally', '[]', '[]', %L)$q$,
  :bill4, :c, 'TOKEN_zzzzzzzzzzzzzzzz'), 'not your bill', 'only the host can finalize');
select t.throws(format($q$select finalize_bill_apply(%L, %L, 'items', 'equally', '[]', '[]', 'short')$q$,
  :bill4, :a), 'bad share token', 'finalize rejects a weak token');
select t.throws(format($q$select finalize_bill_apply(%L, %L, 'items', 'equally', '[]', '[]', %L)$q$,
  :bill, :a, 'TOKEN_yyyyyyyyyyyyyyyy'), 'already', 'finalize cannot run twice');
-- Nothing above may have half-applied.
select t.ok((select status from bills where id = :bill4) = 'draft', 'a rejected finalize leaves the bill a draft');
select t.ok((select count(*) from shares where bill_id = :bill4) = 0, 'a rejected finalize stores no shares');
-- A good one, with the charges re-checked on the server.
select t.ok(
  (finalize_bill_apply(:bill4, :a, 'equally', 'equally',
    '[{"type":"vat","rate_bp":500,"amount":5000}]',
    jsonb_build_array(
      jsonb_build_object('participant_id', 'a0000000-0000-0000-0000-000000000041', 'items_amount', 50000, 'extras_amount', 2500, 'total', 52500),
      jsonb_build_object('participant_id', 'a0000000-0000-0000-0000-000000000042', 'items_amount', 50000, 'extras_amount', 2500, 'total', 52500)),
    'TOKEN_okokokokokokokok') ->> 'total')::bigint = 105000, 'a good finalize returns the server-computed total');
reset role;

-- ---------------------------------------------------------------------------
-- Notifications.
-- ---------------------------------------------------------------------------
insert into notifications (user_id, kind) values (:b, 'remind'), (:c, 'remind');
select t.as_user(:b);
select t.ok((select count(*) from notifications) = 1, 'users read only their own notifications');
select t.affects('update notifications set read_at = now()', 1, 'users can mark their own notifications read');
reset role;
select t.as_user(:c);
select t.ok((select read_at from notifications) is null, 'someone else''s read state is untouched');
reset role;

-- ---------------------------------------------------------------------------
-- Storage: receipts live under {user_id}/{bill_id}/.
-- ---------------------------------------------------------------------------
select t.as_user(:a);
select t.ok((select count(*) from storage.buckets where id = 'receipts' and public = false) = 1, 'receipts bucket is private');
select t.affects(format('insert into storage.objects (bucket_id, name) values (''receipts'', %L)', :a || '/' || :bill || '/r.jpg'), 1, 'owner uploads into their own folder');
select t.throws(format('insert into storage.objects (bucket_id, name) values (''receipts'', %L)', :c || '/x/r.jpg'), 'row-level security', 'cannot upload into someone else''s folder');
reset role;
select t.as_user(:c);
select t.ok((select count(*) from storage.objects) = 0, 'other users cannot list the receipt');
reset role;

-- ---------------------------------------------------------------------------
-- Profile creation cannot spoof the email.
-- ---------------------------------------------------------------------------
select t.as_user(:d);
insert into profiles (id, name, email) values (:d, 'Dave', 'fake@spoof.test');
select t.ok((select email from profiles where id = :d) = 'dave@x.test', 'client-supplied email is replaced by the auth email');
reset role;

-- ---------------------------------------------------------------------------
-- Rate limit.
-- ---------------------------------------------------------------------------
select t.as_service();
select t.ok(take_rate_limit(:a, 'scan', 2, 60), 'rate limit: first hit allowed');
select t.ok(take_rate_limit(:a, 'scan', 2, 60), 'rate limit: second hit allowed');
select t.ok(not take_rate_limit(:a, 'scan', 2, 60), 'rate limit: third hit refused');
select t.ok(take_rate_limit(:c, 'scan', 2, 60), 'rate limit is per user');
reset role;

drop schema t cascade;
