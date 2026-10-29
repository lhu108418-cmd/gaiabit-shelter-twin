-- GaiaBit Shelter Twin | PostgreSQL / Supabase
-- 建立後預設沒有對匿名訪客開放資料；必須先設定適當身分與權限。
create extension if not exists pgcrypto;
create table if not exists public.twin_facilities (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null, width_m numeric(10,2) not null default 90, depth_m numeric(10,2) not null default 66,
 config jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.twin_memberships (
 facility_id uuid not null references public.twin_facilities(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check (role in ('admin','operator','viewer')) default 'viewer',
 primary key(facility_id,user_id));
create table if not exists public.twin_zones (
 id uuid primary key default gen_random_uuid(), facility_id uuid not null references public.twin_facilities(id) on delete cascade,
 code text not null, name text not null, category text not null, pos_x numeric not null, pos_z numeric not null,
 size_x numeric not null, size_z numeric not null, capacity integer not null default 0 check(capacity>=0),
 occupancy integer not null default 0 check(occupancy>=0), extra jsonb not null default '{}'::jsonb,
 unique(facility_id,code));
create table if not exists public.twin_devices (
 id uuid primary key default gen_random_uuid(), facility_id uuid not null references public.twin_facilities(id) on delete cascade,
 zone_id uuid references public.twin_zones(id) on delete set null, label text not null, device_type text not null,
 status text not null default 'offline', pos_x numeric, pos_z numeric, last_seen timestamptz, metadata jsonb not null default '{}'::jsonb);
create table if not exists public.twin_animals (
 id uuid primary key default gen_random_uuid(), facility_id uuid not null references public.twin_facilities(id) on delete cascade,
 zone_id uuid references public.twin_zones(id) on delete set null, animal_code text not null, species text not null check(species in ('dog','cat','other')),
 state text not null default 'in_care', arrived_at date, health_status text, notes text,
 unique(facility_id,animal_code));
create table if not exists public.twin_staff_shifts (
 id uuid primary key default gen_random_uuid(), facility_id uuid not null references public.twin_facilities(id) on delete cascade,
 staff_alias text not null, start_at timestamptz not null, end_at timestamptz not null,
 workload_minutes integer not null default 0, walking_meters numeric not null default 0);
create table if not exists public.twin_events (
 id bigint generated always as identity primary key, facility_id uuid not null references public.twin_facilities(id) on delete cascade,
 zone_id uuid references public.twin_zones(id) on delete set null, occurred_at timestamptz not null default now(),
 event_type text not null, severity text not null default 'info', source text not null default 'system',
 detail jsonb not null default '{}'::jsonb);
create index if not exists twin_events_facility_time_idx on public.twin_events(facility_id,occurred_at desc);
create table if not exists public.twin_daily_metrics (
 facility_id uuid not null references public.twin_facilities(id) on delete cascade,
 metric_date date not null, metric_key text not null, metric_value numeric not null, unit text not null,
 source text not null default 'manual', primary key (facility_id,metric_date,metric_key));
create table if not exists public.twin_simulations (
 id uuid primary key default gen_random_uuid(), facility_id uuid not null references public.twin_facilities(id) on delete cascade,
 created_by uuid not null references auth.users(id), label text not null,
 inputs jsonb not null default '{}'::jsonb, outputs jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now());
-- 隔離權限，預設只讓設施持有人及其明確授權成員存取
alter table public.twin_facilities enable row level security;
alter table public.twin_memberships enable row level security;
alter table public.twin_zones enable row level security;
alter table public.twin_devices enable row level security;
alter table public.twin_animals enable row level security;
alter table public.twin_staff_shifts enable row level security;
alter table public.twin_events enable row level security;
alter table public.twin_daily_metrics enable row level security;
alter table public.twin_simulations enable row level security;
-- 保持權限簡單且安全：目前只有 owner 可透過 Data API 操作其場域，日後再擴展成員權限。
create policy twin_facility_owner_all on public.twin_facilities for all to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy twin_membership_owner_all on public.twin_memberships for all to authenticated using(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid()))) with check(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid())));
create policy twin_zone_owner_all on public.twin_zones for all to authenticated using(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid()))) with check(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid())));
create policy twin_device_owner_all on public.twin_devices for all to authenticated using(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid()))) with check(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid())));
create policy twin_animal_owner_all on public.twin_animals for all to authenticated using(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid()))) with check(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid())));
create policy twin_shift_owner_all on public.twin_staff_shifts for all to authenticated using(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid()))) with check(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid())));
create policy twin_event_owner_all on public.twin_events for all to authenticated using(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid()))) with check(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid())));
create policy twin_metrics_owner_all on public.twin_daily_metrics for all to authenticated using(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid()))) with check(exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid())));
create policy twin_sim_owner_all on public.twin_simulations for all to authenticated using(created_by=(select auth.uid()) and exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid()))) with check(created_by=(select auth.uid()) and exists(select 1 from public.twin_facilities f where f.id=facility_id and f.owner_id=(select auth.uid())));
