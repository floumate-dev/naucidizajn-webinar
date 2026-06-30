-- STEP 1 of 4: add last_name column
alter table signups add column if not exists last_name text;
