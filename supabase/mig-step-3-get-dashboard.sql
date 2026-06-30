-- STEP 3 of 4: replace get_dashboard to also return rank + total
drop function if exists get_dashboard(text);

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
as $$
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
$$;

grant execute on function get_dashboard(text) to anon;
