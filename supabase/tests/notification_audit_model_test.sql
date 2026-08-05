begin;

select plan(37);

select has_table(
  'public',
  target.table_name,
  target.description
)
from (
  values
    ('notifications', 'notifications table exists'),
    ('audit_logs', 'audit_logs table exists')
) as target(table_name, description);

select has_pk(
  'public',
  target.table_name,
  target.description
)
from (
  values
    ('notifications', 'notifications has a primary key'),
    ('audit_logs', 'audit_logs has a primary key')
) as target(table_name, description);

select columns_are(
  'public',
  target.table_name,
  target.expected_columns,
  target.description
)
from (
  values
    (
      'notifications',
      array[
        'id',
        'organization_id',
        'recipient_id',
        'kind',
        'title',
        'message',
        'entity_type',
        'entity_id',
        'read_at',
        'created_at'
      ]::name[],
      'notifications has the expected columns'
    ),
    (
      'audit_logs',
      array[
        'id',
        'organization_id',
        'actor_id',
        'action',
        'entity_type',
        'entity_id',
        'old_data',
        'new_data',
        'created_at'
      ]::name[],
      'audit_logs has the expected columns'
    )
) as target(
  table_name,
  expected_columns,
  description
);

select ok(
  not exists (
    select 1
    from unnest(target.required_columns)
      as required(column_name)
    where not exists (
      select 1
      from pg_attribute as column_definition
      where column_definition.attrelid =
        ('public.' || target.table_name)::regclass
        and column_definition.attname =
          required.column_name
        and column_definition.attnotnull
        and not column_definition.attisdropped
    )
  ),
  target.description
)
from (
  values
    (
      'notifications',
      array[
        'organization_id',
        'recipient_id',
        'kind',
        'title',
        'message',
        'created_at'
      ]::name[],
      'notification required columns are not null'
    ),
    (
      'audit_logs',
      array[
        'organization_id',
        'action',
        'entity_type',
        'entity_id',
        'created_at'
      ]::name[],
      'audit-log required columns are not null'
    )
) as target(
  table_name,
  required_columns,
  description
);

select is(
  (
    select count(*)
    from pg_constraint
    where conname in (
      'notifications_organization_id_fkey',
      'audit_logs_organization_id_fkey'
    )
      and confrelid = 'public.organizations'::regclass
      and contype = 'f'
      and confdeltype = 'c'
  ),
  2::bigint,
  'notification and audit organization foreign keys cascade'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
        ('public.' || target.table_name)::regclass
      and conname = target.constraint_name
      and contype = 'f'
      and confrelid = 'public.profiles'::regclass
      and confdeltype = target.delete_action
  ),
  target.description
)
from (
  values
    (
      'notifications',
      'notifications_recipient_id_fkey',
      'c'::"char",
      'recipient deletion cascades notifications'
    ),
    (
      'audit_logs',
      'audit_logs_actor_id_fkey',
      'n'::"char",
      'deleted audit actor is set to null'
    )
) as target(
  table_name,
  constraint_name,
  delete_action,
  description
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
        ('public.' || target.table_name)::regclass
      and conname = target.constraint_name
      and contype = 'u'
  ),
  target.description
)
from (
  values
    (
      'notifications',
      'notifications_organization_id_id_unique',
      'notifications has a composite tenant unique key'
    ),
    (
      'audit_logs',
      'audit_logs_organization_id_id_unique',
      'audit_logs has a composite tenant unique key'
    )
) as target(
  table_name,
  constraint_name,
  description
);

select ok(
  exists (
    select 1
    from pg_indexes as index_definition
    where index_definition.schemaname = 'public'
      and index_definition.tablename =
        target.table_name
      and index_definition.indexname =
        target.index_name
      and not exists (
        select 1
        from unnest(target.required_fragments)
          as required(fragment)
        where index_definition.indexdef not ilike
          ('%' || required.fragment || '%')
      )
  ),
  target.description
)
from (
  values
    (
      'notifications',
      'notifications_recipient_created_at_idx',
      array[
        'organization_id',
        'recipient_id',
        'created_at'
      ]::text[],
      'notification recipient timeline index exists'
    ),
    (
      'notifications',
      'notifications_unread_recipient_idx',
      array[
        'organization_id',
        'recipient_id',
        'created_at',
        'where',
        'read_at is null'
      ]::text[],
      'partial unread notification index exists'
    ),
    (
      'notifications',
      'notifications_entity_idx',
      array[
        'organization_id',
        'entity_type',
        'entity_id',
        'where',
        'entity_id is not null'
      ]::text[],
      'partial notification entity index exists'
    ),
    (
      'audit_logs',
      'audit_logs_organization_created_at_idx',
      array[
        'organization_id',
        'created_at'
      ]::text[],
      'audit organization timeline index exists'
    ),
    (
      'audit_logs',
      'audit_logs_entity_created_at_idx',
      array[
        'organization_id',
        'entity_type',
        'entity_id',
        'created_at'
      ]::text[],
      'audit entity timeline index exists'
    ),
    (
      'audit_logs',
      'audit_logs_actor_created_at_idx',
      array[
        'organization_id',
        'actor_id',
        'created_at',
        'where',
        'actor_id is not null'
      ]::text[],
      'partial audit actor index exists'
    )
) as target(
  table_name,
  index_name,
  required_fragments,
  description
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
        ('public.' || target.table_name)::regclass
      and conname = target.constraint_name
      and contype = 'c'
  ),
  target.description
)
from (
  values
    (
      'notifications',
      'notifications_kind_check',
      'notification kind validation exists'
    ),
    (
      'notifications',
      'notifications_title_check',
      'notification title validation exists'
    ),
    (
      'notifications',
      'notifications_message_check',
      'notification message validation exists'
    ),
    (
      'notifications',
      'notifications_entity_reference_check',
      'notification entity-reference validation exists'
    ),
    (
      'notifications',
      'notifications_read_at_check',
      'notification read-time validation exists'
    ),
    (
      'audit_logs',
      'audit_logs_action_check',
      'audit action validation exists'
    ),
    (
      'audit_logs',
      'audit_logs_entity_type_check',
      'audit entity-type validation exists'
    ),
    (
      'audit_logs',
      'audit_logs_old_data_check',
      'audit old-data JSON validation exists'
    ),
    (
      'audit_logs',
      'audit_logs_new_data_check',
      'audit new-data JSON validation exists'
    ),
    (
      'audit_logs',
      'audit_logs_change_data_check',
      'audit change-data validation exists'
    )
) as target(
  table_name,
  constraint_name,
  description
);

select ok(
  exists (
    select 1
    from pg_proc as function_definition
    join pg_namespace as schema_definition
      on schema_definition.oid =
        function_definition.pronamespace
    where schema_definition.nspname = 'public'
      and function_definition.proname =
        'prevent_audit_log_mutation'
      and function_definition.prorettype =
        'trigger'::regtype
      and not function_definition.prosecdef
  ),
  'audit mutation prevention function exists'
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_definition
    where trigger_definition.tgrelid =
        'public.audit_logs'::regclass
      and trigger_definition.tgname =
        'audit_logs_prevent_mutation'
      and not trigger_definition.tgisinternal
      and trigger_definition.tgenabled <> 'D'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%before%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%update%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%delete%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%prevent_audit_log_mutation%'
  ),
  'audit mutation prevention trigger exists'
);

select is(
  (
    select count(*)
    from pg_class
    where oid in (
      'public.notifications'::regclass,
      'public.audit_logs'::regclass
    )
      and relrowsecurity
  ),
  2::bigint,
  'RLS is enabled on notifications and audit logs'
);

select ok(
  not exists (
    select 1
    from (
      values
        ('notifications'),
        ('audit_logs')
    ) as target(table_name)
    cross join (
      values
        ('select'),
        ('insert'),
        ('update'),
        ('delete')
    ) as required(privilege_name)
    where has_table_privilege(
      'anon',
      'public.' || target.table_name,
      required.privilege_name
    )
  ),
  'anonymous users have no notification or audit privileges'
);

select ok(
  has_table_privilege(
    'authenticated',
    'public.notifications',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.notifications',
    'delete'
  )
  and not has_table_privilege(
    'authenticated',
    'public.notifications',
    'insert'
  )
  and not exists (
    select 1
    from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'notifications'
      and privilege_type = 'UPDATE'
  )
  and has_column_privilege(
    'authenticated',
    'public.notifications',
    'read_at',
    'update'
  )
  and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notifications'
      and column_name <> 'read_at'
      and has_column_privilege(
        'authenticated',
        'public.notifications',
        column_name,
        'update'
      )
  ),
  'authenticated notification privileges follow least privilege'
);

select ok(
  has_table_privilege(
    'authenticated',
    'public.audit_logs',
    'select'
  )
  and not has_table_privilege(
    'authenticated',
    'public.audit_logs',
    'insert'
  )
  and not has_table_privilege(
    'authenticated',
    'public.audit_logs',
    'update'
  )
  and not has_table_privilege(
    'authenticated',
    'public.audit_logs',
    'delete'
  ),
  'authenticated audit-log access is read-only'
);

select ok(
  not exists (
    select 1
    from unnest(target.default_columns)
      as required(column_name)
    where not exists (
      select 1
      from pg_attribute as column_definition
      join pg_attrdef as default_definition
        on default_definition.adrelid =
          column_definition.attrelid
        and default_definition.adnum =
          column_definition.attnum
      where column_definition.attrelid =
          ('public.' || target.table_name)::regclass
        and column_definition.attname =
          required.column_name
    )
  ),
  target.description
)
from (
  values
    (
      'notifications',
      array[
        'id',
        'created_at'
      ]::name[],
      'notification identifiers and timestamps have defaults'
    ),
    (
      'audit_logs',
      array[
        'id',
        'created_at'
      ]::name[],
      'audit identifiers and timestamps have defaults'
    )
) as target(
  table_name,
  default_columns,
  description
);

select * from finish();

rollback;