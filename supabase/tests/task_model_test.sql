begin;

select plan(26);

select has_table(
  'public',
  'tasks',
  'tasks table exists'
);

select has_pk(
  'public',
  'tasks',
  'tasks has a primary key'
);

select columns_are(
  'public',
  'tasks',
  array[
    'id',
    'organization_id',
    'campaign_id',
    'title',
    'description',
    'status',
    'assignee_id',
    'due_date',
    'completed_at',
    'created_by',
    'created_at',
    'updated_at'
  ]::name[],
  'tasks has the expected columns'
);

select col_not_null(
  'public',
  'tasks',
  'organization_id',
  'organization_id is required'
);

select col_not_null(
  'public',
  'tasks',
  'campaign_id',
  'campaign_id is required'
);

select col_not_null(
  'public',
  'tasks',
  'title',
  'task title is required'
);

select col_not_null(
  'public',
  'tasks',
  'status',
  'task status is required'
);

select col_not_null(
  'public',
  'tasks',
  'created_by',
  'created_by is required'
);

select ok(
  not (
    select column_definition.attnotnull
    from pg_attribute as column_definition
    where column_definition.attrelid =
      'public.tasks'::regclass
      and column_definition.attname = 'assignee_id'
  ),
  'task assignee is optional'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_definition
    where constraint_definition.conrelid =
        'public.tasks'::regclass
      and constraint_definition.conname =
        'tasks_organization_id_fkey'
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
    where constraint_definition.conrelid =
        'public.tasks'::regclass
      and constraint_definition.conname =
        'tasks_organization_campaign_fkey'
      and constraint_definition.contype = 'f'
      and constraint_definition.confrelid =
        'public.campaigns'::regclass
      and cardinality(constraint_definition.conkey) = 2
      and cardinality(constraint_definition.confkey) = 2
      and constraint_definition.confdeltype = 'c'
  ),
  'campaign relationship is a cascading composite tenant foreign key'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_definition
    where constraint_definition.conrelid =
        'public.tasks'::regclass
      and constraint_definition.conname =
        'tasks_assignee_id_fkey'
      and constraint_definition.contype = 'f'
      and constraint_definition.confrelid =
        'public.profiles'::regclass
      and constraint_definition.confdeltype = 'n'
  ),
  'deleting an assignee sets task assignee to null'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_definition
    where constraint_definition.conrelid =
        'public.tasks'::regclass
      and constraint_definition.conname =
        'tasks_created_by_fkey'
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
    where constraint_definition.conrelid =
        'public.tasks'::regclass
      and constraint_definition.conname =
        'tasks_organization_id_id_unique'
      and constraint_definition.contype = 'u'
  ),
  'tasks has a composite tenant unique key'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'tasks'
      and indexname =
        'tasks_organization_campaign_status_idx'
      and indexdef ilike '%organization_id%'
      and indexdef ilike '%campaign_id%'
      and indexdef ilike '%status%'
  ),
  'campaign and status lookup index exists'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'tasks'
      and indexname =
        'tasks_organization_assignee_status_idx'
      and indexdef ilike '%organization_id%'
      and indexdef ilike '%assignee_id%'
      and indexdef ilike '%status%'
      and indexdef ilike '%where%assignee_id is not null%'
  ),
  'partial assignee and status index exists'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'tasks'
      and indexname =
        'tasks_organization_due_date_idx'
      and indexdef ilike '%organization_id%'
      and indexdef ilike '%due_date%'
      and indexdef ilike
        '%where%due_date is not null%completed_at is null%'
  ),
  'partial incomplete-task due-date index exists'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.tasks'::regclass
      and conname = 'tasks_title_check'
      and contype = 'c'
  ),
  'task title validation exists'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.tasks'::regclass
      and conname = 'tasks_description_check'
      and contype = 'c'
  ),
  'task description validation exists'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.tasks'::regclass
      and conname = 'tasks_completed_at_check'
      and contype = 'c'
  ),
  'task completion timestamp validation exists'
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_definition
    where trigger_definition.tgrelid =
        'public.tasks'::regclass
      and trigger_definition.tgname =
        'tasks_set_updated_at'
      and not trigger_definition.tgisinternal
      and trigger_definition.tgenabled <> 'D'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%before update%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%set_updated_at%'
  ),
  'task updated_at trigger exists'
);

select ok(
  (
    select table_definition.relrowsecurity
    from pg_class as table_definition
    where table_definition.oid =
      'public.tasks'::regclass
  ),
  'row-level security is enabled on tasks'
);

select ok(
  not has_table_privilege(
    'anon',
    'public.tasks',
    'select'
  )
  and not has_table_privilege(
    'anon',
    'public.tasks',
    'insert'
  )
  and not has_table_privilege(
    'anon',
    'public.tasks',
    'update'
  )
  and not has_table_privilege(
    'anon',
    'public.tasks',
    'delete'
  ),
  'anonymous users have no task CRUD privileges'
);

select ok(
  has_table_privilege(
    'authenticated',
    'public.tasks',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.tasks',
    'insert'
  )
  and has_table_privilege(
    'authenticated',
    'public.tasks',
    'update'
  )
  and has_table_privilege(
    'authenticated',
    'public.tasks',
    'delete'
  ),
  'authenticated users have task CRUD privileges'
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
        'public.tasks'::regclass
      and column_definition.attname in (
        'id',
        'status',
        'created_at',
        'updated_at'
      )
  ),
  4::bigint,
  'task UUID, status, and timestamps have defaults'
);

select ok(
  (
    select pg_get_expr(
      default_definition.adbin,
      default_definition.adrelid
    ) ilike '%todo%'
    from pg_attribute as column_definition
    join pg_attrdef as default_definition
      on default_definition.adrelid =
        column_definition.attrelid
      and default_definition.adnum =
        column_definition.attnum
    where column_definition.attrelid =
        'public.tasks'::regclass
      and column_definition.attname = 'status'
  ),
  'task status defaults to todo'
);

select * from finish();

rollback;