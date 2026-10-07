-- Dev seed: a demo host with friends, a group, and the Chillox sample from the spec
-- (total 2,236; Tania on a 200 tab) plus one fully settled bill.
-- Login in dev with the email below through Inbucket (http://127.0.0.1:54324).

do $seed$
declare
  demo constant uuid := '00000000-0000-0000-0000-0000000d3e30';
  f_rafi constant uuid := 'f1000000-0000-0000-0000-000000000001';
  f_nabil constant uuid := 'f1000000-0000-0000-0000-000000000002';
  f_tania constant uuid := 'f1000000-0000-0000-0000-000000000003';
  grp constant uuid := 'e1000000-0000-0000-0000-000000000001';
  b1 constant uuid := 'b1000000-0000-0000-0000-000000000001';   -- Chillox
  b2 constant uuid := 'b1000000-0000-0000-0000-000000000002';   -- Pizza Roma
  p_you constant uuid := 'a1000000-0000-0000-0000-000000000001';
  p_rafi constant uuid := 'a1000000-0000-0000-0000-000000000002';
  p_nabil constant uuid := 'a1000000-0000-0000-0000-000000000003';
  p_tania constant uuid := 'a1000000-0000-0000-0000-000000000004';
  i_burger constant uuid := 'c1000000-0000-0000-0000-000000000001';
  i_beef constant uuid := 'c1000000-0000-0000-0000-000000000002';
  i_fries constant uuid := 'c1000000-0000-0000-0000-000000000003';
  i_coke constant uuid := 'c1000000-0000-0000-0000-000000000004';
  q_you constant uuid := 'a2000000-0000-0000-0000-000000000001';
  q_rafi constant uuid := 'a2000000-0000-0000-0000-000000000002';
  q_nabil constant uuid := 'a2000000-0000-0000-0000-000000000003';
  j_pizza constant uuid := 'c2000000-0000-0000-0000-000000000001';
begin
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (demo, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'demo@splitup.app', now(),
          '{"provider":"email","providers":["email"]}', '{}', now(), now())
  on conflict (id) do nothing;
  insert into profiles (id, name, avatar_color, bkash_number) values (demo, 'Demo', 'lavender', '01700000000')
  on conflict (id) do nothing;

  insert into friends (id, owner_id, name, phone, avatar_color) values
    (f_rafi, demo, 'Rafi', '01711111111', 'coral'),
    (f_nabil, demo, 'Nabil', null, 'sky'),
    (f_tania, demo, 'Tania', '01922222222', 'lime');
  insert into groups (id, name, owner_id) values (grp, 'NSU boys', demo);
  insert into group_members values (grp, f_rafi), (grp, f_nabil), (grp, f_tania);

  -- Chillox: burger 345, beef kala bhuna 1,145, fries 240, coke x3 270; VAT and service 5.9% each.
  insert into bills (id, group_id, place, created_by, billed_at) values (b1, grp, 'Chillox', demo, now() - interval '3 days');
  insert into bill_participants (id, bill_id, friend_id, user_id, name, is_host, position) values
    (p_you, b1, null, demo, 'Demo', true, 0), (p_rafi, b1, f_rafi, null, 'Rafi', false, 1),
    (p_nabil, b1, f_nabil, null, 'Nabil', false, 2), (p_tania, b1, f_tania, null, 'Tania', false, 3);
  insert into items (id, bill_id, name, qty, unit_price, position) values
    (i_burger, b1, 'Chicken burger', 1, 34500, 0), (i_beef, b1, 'Beef kala bhuna', 1, 114500, 1),
    (i_fries, b1, 'Fries', 1, 24000, 2), (i_coke, b1, 'Coke', 3, 9000, 3);
  insert into claims values
    (i_burger, p_you), (i_beef, p_rafi), (i_beef, p_nabil),
    (i_fries, p_you), (i_fries, p_tania), (i_coke, p_you), (i_coke, p_rafi), (i_coke, p_tania);
  insert into charges values (b1, 'vat', 590, 11800), (b1, 'service', 590, 11800);
  insert into shares values
    (b1, p_you, 55500, 5900, 61400), (b1, p_rafi, 66250, 5900, 72150),
    (b1, p_nabil, 57250, 5900, 63150), (b1, p_tania, 21000, 5900, 26900);
  insert into settlements (bill_id, participant_id) values (b1, p_rafi), (b1, p_nabil), (b1, p_tania);
  update bills set subtotal = 200000, total = 223600, status = 'open', share_token = 'chilloxsampletoken00000' where id = b1;
  update settlements set method = 'bkash', paid_amount = 72150 where bill_id = b1 and participant_id = p_rafi;
  update settlements set method = 'cash', paid_amount = 63150 where bill_id = b1 and participant_id = p_nabil;
  update settlements set method = 'owes_me', paid_amount = 6900, owed_amount = 20000, covered_amount = 20000
   where bill_id = b1 and participant_id = p_tania;
  update bills set status = 'settled' where id = b1;

  -- Pizza Roma: one margherita pizza, three people, no extras, all paid.
  insert into bills (id, group_id, place, created_by, billed_at) values (b2, grp, 'Pizza Roma', demo, now() - interval '9 days');
  insert into bill_participants (id, bill_id, friend_id, user_id, name, is_host, position) values
    (q_you, b2, null, demo, 'Demo', true, 0), (q_rafi, b2, f_rafi, null, 'Rafi', false, 1), (q_nabil, b2, f_nabil, null, 'Nabil', false, 2);
  insert into items (id, bill_id, name, qty, unit_price) values (j_pizza, b2, 'Margherita', 3, 50000);
  insert into claims values (j_pizza, q_you), (j_pizza, q_rafi), (j_pizza, q_nabil);
  insert into shares values (b2, q_you, 50000, 0, 50000), (b2, q_rafi, 50000, 0, 50000), (b2, q_nabil, 50000, 0, 50000);
  insert into settlements (bill_id, participant_id) values (b2, q_rafi), (b2, q_nabil);
  update bills set subtotal = 150000, total = 150000, status = 'open', share_token = 'pizzaromasampletoken000' where id = b2;
  update settlements set method = 'cash', paid_amount = 50000 where bill_id = b2;
  update bills set status = 'settled' where id = b2;
end
$seed$;
