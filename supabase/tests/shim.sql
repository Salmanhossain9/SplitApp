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
$$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

create schema storage;
create table storage.buckets (id text primary key, name text not null, public boolean default false);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text not null
);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql immutable as
$$ select string_to_array(name, '/') $$;

create publication supabase_realtime;

grant usage on schema public, auth, storage to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
grant all on all tables in schema storage to authenticated, service_role;
grant select on auth.users to service_role;
