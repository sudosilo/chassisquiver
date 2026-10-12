create table if not exists public.chassisquiver_runs (
  id text primary key check (id ~ '^[a-z0-9]{6,40}$'),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  road text not null check (char_length(road) between 1 and 80),
  at timestamptz not null,
  auto boolean not null default false,
  score real not null check (score >= 0 and score <= 10),
  rating smallint check (rating >= 0 and rating <= 10),
  outside real,
  spm real,
  spikes integer,
  rms real,
  p95 real,
  peak real,
  secs integer,
  miles real,
  mph real,
  band real,
  bump real,
  rate integer,
  vehicle jsonb not null default '{}'::jsonb,
  path jsonb check (path is null or (jsonb_typeof(path) = 'array' and jsonb_array_length(path) <= 20000)),
  shared boolean not null default true,
  created_at timestamptz not null default now()
);
do $$
begin
  if to_regclass('public.runs') is not null
    and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'runs' and column_name = 'spm')
    and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'runs' and column_name = 'bump')
    and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'runs' and column_name = 'vehicle')
    and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'runs' and column_name = 'auto')
  then
    insert into public.chassisquiver_runs select * from public.runs on conflict do nothing;
    drop table public.runs;
  end if;
end
$$;
create index if not exists chassisquiver_runs_road_idx on public.chassisquiver_runs (lower(road));
create index if not exists chassisquiver_runs_at_idx on public.chassisquiver_runs (at desc);
create index if not exists chassisquiver_runs_user_idx on public.chassisquiver_runs (user_id);
alter table public.chassisquiver_runs enable row level security;
drop policy if exists chassisquiver_runs_read on public.chassisquiver_runs;
create policy chassisquiver_runs_read on public.chassisquiver_runs for select using (shared or user_id = auth.uid());
drop policy if exists chassisquiver_runs_insert on public.chassisquiver_runs;
create policy chassisquiver_runs_insert on public.chassisquiver_runs for insert to authenticated with check (user_id = auth.uid());
drop policy if exists chassisquiver_runs_update on public.chassisquiver_runs;
create policy chassisquiver_runs_update on public.chassisquiver_runs for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists chassisquiver_runs_delete on public.chassisquiver_runs;
create policy chassisquiver_runs_delete on public.chassisquiver_runs for delete to authenticated using (user_id = auth.uid());
grant select on public.chassisquiver_runs to anon, authenticated;
grant insert, update, delete on public.chassisquiver_runs to authenticated;
