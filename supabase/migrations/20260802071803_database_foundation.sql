-- CampaignOps database foundation.
-- Dependency order:
-- 1. Extensions
-- 2. Enum types
-- 3. Tables
-- 4. Functions
-- 5. Triggers
-- 6. RLS policies and privileges

create extension if not exists citext;

create type public.organization_role as enum (
  'owner',
  'manager',
  'member'
);

create type public.campaign_status as enum (
  'draft',
  'active',
  'in_review',
  'approved',
  'completed',
  'archived'
);

create type public.task_status as enum (
  'todo',
  'in_progress',
  'blocked',
  'done'
);

create type public.approval_status as enum (
  'pending',
  'approved',
  'changes_requested'
);

create table public.profiles (
  id uuid primary key
    references auth.users (id)
    on delete cascade,

  full_name text not null
    check (
      char_length(btrim(full_name)) between 1 and 100
    ),

  avatar_url text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id,
    full_name
  )
  values (
    new.id,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      'New user'
    )
  );

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

alter table public.profiles enable row level security;

create policy "Users can view their own profile"
on public.profiles
for select
to authenticated
using (
  (select auth.uid()) = id
);

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using (
  (select auth.uid()) = id
)
with check (
  (select auth.uid()) = id
);

-- Remove broad automatically granted permissions.
revoke all
on table public.profiles
from anon, authenticated;

-- Authenticated users may read their row.
grant select
on table public.profiles
to authenticated;

-- Only these user-editable columns may be changed directly.
grant update (full_name, avatar_url)
on table public.profiles
to authenticated;

-- These functions are trigger functions, not public API endpoints.
revoke execute
on function public.set_updated_at()
from public, anon, authenticated;

revoke execute
on function public.handle_new_user()
from public, anon, authenticated;