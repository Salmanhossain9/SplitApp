-- Minimal stand-ins for what Supabase provides, so the migrations and RLS tests run on plain
-- Postgres (CI and the cloud sandbox). Not used against a real Supabase project.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema auth;
create table auth.users (
  id uuid primary key, email text, instance_id uuid, aud text, role text,
  email_confirmed_at timestamptz, raw_app_meta_data jsonb, raw_user_meta_data jsonb,
  created_at timestamptz, updated_at timestamptz
);
create function auth.uid() returns uuid language sql stable as
$$ select coalesce(
     nullif(current_setting('request.jwt.claim.sub', true), ''),
     nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
   )::uuid $$;

create publication supabase_realtime;

grant usage on schema public, auth to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
grant select on auth.users to service_role;
