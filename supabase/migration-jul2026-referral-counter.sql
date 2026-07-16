-- Jul 2026 webinar: referral counter (referrals_brought) + reward-once guard (reward_notified)
-- Pokreni u Supabase SQL editoru (ovo je DDL — ne ide preko PostgREST-a).
-- Idempotentno: bezbedno za ponovno pokretanje. Sve u jednoj transakciji.

begin;

-- 1. Kolone na signups
alter table signups add column if not exists referrals_brought int     not null default 0;
alter table signups add column if not exists reward_notified   boolean not null default false;

-- 2. Backfill referrals_brought iz postojecih referral redova
update signups s
set referrals_brought = coalesce(sub.cnt, 0)
from (
  select referred_by, count(*)::int as cnt
  from signups
  where referred_by is not null
  group by referred_by
) sub
where s.ref_code = sub.referred_by;

-- 3. Trigger: uvecaj referrer-ov brojac na svaki NOV referral insert.
--    AFTER INSERT se okida samo za stvarno nove redove (ON CONFLICT DO UPDATE/NOTHING ga preskace),
--    pa ponovna prijava ne broji duplo. UPDATE uzima row-lock -> konkurentni insert-i se serijalizuju.
create or replace function bump_referrer_count()
returns trigger
language plpgsql
as $$
begin
  if NEW.referred_by is not null then
    update signups
    set referrals_brought = referrals_brought + 1
    where ref_code = NEW.referred_by;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_bump_referrer_count on signups;
create trigger trg_bump_referrer_count
after insert on signups
for each row execute function bump_referrer_count();

commit;

-- Provera posle pokretanja:
--   select ref_code, first_name, referrals_brought, reward_notified
--   from signups order by referrals_brought desc limit 20;
