-- GaiaBit Shelter Twin | PostgreSQL / Supabase | schema v1
-- Execute in a NEW dedicated Supabase project. Does not modify existing project tables.
-- The static HTML remains a local demonstration until explicitly configured.
create extension if not exists pgcrypto;

create table if not exists public.twin_shelters (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null, code text not null, address text, width_m numeric(10,2) not null default 48,
 depth_m numeric(10,2) not null default 32, model_level text not null default 'L1',
 status text not null default 'draft' check(status in ('draft','review','published','archived')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(owner_id,code)
);
create table if not exists public.twin_memberships (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check (role in ('admin','manager','editor','analyst','care','viewer')),
 created_at timestamptz not null default now(), unique(shelter_id,user_id)
);
create table if not exists public.twin_zones (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 name text not null, type text not null, x numeric not null, y numeric not null,
 w numeric not null check(w>0), h numeric not null check(h>0), capacity integer not null default 0 check(capacity>=0),
 animal_count integer not null default 0 check(animal_count>=0), metadata jsonb not null default '{}',
 created_at timestamptz not null default now()
);
create table if not exists public.twin_devices (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 zone_id uuid references public.twin_zones(id) on delete set null, code text not null, type text not null,
 status text not null default 'unknown', x numeric, y numeric, height_m numeric,
 fov_deg numeric, effective_range_m numeric, metadata jsonb not null default '{}',
 created_at timestamptz not null default now(), unique(shelter_id,code)
);
create table if not exists public.twin_animals (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 zone_id uuid references public.twin_zones(id) on delete set null,
 animal_code text not null, species text not null check(species in ('dog','cat','other')),
 display_name text, health_status text, admission_date date, status text not null default 'in-shelter',
 metadata jsonb not null default '{}', created_at timestamptz not null default now(), unique(shelter_id,animal_code)
);
create table if not exists public.twin_staff_shifts (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 assigned_user_id uuid references auth.users(id) on delete set null, display_label text not null, staff_role text not null,
 starts_at timestamptz, ends_at timestamptz, zone_id uuid references public.twin_zones(id) on delete set null,
 metadata jsonb not null default '{}', created_at timestamptz not null default now()
);
create table if not exists public.twin_tasks (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 zone_id uuid references public.twin_zones(id) on delete set null,
 name text not null, kind text not null, priority text not null default 'normal', status text not null default 'pending',
 planned_at timestamptz, minutes integer check(minutes>=0), assigned_shift_id uuid references public.twin_staff_shifts(id) on delete set null,
 metadata jsonb not null default '{}', created_at timestamptz not null default now()
);
create table if not exists public.twin_events (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 event_at timestamptz not null default now(), type text not null, severity text not null default 'info',
 message text not null, review_status text not null default 'unreviewed', source_kind text not null default 'manual',
 metadata jsonb not null default '{}'
);
create table if not exists public.twin_scenarios (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 name text not null, status text not null default 'draft', model_version text not null default 'prototype-v1',
 seed bigint not null default 20261029, parameters jsonb not null default '{}',
 created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.twin_simulation_runs (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 scenario_id uuid not null references public.twin_scenarios(id) on delete cascade,
 created_by uuid references auth.users(id) on delete set null, model_version text not null,
 seed bigint not null, input_snapshot jsonb not null default '{}', output_summary jsonb not null default '{}',
 result_class text not null default 'estimate', run_status text not null default 'completed',
 created_at timestamptz not null default now()
);
create table if not exists public.twin_model_versions (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 version_label text not null, state text not null default 'draft', scene_snapshot jsonb not null default '{}',
 notes text, created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), unique(shelter_id,version_label)
);
create table if not exists public.twin_audit_logs (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public.twin_shelters(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null, operation text not null,
 entity_type text not null, entity_id text, details jsonb not null default '{}', created_at timestamptz not null default now()
);
create index if not exists idx_twin_members_user on public.twin_memberships(user_id,shelter_id);
create index if not exists idx_twin_zones_shelter on public.twin_zones(shelter_id);
create index if not exists idx_twin_devices_shelter on public.twin_devices(shelter_id);
create index if not exists idx_twin_animals_shelter on public.twin_animals(shelter_id);
create index if not exists idx_twin_events_shelter_time on public.twin_events(shelter_id,event_at desc);
create index if not exists idx_twin_runs_shelter on public.twin_simulation_runs(shelter_id,created_at desc);

-- Read requires ownership or membership. Writes: owner only in first deployment (safe default).
create or replace function public.twin_has_access(p_shelter uuid)
returns boolean language sql stable security invoker set search_path = '' as $$
 select exists(select 1 from public.twin_shelters s where s.id=p_shelter and s.owner_id=(select auth.uid()));
$$;
-- Do not grant broad SELECT over memberships: only own memberships visible.
-- Membership-based read can be added using audited, carefully reviewed role policies later.
revoke all on function public.twin_has_access(uuid) from public, anon;
grant execute on function public.twin_has_access(uuid) to authenticated;

alter table public.twin_shelters enable row level security;
alter table public.twin_memberships enable row level security;
alter table public.twin_zones enable row level security;
alter table public.twin_devices enable row level security;
alter table public.twin_animals enable row level security;
alter table public.twin_staff_shifts enable row level security;
alter table public.twin_tasks enable row level security;
alter table public.twin_events enable row level security;
alter table public.twin_scenarios enable row level security;
alter table public.twin_simulation_runs enable row level security;
alter table public.twin_model_versions enable row level security;
alter table public.twin_audit_logs enable row level security;

create policy "owner shelter read" on public.twin_shelters for select to authenticated using(owner_id=(select auth.uid()));
create policy "owner shelter insert" on public.twin_shelters for insert to authenticated with check(owner_id=(select auth.uid()));
create policy "owner shelter update" on public.twin_shelters for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy "owner shelter delete" on public.twin_shelters for delete to authenticated using(owner_id=(select auth.uid()));

-- Restrict sensitive audit log creation to trusted server-side workflows in a later phase.
-- The prototype is a local editor and does not claim server-enforced auditing.
do $$ declare t text; begin
 foreach t in array array['twin_memberships','twin_zones','twin_devices','twin_animals','twin_staff_shifts','twin_tasks','twin_events','twin_scenarios','twin_simulation_runs','twin_model_versions'] loop
  execute format('create policy %I on public.%I for select to authenticated using (public.twin_has_access(shelter_id))','owner_read_'||t,t);
  execute format('create policy %I on public.%I for insert to authenticated with check (public.twin_has_access(shelter_id))','owner_insert_'||t,t);
  execute format('create policy %I on public.%I for update to authenticated using (public.twin_has_access(shelter_id)) with check (public.twin_has_access(shelter_id))','owner_update_'||t,t);
  execute format('create policy %I on public.%I for delete to authenticated using (public.twin_has_access(shelter_id))','owner_delete_'||t,t);
 end loop;
end $$;
create policy "owner audit read" on public.twin_audit_logs for select to authenticated using(public.twin_has_access(shelter_id));
-- No anon rights or public read policies; grant authenticated access subject to RLS.
revoke all on all tables in schema public from anon;
grant select,insert,update,delete on public.twin_shelters,public.twin_memberships,public.twin_zones,public.twin_devices,public.twin_animals,public.twin_staff_shifts,public.twin_tasks,public.twin_events,public.twin_scenarios,public.twin_simulation_runs,public.twin_model_versions to authenticated;
grant select on public.twin_audit_logs to authenticated;
