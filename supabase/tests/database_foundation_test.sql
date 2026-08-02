select plan(20);

select ok(
  to_regtype('public.organization_role') is not null,
  'organization_role enum exists'
);

select ok(
  to_regtype('public.campaign_status') is not null,
  'campaign_status enum exists'
);

select ok(
  to_regtype('public.task_status') is not null,
  'task_status enum exists'
);

select ok(
  to_regtype('public.approval_status') is not null,
  'approval_status enum exists'
);

select has_table(
  'public',
  'profiles',
  'profiles table exists'
);

select col_is_pk(
  'public',
  'profiles',
  'id',
  'profiles.id is the primary key'
);

select fk_ok(
  'public',
  'profiles',
  'id',
  'auth',
  'users',
  'id',
  'profiles.id references auth.users.id'
);

select col_not_null(
  'public',
  'profiles',
  'full_name',
  'profiles.full_name is required'
);

select col_has_default(
  'public',
  'profiles',
  'created_at',
  'profiles.created_at has a default'
);

select col_has_default(
  'public',
  'profiles',
  'updated_at',
  'profiles.updated_at has a default'
);

select has_trigger(
  'public',
  'profiles',
  'set_profiles_updated_at',
  'profiles has an updated_at trigger'
);

select has_trigger(
  'auth',
  'users',
  'on_auth_user_created',
  'auth.users has a profile creation trigger'
);

select ok(
  (
    select c.relrowsecurity
    from pg_catalog.pg_class as c
    join pg_catalog.pg_namespace as n
      on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'profiles'
  ),
  'RLS is enabled on profiles'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Users can view their own profile'
  ),
  'own-profile select policy exists'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Users can update their own profile'
  ),
  'own-profile update policy exists'
);

select ok(
  has_table_privilege(
    'authenticated',
    'public.profiles',
    'SELECT'
  ),
  'authenticated users have profile select permission'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.profiles',
    'INSERT'
  ),
  'authenticated users cannot insert profiles directly'
);

select ok(
  has_column_privilege(
    'authenticated',
    'public.profiles',
    'full_name',
    'UPDATE'
  ),
  'authenticated users may update full_name'
);

select ok(
  not has_column_privilege(
    'authenticated',
    'public.profiles',
    'created_at',
    'UPDATE'
  ),
  'authenticated users cannot update created_at'
);

select ok(
  (
    select p.prosecdef
    from pg_catalog.pg_proc as p
    join pg_catalog.pg_namespace as n
      on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'handle_new_user'
  ),
  'handle_new_user is security definer'
);

select * from finish();

rollback;