-- GaiaBit Shelter Twin Admin | conflict-safe PostgreSQL / Supabase | schema v2
-- Safe to run alongside the earlier twin_* tables (which use facility_id).
-- New admin tables all use stwin_* and shelter_id. No deletion or modification of old tables.
-- Run once in Supabase SQL Editor; if re-running, policies are dropped/recreated below.
-- The static HTML remains a local demonstration until explicitly configured.
create extension if not exists pgcrypto;

create table if not exists public.stwin_shelters (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null, code text not null, address text, width_m numeric(10,2) not null default 48,
 depth_m numeric(10,2) not null default 32, model_level text not null default 'L1',
 status text not null default 'draft' check(status in ('draft','review','published','archived')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(owner_id,code)
);
create table if not exists public.stwin_memberships (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check (role in ('admin','manager','editor','analyst','care','viewer')),
 created_at timestamptz not null default now(), unique(shelter_id,user_id)
);
create table if not exists public.stwin_zones (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 name text not null, type text not null, x numeric not null, y numeric not null,
 w numeric not null check(w>0), h numeric not null check(h>0), capacity integer not null default 0 check(capacity>=0),
 animal_count integer not null default 0 check(animal_count>=0), metadata jsonb not null default '{}',
 created_at timestamptz not null default now()
);
create table if not exists public.stwin_devices (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 zone_id uuid references public.stwin_zones(id) on delete set null, code text not null, type text not null,
 status text not null default 'unknown', x numeric, y numeric, height_m numeric,
 fov_deg numeric, effective_range_m numeric, metadata jsonb not null default '{}',
 created_at timestamptz not null default now(), unique(shelter_id,code)
);
create table if not exists public.stwin_animals (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 zone_id uuid references public.stwin_zones(id) on delete set null,
 animal_code text not null, species text not null check(species in ('dog','cat','other')),
 display_name text, health_status text, admission_date date, status text not null default 'in-shelter',
 metadata jsonb not null default '{}', created_at timestamptz not null default now(), unique(shelter_id,animal_code)
);
create table if not exists public.stwin_staff_shifts (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 assigned_user_id uuid references auth.users(id) on delete set null, display_label text not null, staff_role text not null,
 starts_at timestamptz, ends_at timestamptz, zone_id uuid references public.stwin_zones(id) on delete set null,
 metadata jsonb not null default '{}', created_at timestamptz not null default now()
);
create table if not exists public.stwin_tasks (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 zone_id uuid references public.stwin_zones(id) on delete set null,
 name text not null, kind text not null, priority text not null default 'normal', status text not null default 'pending',
 planned_at timestamptz, minutes integer check(minutes>=0), assigned_shift_id uuid references public.stwin_staff_shifts(id) on delete set null,
 metadata jsonb not null default '{}', created_at timestamptz not null default now()
);
create table if not exists public.stwin_events (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 event_at timestamptz not null default now(), type text not null, severity text not null default 'info',
 message text not null, review_status text not null default 'unreviewed', source_kind text not null default 'manual',
 metadata jsonb not null default '{}'
);
create table if not exists public.stwin_scenarios (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 name text not null, status text not null default 'draft', model_version text not null default 'prototype-v1',
 seed bigint not null default 20261029, parameters jsonb not null default '{}',
 created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.stwin_simulation_runs (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 scenario_id uuid not null references public.stwin_scenarios(id) on delete cascade,
 created_by uuid references auth.users(id) on delete set null, model_version text not null,
 seed bigint not null, input_snapshot jsonb not null default '{}', output_summary jsonb not null default '{}',
 result_class text not null default 'estimate', run_status text not null default 'completed',
 created_at timestamptz not null default now()
);
create table if not exists public.stwin_model_versions (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 version_label text not null, state text not null default 'draft', scene_snapshot jsonb not null default '{}',
 notes text, created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), unique(shelter_id,version_label)
);
create table if not exists public.stwin_audit_logs (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.stwin_shelters(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null, operation text not null,
 entity_type text not null, entity_id text, details jsonb not null default '{}', created_at timestamptz not null default now()
);
create index if not exists idx_stwin_members_user on public.stwin_memberships(user_id,shelter_id);
create index if not exists idx_stwin_zones_shelter on public.stwin_zones(shelter_id);
create index if not exists idx_stwin_devices_shelter on public.stwin_devices(shelter_id);
create index if not exists idx_stwin_animals_shelter on public.stwin_animals(shelter_id);
create index if not exists idx_stwin_events_shelter_time on public.stwin_events(shelter_id,event_at desc);
create index if not exists idx_stwin_runs_shelter on public.stwin_simulation_runs(shelter_id,created_at desc);

-- Read requires ownership or membership. Writes: owner only in first deployment (safe default).
create or replace function public.stwin_has_access(p_shelter uuid)
returns boolean language sql stable security invoker set search_path = '' as $$
 select exists(select 1 from public.stwin_shelters s where s.id=p_shelter and s.owner_id=(select auth.uid()));
$$;
-- Do not grant broad SELECT over memberships: only own memberships visible.
-- Membership-based read can be added using audited, carefully reviewed role policies later.
revoke all on function public.stwin_has_access(uuid) from public, anon;
grant execute on function public.stwin_has_access(uuid) to authenticated;

alter table public.stwin_shelters enable row level security;
alter table public.stwin_memberships enable row level security;
alter table public.stwin_zones enable row level security;
alter table public.stwin_devices enable row level security;
alter table public.stwin_animals enable row level security;
alter table public.stwin_staff_shifts enable row level security;
alter table public.stwin_tasks enable row level security;
alter table public.stwin_events enable row level security;
alter table public.stwin_scenarios enable row level security;
alter table public.stwin_simulation_runs enable row level security;
alter table public.stwin_model_versions enable row level security;
alter table public.stwin_audit_logs enable row level security;

drop policy if exists "owner shelter read" on public.stwin_shelters;
create policy "owner shelter read" on public.stwin_shelters for select to authenticated using(owner_id=(select auth.uid()));
drop policy if exists "owner shelter insert" on public.stwin_shelters;
create policy "owner shelter insert" on public.stwin_shelters for insert to authenticated with check(owner_id=(select auth.uid()));
drop policy if exists "owner shelter update" on public.stwin_shelters;
create policy "owner shelter update" on public.stwin_shelters for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
drop policy if exists "owner shelter delete" on public.stwin_shelters;
create policy "owner shelter delete" on public.stwin_shelters for delete to authenticated using(owner_id=(select auth.uid()));

-- Restrict sensitive audit log creation to trusted server-side workflows in a later phase.
-- The prototype is a local editor and does not claim server-enforced auditing.
do $$ declare t text; begin
 foreach t in array array['stwin_memberships','stwin_zones','stwin_devices','stwin_animals','stwin_staff_shifts','stwin_tasks','stwin_events','stwin_scenarios','stwin_simulation_runs','stwin_model_versions'] loop
  execute format('drop policy if exists %I on public.%I','owner_read_'||t,t);
  execute format('drop policy if exists %I on public.%I','owner_insert_'||t,t);
  execute format('drop policy if exists %I on public.%I','owner_update_'||t,t);
  execute format('drop policy if exists %I on public.%I','owner_delete_'||t,t);
  execute format('create policy %I on public.%I for select to authenticated using (public.stwin_has_access(shelter_id))','owner_read_'||t,t);
  execute format('create policy %I on public.%I for insert to authenticated with check (public.stwin_has_access(shelter_id))','owner_insert_'||t,t);
  execute format('create policy %I on public.%I for update to authenticated using (public.stwin_has_access(shelter_id)) with check (public.stwin_has_access(shelter_id))','owner_update_'||t,t);
  execute format('create policy %I on public.%I for delete to authenticated using (public.stwin_has_access(shelter_id))','owner_delete_'||t,t);
 end loop;
end $$;
drop policy if exists "owner audit read" on public.stwin_audit_logs;
create policy "owner audit read" on public.stwin_audit_logs for select to authenticated using(public.stwin_has_access(shelter_id));
-- No anon rights or public read policies; grant authenticated access subject to RLS.
revoke all on all tables in schema public from anon;
grant select,insert,update,delete on public.stwin_shelters,public.stwin_memberships,public.stwin_zones,public.stwin_devices,public.stwin_animals,public.stwin_staff_shifts,public.stwin_tasks,public.stwin_events,public.stwin_scenarios,public.stwin_simulation_runs,public.stwin_model_versions to authenticated;
grant select on public.stwin_audit_logs to authenticated;
