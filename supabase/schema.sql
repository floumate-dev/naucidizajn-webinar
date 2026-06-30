-- Nauči Dizajnu — UI/UX Webinar 27.04.2026 — Referral System Schema
-- Run this in Supabase SQL Editor after creating the project.

create extension if not exists pgcrypto;

create table if not exists signups (
  id              uuid primary key default gen_random_uuid(),
  email           text not null unique,
  first_name      text,
  ref_code        text not null unique,
  referred_by     text references signups(ref_code) on delete set null,
  dashboard_token text not null unique,
  attended        boolean not null default false,
  reward_sent     boolean not null default false,
  flagged         boolean not null default false,
  notes           text,
  created_at      timestamptz not null default now()
);

create index if not exists signups_referred_by_idx on signups(referred_by);
create index if not exists signups_dashboard_token_idx on signups(dashboard_token);
create index if not exists signups_created_at_idx on signups(created_at desc);

-- random code generator: 6 chars, uppercase alphanumeric, no 0/O/I/1 confusion
create or replace function gen_ref_code() returns text
language plpgsql as $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..6 loop
    result := result || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return result;
end;
$$;

-- random url-safe dashboard token (~24 chars)
create or replace function gen_dashboard_token() returns text
language plpgsql as $$
declare
  raw text;
begin
  raw := encode(gen_random_bytes(18), 'base64');
  raw := replace(raw, '+', '-');
  raw := replace(raw, '/', '_');
  raw := replace(raw, '=', '');
  return raw;
end;
$$;

-- Main signup function. Idempotent on email.
-- Called by the webhook via service_role key.
create or replace function create_signup(
  p_email text,
  p_first_name text default null,
  p_referred_by text default null
) returns table (
  out_ref_code text,
  out_dashboard_token text,
  out_is_new boolean,
  out_referred_by text
)
language plpgsql
security definer
as $$
declare
  v_existing signups%rowtype;
  v_ref_code text;
  v_token text;
  v_referred_by text;
  v_attempts int := 0;
begin
  p_email := lower(trim(p_email));
  if p_email is null or p_email = '' or position('@' in p_email) = 0 then
    raise exception 'Invalid email';
  end if;

  select * into v_existing from signups where email = p_email limit 1;
  if found then
    return query select
      v_existing.ref_code,
      v_existing.dashboard_token,
      false,
      v_existing.referred_by;
    return;
  end if;

  v_referred_by := null;
  if p_referred_by is not null and length(trim(p_referred_by)) > 0 then
    select s.ref_code into v_referred_by
    from signups s
    where s.ref_code = upper(trim(p_referred_by))
    limit 1;
  end if;

  loop
    v_ref_code := gen_ref_code();
    exit when not exists (select 1 from signups where ref_code = v_ref_code);
    v_attempts := v_attempts + 1;
    if v_attempts > 20 then
      raise exception 'Could not generate unique ref_code after 20 attempts';
    end if;
  end loop;

  v_token := gen_dashboard_token();

  insert into signups (email, first_name, ref_code, referred_by, dashboard_token)
  values (p_email, nullif(trim(p_first_name), ''), v_ref_code, v_referred_by, v_token);

  return query select v_ref_code, v_token, true, v_referred_by;
end;
$$;

-- Dashboard read function. Accepts the secret token and returns the public-safe projection.
-- SECURITY DEFINER so anon role (which has no table access) can still invoke it.
create or replace function get_dashboard(p_token text)
returns table (
  ref_code text,
  first_name text,
  referral_count bigint,
  referrals json
)
language plpgsql
security definer
as $$
declare
  v_ref_code text;
  v_first_name text;
begin
  if p_token is null or length(p_token) < 10 then
    return;
  end if;

  select s.ref_code, s.first_name into v_ref_code, v_first_name
  from signups s
  where s.dashboard_token = p_token
  limit 1;

  if not found then
    return;
  end if;

  return query
  select
    v_ref_code,
    v_first_name,
    (select count(*) from signups x where x.referred_by = v_ref_code),
    coalesce(
      (select json_agg(json_build_object(
        'email', x.email,
        'first_name', x.first_name,
        'created_at', x.created_at
      ) order by x.created_at desc)
      from signups x where x.referred_by = v_ref_code),
      '[]'::json
    );
end;
$$;

alter table signups enable row level security;
-- No policies for anon/authenticated = zero direct table access.
-- All reads go through get_dashboard(token), all writes through create_signup() (service_role).

grant execute on function get_dashboard(text) to anon;
revoke execute on function create_signup(text, text, text) from anon, authenticated;
