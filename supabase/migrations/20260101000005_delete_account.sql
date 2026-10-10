-- Account deletion (Google Play requires it, in the app and on the web).
-- delete_account_data removes everything a person created; the delete-account edge function
-- calls it and then deletes the login itself (auth.users, which cascades to the profile, their
-- groups, friends list, group members and notifications).
--
-- What happens to shared things:
--  * bills the person hosted are deleted with their items, shares and settlements (the other
--    people lose that bill, there is no host left to settle with);
--  * bills someone else hosted keep the person's name as a plain guest row (bill_participants
--    and friends.user_id go to null on the profile delete), so the host's totals still add up.
-- Deleting a bill directly is allowed by the draft-only triggers: their child rows are removed
-- by the cascade, when the parent bill is already gone.
create or replace function delete_account_data(p_user_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_user_id is null then raise exception 'user id is required'; end if;
  delete from bills where created_by = p_user_id;
  -- Their own rows that point at the profile are removed by the profile cascade; deleting them
  -- here too makes this function leave nothing behind even if the login delete is retried.
  delete from notifications where user_id = p_user_id;
  delete from groups where owner_id = p_user_id;
  delete from friends where owner_id = p_user_id;
  update bill_participants set user_id = null where user_id = p_user_id;
  update friends set user_id = null where user_id = p_user_id;
  delete from profiles where id = p_user_id;
end $$;

revoke all on function delete_account_data(uuid) from public, anon, authenticated;
grant execute on function delete_account_data(uuid) to service_role;
