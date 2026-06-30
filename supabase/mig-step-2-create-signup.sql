-- STEP 2 of 4: replace create_signup to accept p_last_name
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
$$;

revoke execute on function create_signup(text, text, text, text) from anon, authenticated;
