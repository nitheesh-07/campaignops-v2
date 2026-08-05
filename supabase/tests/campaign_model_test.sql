begin;

select plan(24);

select has_table(
  'public',
  'campaigns',
  'campaigns table exists'
);

select has_pk(
  'public',
  'campaigns',
  'campaigns has a primary key'
);

select columns_are(
  'public',
  'campaigns',
  array[
    'id',
    'organization_id',
    'client_id',
    'name',
    'description',
    'status',
    'start_date',
    'due_date',
    'created_by',
    'created_at',
    'updated_at'
  ]::name[],
  'campaigns has the expected columns'
);

select col_not_null(
  'public',
  'campaigns',
  'organization_id',
  'organization_id is required'
);

select col_not_null(
  'public',
  'campaigns',
  'client_id',
  'client_id is required'
);

select col_not_null(
  'public',
  'campaigns',
  'name',
  'campaign name is required'
);

select col_not_null(
  'public',
  'campaigns',
  'status',
  'campaign status is required'
);

select col_not_null(
  'public',
  'campaigns',
  'created_by',
  'created_by is required'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_definition
    join pg_class as table_definition
      on table_definition.oid = constraint_definition.conrelid
    join pg_namespace as schema_definition
      on schema_definition.oid = table_definition.relnamespace
    where schema_definition.nspname = 'public'
      and table_definition.relname = 'campaigns'
      and constraint_definition.conname =
        'campaigns_organization_id_fkey'
      and constraint_definition.contype = 'f'
      and constraint_definition.confrelid =
        'public.organizations'::regclass
      and constraint_definition.confdeltype = 'c'
  ),
  'organization foreign key cascades on delete'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_definition
    join pg_class as table_definition
      on table_definition.oid = constraint_definition.conrelid
    join pg_namespace as schema_definition
      on schema_definition.oid = table_definition.relnamespace
    where schema_definition.nspname = 'public'
      and table_definition.relname = 'campaigns'
      and constraint_definition.conname =
        'campaigns_organization_client_fkey'
      and constraint_definition.contype = 'f'
      and constraint_definition.confrelid =
        'public.clients'::regclass
      and cardinality(constraint_definition.conkey) = 2
      and cardinality(constraint_definition.confkey) = 2
      and constraint_definition.confdeltype = 'r'
  ),
  'client relationship is a restrictive composite tenant foreign key'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_definition
    join pg_class as table_definition
      on table_definition.oid = constraint_definition.conrelid
    join pg_namespace as schema_definition
      on schema_definition.oid = table_definition.relnamespace
    where schema_definition.nspname = 'public'
      and table_definition.relname = 'campaigns'
      and constraint_definition.conname =
        'campaigns_created_by_fkey'
      and constraint_definition.contype = 'f'
      and constraint_definition.confrelid =
        'public.profiles'::regclass
      and constraint_definition.confdeltype = 'r'
  ),
  'created_by references profiles and restricts deletion'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_definition
    join pg_class as table_definition
      on table_definition.oid = constraint_definition.conrelid
    join pg_namespace as schema_definition
      on schema_definition.oid = table_definition.relnamespace
    where schema_definition.nspname = 'public'
      and table_definition.relname = 'campaigns'
      and constraint_definition.conname =
        'campaigns_organization_id_id_unique'
      and constraint_definition.contype = 'u'
  ),
  'campaigns has a composite tenant unique key'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'campaigns'
      and indexname = 'campaigns_client_name_unique_idx'
      and indexdef ilike 'create unique index%'
      and indexdef ilike '%organization_id%'
      and indexdef ilike '%client_id%'
      and indexdef ilike '%lower(name)%'
  ),
  'campaign names are case-insensitively unique per client'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'campaigns'
      and indexname = 'campaigns_organization_status_idx'
      and indexdef ilike '%organization_id%'
      and indexdef ilike '%status%'
  ),
  'campaign organization and status index exists'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'campaigns'
      and indexname = 'campaigns_organization_due_date_idx'
      and indexdef ilike '%organization_id%'
      and indexdef ilike '%due_date%'
      and indexdef ilike '%where%due_date is not null%'
  ),
  'campaign due-date partial index exists'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.campaigns'::regclass
      and conname = 'campaigns_name_check'
      and contype = 'c'
  ),
  'campaign name validation exists'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.campaigns'::regclass
      and conname = 'campaigns_description_check'
      and contype = 'c'
  ),
  'campaign description validation exists'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.campaigns'::regclass
      and conname = 'campaigns_date_range_check'
      and contype = 'c'
  ),
  'campaign date-range validation exists'
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_definition
    where trigger_definition.tgrelid =
        'public.campaigns'::regclass
      and trigger_definition.tgname =
        'campaigns_set_updated_at'
      and not trigger_definition.tgisinternal
      and trigger_definition.tgenabled <> 'D'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%before update%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%set_updated_at%'
  ),
  'campaign updated_at trigger exists'
);

select ok(
  (
    select table_definition.relrowsecurity
    from pg_class as table_definition
    where table_definition.oid =
      'public.campaigns'::regclass
  ),
  'row-level security is enabled on campaigns'
);

select ok(
  not has_table_privilege(
    'anon',
    'public.campaigns',
    'select'
  )
  and not has_table_privilege(
    'anon',
    'public.campaigns',
    'insert'
  )
  and not has_table_privilege(
    'anon',
    'public.campaigns',
    'update'
  )
  and not has_table_privilege(
    'anon',
    'public.campaigns',
    'delete'
  ),
  'anonymous users have no campaign CRUD privileges'
);

select ok(
  has_table_privilege(
    'authenticated',
    'public.campaigns',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.campaigns',
    'insert'
  )
  and has_table_privilege(
    'authenticated',
    'public.campaigns',
    'update'
  )
  and has_table_privilege(
    'authenticated',
    'public.campaigns',
    'delete'
  ),
  'authenticated users have campaign CRUD privileges'
);

select is(
  (
    select count(*)
    from pg_attribute as column_definition
    join pg_attrdef as default_definition
      on default_definition.adrelid =
        column_definition.attrelid
      and default_definition.adnum =
        column_definition.attnum
    where column_definition.attrelid =
        'public.campaigns'::regclass
      and column_definition.attname in (
        'id',
        'status',
        'created_at',
        'updated_at'
      )
  ),
  4::bigint,
  'campaign UUID, status, and timestamps have defaults'
);

select ok(
  (
    select pg_get_expr(
      default_definition.adbin,
      default_definition.adrelid
    ) ilike '%draft%'
    from pg_attribute as column_definition
    join pg_attrdef as default_definition
      on default_definition.adrelid =
        column_definition.attrelid
      and default_definition.adnum =
        column_definition.attnum
    where column_definition.attrelid =
        'public.campaigns'::regclass
      and column_definition.attname = 'status'
  ),
  'campaign status defaults to draft'
);

select * from finish();

rollback;