select plan(16);

-- 1: Table
select has_table(
  'public',
  'clients',
  'clients table should exist'
);

-- 2: Primary key
select has_pk(
  'public',
  'clients',
  'clients should have a primary key'
);

-- 3: Required columns
select is(
  (
    select count(*)::integer
    from pg_attribute
    where attrelid = 'public.clients'::regclass
      and attname = any (
        array[
          'id',
          'organization_id',
          'name',
          'contact_name',
          'contact_email',
          'notes',
          'created_by',
          'archived_at',
          'created_at',
          'updated_at'
        ]
      )
      and attnum > 0
      and not attisdropped
  ),
  10,
  'clients should contain all required columns'
);

-- 4–5: Required values
select col_not_null(
  'public',
  'clients',
  'organization_id',
  'clients.organization_id should be required'
);

select col_not_null(
  'public',
  'clients',
  'name',
  'clients.name should be required'
);

-- 6: Organization foreign key with cascade delete
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.clients'::regclass
      and conname = 'clients_organization_id_fkey'
      and contype = 'f'
      and confdeltype = 'c'
  ),
  'clients should be deleted when their organization is deleted'
);

-- 7: Creator profile foreign key with restrict delete
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.clients'::regclass
      and conname = 'clients_created_by_fkey'
      and contype = 'f'
      and confdeltype = 'r'
  ),
  'clients.created_by should restrict profile deletion'
);

-- 8: Composite tenant key for future campaign foreign keys
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.clients'::regclass
      and conname = 'clients_organization_id_id_unique'
      and contype = 'u'
  ),
  'clients should have a unique organization_id and id pair'
);

-- 9: Case-insensitive client-name uniqueness per organization
select ok(
  exists (
    select 1
    from pg_index index_definition
    join pg_class index_name
      on index_name.oid = index_definition.indexrelid
    where index_definition.indrelid = 'public.clients'::regclass
      and index_name.relname =
        'clients_organization_name_unique_idx'
      and index_definition.indisunique
      and pg_get_indexdef(index_definition.indexrelid)
        ilike '%organization_id%'
      and pg_get_indexdef(index_definition.indexrelid)
        ilike '%lower(name)%'
  ),
  'client names should be case-insensitively unique per organization'
);

-- 10: Active/archived lookup index
select ok(
  to_regclass(
    'public.clients_organization_archived_at_idx'
  ) is not null,
  'clients should have an organization and archived_at index'
);

-- 11: Validation constraints
select is(
  (
    select count(*)::integer
    from pg_constraint
    where conrelid = 'public.clients'::regclass
      and conname = any (
        array[
          'clients_name_check',
          'clients_contact_name_check',
          'clients_contact_email_check',
          'clients_notes_length_check',
          'clients_archived_at_check'
        ]
      )
  ),
  5,
  'all client validation constraints should exist'
);

-- 12: Updated-at trigger
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.clients'::regclass
      and tgname = 'clients_set_updated_at'
      and not tgisinternal
  ),
  'clients should have an updated_at trigger'
);

-- 13: RLS
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.clients'::regclass
  ),
  'clients should have Row Level Security enabled'
);

-- 14: Anonymous access
select ok(
  not has_table_privilege(
    'anon',
    'public.clients',
    'select'
  )
  and not has_table_privilege(
    'anon',
    'public.clients',
    'insert'
  )
  and not has_table_privilege(
    'anon',
    'public.clients',
    'update'
  )
  and not has_table_privilege(
    'anon',
    'public.clients',
    'delete'
  ),
  'anonymous users should not have client table privileges'
);

-- 15: Authenticated grants
select ok(
  has_table_privilege(
    'authenticated',
    'public.clients',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.clients',
    'insert'
  )
  and has_table_privilege(
    'authenticated',
    'public.clients',
    'update'
  )
  and has_table_privilege(
    'authenticated',
    'public.clients',
    'delete'
  ),
  'authenticated users should have client DML grants'
);

-- 16: Generated UUID and timestamp defaults
select is(
  (
    select count(*)::integer
    from pg_attrdef column_default
    join pg_attribute column_definition
      on column_definition.attrelid = column_default.adrelid
      and column_definition.attnum = column_default.adnum
    where column_default.adrelid = 'public.clients'::regclass
      and column_definition.attname = any (
        array[
          'id',
          'created_at',
          'updated_at'
        ]
      )
  ),
  3,
  'client id and timestamps should have defaults'
);

select * from finish();