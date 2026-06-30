-- STEP 5: server-side email masking for leaderboard
-- Viewer sees their own full email; all other rows show "d***@gmail.com".

create or replace function mask_email(e text) returns text
language sql
immutable
as $$
  select case
    when e is null or position('@' in e) = 0 then e
    else substr(e, 1, 1) || '***' || substr(e, position('@' in e))
  end
$$;

drop function if exists get_leaderboard();

create or replace function get_leaderboard(p_token text default null)
returns table (
  rank int,
  first_name text,
  last_name text,
  email text,
  referral_count bigint,
  is_me boolean
)
language plpgsql
security definer
as $fn$
declare
  v_viewer_email text;
begin
  if p_token is not null and length(p_token) >= 10 then
    select s.email into v_viewer_email
    from signups s
    where s.dashboard_token = p_token
    limit 1;
  end if;

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
    case
      when v_viewer_email is not null and c.email = v_viewer_email then c.email
      else mask_email(c.email)
    end as email,
    c.cnt as referral_count,
    (v_viewer_email is not null and c.email = v_viewer_email) as is_me
  from counts c
  where c.cnt >= 1
  order by c.cnt desc, c.first_name nulls last
  limit 50;
end;
$fn$;

grant execute on function get_leaderboard(text) to anon;
