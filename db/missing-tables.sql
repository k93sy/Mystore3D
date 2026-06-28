-- ================================================================
--  Balance 3D — Missing Tables Setup
--  Run this in Supabase SQL Editor AFTER schema.sql has been applied.
--  Creates: categories, discounts, settings, reviews, stock_log,
--           custom_print_requests
--  Fixes:   infinite-recursion in profiles RLS policy
-- ================================================================

-- ---------------------------------------------------------------
-- 0. Fix profiles RLS infinite recursion (error 42P17)
--    The original policy queried profiles to check if the caller
--    is an admin, causing a recursive loop. Replace with a simple
--    own-row policy; the admin panel uses the anon key which bypasses
--    per-row restrictions via the permissive anon policy below.
-- ---------------------------------------------------------------
drop policy if exists "Admins can view all profiles"  on public.profiles;
drop policy if exists "Users can update own profile"  on public.profiles;
drop policy if exists "Users can read own profile"    on public.profiles;
drop policy if exists "Anon full access profiles"     on public.profiles;

create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Anon full access profiles"
  on public.profiles for all
  using (true) with check (true);


-- ---------------------------------------------------------------
-- 1. CATEGORIES
-- ---------------------------------------------------------------
create table if not exists public.categories (
  id         text        primary key,
  name_en    text        not null default '',
  name_ar    text        not null default '',
  icon       text        not null default '📦',
  sort_order integer     not null default 0,
  created_at timestamptz not null default now()
);

alter table public.categories enable row level security;

create policy "Public read categories"
  on public.categories for select using (true);

create policy "Anon full access categories"
  on public.categories for all
  using (true) with check (true);


-- ---------------------------------------------------------------
-- 2. DISCOUNTS
-- ---------------------------------------------------------------
create table if not exists public.discounts (
  id         text        primary key,
  code       text        not null,
  type       text        not null default 'percentage'
                         check (type in ('percentage', 'fixed')),
  value      numeric     not null default 0,
  min_order  numeric     not null default 0,
  max_uses   integer,
  uses       integer     not null default 0,
  active     boolean     not null default true,
  expires_at date,
  created_at timestamptz not null default now()
);

alter table public.discounts enable row level security;

create policy "Public read active discounts"
  on public.discounts for select using (active = true);

create policy "Anon full access discounts"
  on public.discounts for all
  using (true) with check (true);


-- ---------------------------------------------------------------
-- 3. SETTINGS  (single-row JSONB — the whole settings object)
-- ---------------------------------------------------------------
create table if not exists public.settings (
  id         smallint    primary key default 1,
  data       jsonb       not null default '{}',
  updated_at timestamptz not null default now(),
  check (id = 1)
);

-- Seed an empty row so upsert always finds a target
insert into public.settings (id, data)
values (1, '{}')
on conflict (id) do nothing;

alter table public.settings enable row level security;

create policy "Public read settings"
  on public.settings for select using (true);

create policy "Anon full access settings"
  on public.settings for all
  using (true) with check (true);


-- ---------------------------------------------------------------
-- 4. REVIEWS
-- ---------------------------------------------------------------
create table if not exists public.reviews (
  id            text        primary key,
  product_id    text        references public.products(id) on delete cascade,
  customer_name text        not null default '',
  rating        integer     not null default 5
                            check (rating between 1 and 5),
  comment       text        not null default '',
  status        text        not null default 'pending'
                            check (status in ('pending', 'approved', 'rejected')),
  created_at    timestamptz not null default now()
);

alter table public.reviews enable row level security;

create policy "Public read approved reviews"
  on public.reviews for select using (status = 'approved');

create policy "Anon full access reviews"
  on public.reviews for all
  using (true) with check (true);


-- ---------------------------------------------------------------
-- 5. STOCK LOG
-- ---------------------------------------------------------------
create table if not exists public.stock_log (
  id            text        primary key,
  product_id    text        not null,
  product_name  text        not null default '',
  change_type   text        not null,
  delta         integer     not null,
  stock_before  integer     not null default 0,
  stock_after   integer     not null default 0,
  order_id      text,
  reason        text        not null default '',
  created_at    timestamptz not null default now()
);

alter table public.stock_log enable row level security;

create policy "Anon full access stock_log"
  on public.stock_log for all
  using (true) with check (true);


-- ---------------------------------------------------------------
-- 6. CUSTOM PRINT REQUESTS
-- ---------------------------------------------------------------
create table if not exists public.custom_print_requests (
  id             text        primary key,
  status         text        not null default 'pending',
  customer_name  text        not null default '',
  customer_email text        not null default '',
  customer_phone text        not null default '',
  description    text        not null default '',
  file_url       text,
  price_estimate numeric,
  admin_notes    text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

drop trigger if exists trg_cpr_updated_at on public.custom_print_requests;
create trigger trg_cpr_updated_at
  before update on public.custom_print_requests
  for each row execute procedure public.set_updated_at();

alter table public.custom_print_requests enable row level security;

create policy "Anon full access custom_print_requests"
  on public.custom_print_requests for all
  using (true) with check (true);
