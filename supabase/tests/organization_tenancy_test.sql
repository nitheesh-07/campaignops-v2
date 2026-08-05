select plan(24);

-- 1–3: Required tables
select has_table(
  'public',
  'organizations',
  'organizations table should exist'
);

select has_table(
  'public',
  'organization_members',
  'organization_members table should exist'
);

select has_table(
  'public',
  'organization_invitations',
  'organization_invitations table should exist'
);

-- 4–6: Primary keys
select has_pk(
  'public',
  'organizations',
  'organizations should have a primary key'
);

select has_pk(
  'public',
  'organization_members',
  'organization_members should have a primary key'
);

select has_pk(
  'public',
  'organization_invitations',
  'organization_invitations should have a primary key'
);

-- 7: Membership composite primary key
select is(
  (
    select string_agg(attribute.attname, ',' order by key_column.position)
    from pg_index index_definition
    cross join lateral unnest(index_definition.indkey)
      with ordinality as key_column(attribute_number, position)
    join pg_attribute attribute
      on attribute.attrelid = index_definition.indrelid
      and attribute.attnum = key_column.attribute_number
    where index_definition.indrelid =
      'public.organization_members'::regclass
      and index_definition.indisprimary
  ),
  'organization_id,user_id',
  'membership primary key should contain organization_id and user_id'
);

-- 8: Unique organization slug
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.organizations'::regclass
      and conname = 'organizations_slug_unique'
      and contype = 'u'
  ),
  'organization slug should have a unique constraint'
);

-- 9: Organization creator foreign key
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.organizations'::regclass
      and conname = 'organizations_created_by_fkey'
      and contype = 'f'
  ),
  'organizations.created_by should have a foreign key'
);

-- 10: Organization membership should be deleted with its organization
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.organization_members'::regclass
      and conname = 'organization_members_organization_id_fkey'
      and contype = 'f'
      and confdeltype = 'c'
  ),
  'organization membership should cascade when an organization is deleted'
);

-- 11: User membership should be deleted with its profile
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.organization_members'::regclass
      and conname = 'organization_members_user_id_fkey'
      and contype = 'f'
      and confdeltype = 'c'
  ),
  'organization membership should cascade when a profile is deleted'
);

-- 12: Invitations should be deleted with their organization
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.organization_invitations'::regclass
      and conname = 'organization_invitations_organization_id_fkey'
      and contype = 'f'
      and confdeltype = 'c'
  ),
  'organization invitations should cascade when an organization is deleted'
);

-- 13: Invitation creator foreign key
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.organization_invitations'::regclass
      and conname = 'organization_invitations_invited_by_fkey'
      and contype = 'f'
  ),
  'organization_invitations.invited_by should have a foreign key'
);

-- 14: Membership role uses the organization_role enum
select is(
  (
    select format('%s.%s', type_schema.nspname, data_type.typname)
    from pg_attribute attribute
    join pg_class table_definition
      on table_definition.oid = attribute.attrelid
    join pg_namespace table_schema
      on table_schema.oid = table_definition.relnamespace
    join pg_type data_type
      on data_type.oid = attribute.atttypid
    join pg_namespace type_schema
      on type_schema.oid = data_type.typnamespace
    where table_schema.nspname = 'public'
      and table_definition.relname = 'organization_members'
      and attribute.attname = 'role'
  ),
  'public.organization_role',
  'membership role should use the organization_role enum'
);

-- 15: Invitation role uses the organization_role enum
select is(
  (
    select format('%s.%s', type_schema.nspname, data_type.typname)
    from pg_attribute attribute
    join pg_class table_definition
      on table_definition.oid = attribute.attrelid
    join pg_namespace table_schema
      on table_schema.oid = table_definition.relnamespace
    join pg_type data_type
      on data_type.oid = attribute.atttypid
    join pg_namespace type_schema
      on type_schema.oid = data_type.typnamespace
    where table_schema.nspname = 'public'
      and table_definition.relname = 'organization_invitations'
      and attribute.attname = 'role'
  ),
  'public.organization_role',
  'invitation role should use the organization_role enum'
);

-- 16: Invitation token hashes must be unique
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.organization_invitations'::regclass
      and conname = 'organization_invitations_token_hash_unique'
      and contype = 'u'
  ),
  'invitation token hashes should be unique'
);

-- 17: Pending invitation emails use a case-insensitive unique index
select ok(
  exists (
    select 1
    from pg_index index_definition
    join pg_class index_name
      on index_name.oid = index_definition.indexrelid
    where index_definition.indrelid =
      'public.organization_invitations'::regclass
      and index_name.relname =
        'organization_invitations_pending_email_idx'
      and index_definition.indisunique
      and pg_get_indexdef(index_definition.indexrelid)
        ilike '%lower(email)%'
      and pg_get_expr(
        index_definition.indpred,
        index_definition.indrelid
      ) ilike '%accepted_at IS NULL%'
  ),
  'pending invitation email index should be case-insensitive and unique'
);

-- 18: Required validation constraints
select is(
  (
    select count(*)::integer
    from pg_constraint
    where conname = any (
      array[
        'organizations_name_length_check',
        'organizations_slug_format_check',
        'organization_invitations_email_check',
        'organization_invitations_role_check',
        'organization_invitations_token_hash_check',
        'organization_invitations_expiry_check',
        'organization_invitations_accepted_at_check'
      ]
    )
  ),
  7,
  'all organization and invitation validation constraints should exist'
);

-- 19: Membership lookup indexes
select ok(
  to_regclass('public.organization_members_user_id_idx') is not null
  and to_regclass(
    'public.organization_members_organization_role_idx'
  ) is not null,
  'organization membership lookup indexes should exist'
);

-- 20: Invitation expiry index
select ok(
  to_regclass(
    'public.organization_invitations_expires_at_idx'
  ) is not null,
  'invitation expiry index should exist'
);

-- 21–22: Updated-at triggers
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.organizations'::regclass
      and tgname = 'organizations_set_updated_at'
      and not tgisinternal
  ),
  'organizations should have an updated_at trigger'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.organization_members'::regclass
      and tgname = 'organization_members_set_updated_at'
      and not tgisinternal
  ),
  'organization_members should have an updated_at trigger'
);

-- 23: RLS on all tenant tables
select ok(
  (
    select bool_and(table_definition.relrowsecurity)
    from pg_class table_definition
    join pg_namespace table_schema
      on table_schema.oid = table_definition.relnamespace
    where table_schema.nspname = 'public'
      and table_definition.relname in (
        'organizations',
        'organization_members',
        'organization_invitations'
      )
  ),
  'all organization tenancy tables should have RLS enabled'
);

-- 24: Privilege model
select ok(
  not has_table_privilege(
    'anon',
    'public.organizations',
    'select'
  )
  and not has_table_privilege(
    'anon',
    'public.organization_members',
    'select'
  )
  and not has_table_privilege(
    'anon',
    'public.organization_invitations',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.organizations',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.organizations',
    'insert'
  )
  and has_table_privilege(
    'authenticated',
    'public.organizations',
    'update'
  )
  and has_table_privilege(
    'authenticated',
    'public.organizations',
    'delete'
  )
  and has_table_privilege(
    'authenticated',
    'public.organization_members',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.organization_members',
    'insert'
  )
  and has_table_privilege(
    'authenticated',
    'public.organization_members',
    'update'
  )
  and has_table_privilege(
    'authenticated',
    'public.organization_members',
    'delete'
  )
  and has_table_privilege(
    'authenticated',
    'public.organization_invitations',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.organization_invitations',
    'insert'
  )
  and has_table_privilege(
    'authenticated',
    'public.organization_invitations',
    'update'
  )
  and has_table_privilege(
    'authenticated',
    'public.organization_invitations',
    'delete'
  ),
  'anonymous access should be denied and authenticated DML granted'
);

select * from finish();