alter table public.chassisquiver_runs add column if not exists metrics jsonb not null default '{}'::jsonb;
notify pgrst, 'reload schema';
