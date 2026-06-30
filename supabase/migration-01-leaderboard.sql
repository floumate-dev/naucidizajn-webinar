-- Migration 01: add last_name column + leaderboard support
-- Safe to run on production (additive only).

alter table signups add column if not exists last_name text;

-- create_signup now accepts p_last_name
create or replace function create_signup(
  p_email text,
  p_first_name text default null,
  p_referred_by text default null,
  p_last_name text default null
) returns table (
  out_ref_code text,
  out_dashboard_token text,
  out_is_new boolean,
  out_referred_by text
)
language plpgsql
security definer
as $fn_signup$
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
    -- back-fill last_name if previously null and we now have one
    if v_existing.last_name is null and nullif(trim(p_last_name), '') is not null then
      update signups set last_name = trim(p_last_name) where id = v_existing.id;
    end if;
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

  insert into signups (email, first_name, last_name, ref_code, referred_by, dashboard_token)
  values (
    p_email,
    nullif(trim(p_first_name), ''),
    nullif(trim(p_last_name), ''),
    v_ref_code,
    v_referred_by,
    v_token
  );

  return query select v_ref_code, v_token, true, v_referred_by;
end;
$fn_signup$;

revoke execute on function create_signup(text, text, text, text) from anon, authenticated;

-- get_dashboard now returns user's leaderboard rank + total active referrers
create or replace function get_dashboard(p_token text)
returns table (
  ref_code text,
  first_name text,
  last_name text,
  referral_count bigint,
  my_rank int,
  total_with_referrals bigint,
  referrals json
)
language plpgsql
security definer
as $fn_dashboard$
declare
  v_ref_code text;
  v_first_name text;
  v_last_name text;
  v_my_count bigint;
  v_my_rank int;
  v_total bigint;
begin
  if p_token is null or length(p_token) < 10 then
    return;
  end if;

  select s.ref_code, s.first_name, s.last_name
  into v_ref_code, v_first_name, v_last_name
  from signups s
  where s.dashboard_token = p_token
  limit 1;

  if not found then
    return;
  end if;

  v_my_count := (select count(*) from signups x where x.referred_by = v_ref_code);
  v_total    := (select count(*) from (
    select s.ref_code
    from signups s
    where (select count(*) from signups y where y.referred_by = s.ref_code) > 0
  ) t);

  if v_my_count > 0 then
    v_my_rank := (
      select count(*) + 1
      from signups s
      where (select count(*) from signups z where z.referred_by = s.ref_code) > v_my_count
    );
  else
    v_my_rank := null;
  end if;

  return query
  select
    v_ref_code,
    v_first_name,
    v_last_name,
    v_my_count,
    v_my_rank,
    v_total,
    coalesce(
      (select json_agg(json_build_object(
        'email', x.email,
        'first_name', x.first_name,
        'last_name', x.last_name,
        'created_at', x.created_at
      ) order by x.created_at desc)
      from signups x where x.referred_by = v_ref_code),
      '[]'::json
    );
end;
$fn_dashboard$;

-- Top 50 leaderboard, referrers with count >= 1
create or replace function get_leaderboard()
returns table (
  rank int,
  first_name text,
  last_name text,
  email text,
  referral_count bigint
)
language plpgsql
security definer
as $fn_leaderboard$
begin
  return query
  with counts as (
    select
      s.ref_code,
      s.first_name,
      s.last_name,
      s.email,
      (select count(*) from signups x where x.referred_by = s.ref_code) as cnt
    from signups s
  )
  select
    (row_number() over (order by c.cnt desc, c.first_name nulls last))::int as rank,
    c.first_name,
    c.last_name,
    c.email,
    c.cnt
  from counts c
  where c.cnt >= 1
  order by c.cnt desc, c.first_name nulls last
  limit 50;
end;
$fn_leaderboard$;

grant execute on function get_leaderboard() to anon;
grant execute on function get_dashboard(text) to anon;
