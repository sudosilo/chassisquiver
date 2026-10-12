create table if not exists public.runs (
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

create index if not exists runs_road_idx on public.runs (lower(road));
create index if not exists runs_at_idx on public.runs (at desc);
create index if not exists runs_user_idx on public.runs (user_id);

alter table public.runs enable row level security;

drop policy if exists "runs read shared or own" on public.runs;
create policy "runs read shared or own" on public.runs
  for select using (shared or user_id = auth.uid());

drop policy if exists "runs insert own" on public.runs;
create policy "runs insert own" on public.runs
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "runs update own" on public.runs;
create policy "runs update own" on public.runs
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "runs delete own" on public.runs;
create policy "runs delete own" on public.runs
  for delete to authenticated using (user_id = auth.uid());

grant select on public.runs to anon, authenticated;
grant insert, update, delete on public.runs to authenticated;
