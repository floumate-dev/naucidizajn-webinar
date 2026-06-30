-- STEP 4 of 4: create get_leaderboard (top 50 referrers)
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
as $$
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
$$;

grant execute on function get_leaderboard() to anon;
