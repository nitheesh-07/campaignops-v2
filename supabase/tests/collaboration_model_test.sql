begin;

select plan(48);

select has_table(
  'public',
  target.table_name,
  target.description
)
from (
  values
    ('approvals', 'approvals table exists'),
    ('comments', 'comments table exists'),
    ('attachments', 'attachments table exists')
) as target(table_name, description);

select has_pk(
  'public',
  target.table_name,
  target.description
)
from (
  values
    ('approvals', 'approvals has a primary key'),
    ('comments', 'comments has a primary key'),
    ('attachments', 'attachments has a primary key')
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
      'approvals',
      array[
        'id',
        'organization_id',
        'task_id',
        'status',
        'requested_by',
        'reviewer_id',
        'request_note',
        'response_note',
        'responded_at',
        'created_at',
        'updated_at'
      ]::name[],
      'approvals has the expected columns'
    ),
    (
      'comments',
      array[
        'id',
        'organization_id',
        'task_id',
        'author_id',
        'body',
        'created_at',
        'updated_at'
      ]::name[],
      'comments has the expected columns'
    ),
    (
      'attachments',
      array[
        'id',
        'organization_id',
        'task_id',
        'uploaded_by',
        'file_name',
        'storage_path',
        'mime_type',
        'size_bytes',
        'created_at'
      ]::name[],
      'attachments has the expected columns'
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
      'approvals',
      array[
        'organization_id',
        'task_id',
        'status',
        'requested_by',
        'created_at',
        'updated_at'
      ]::name[],
      'approval required columns are not null'
    ),
    (
      'comments',
      array[
        'organization_id',
        'task_id',
        'author_id',
        'body',
        'created_at',
        'updated_at'
      ]::name[],
      'comment required columns are not null'
    ),
    (
      'attachments',
      array[
        'organization_id',
        'task_id',
        'uploaded_by',
        'file_name',
        'storage_path',
        'mime_type',
        'size_bytes',
        'created_at'
      ]::name[],
      'attachment required columns are not null'
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
      'approvals_organization_id_fkey',
      'comments_organization_id_fkey',
      'attachments_organization_id_fkey'
    )
      and confrelid = 'public.organizations'::regclass
      and contype = 'f'
      and confdeltype = 'c'
  ),
  3::bigint,
  'all collaboration tables cascade when their organization is deleted'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
        ('public.' || target.table_name)::regclass
      and conname = target.constraint_name
      and contype = 'f'
      and confrelid = 'public.tasks'::regclass
      and cardinality(conkey) = 2
      and cardinality(confkey) = 2
      and confdeltype = 'c'
  ),
  target.description
)
from (
  values
    (
      'approvals',
      'approvals_organization_task_fkey',
      'approval has a cascading composite task foreign key'
    ),
    (
      'comments',
      'comments_organization_task_fkey',
      'comment has a cascading composite task foreign key'
    ),
    (
      'attachments',
      'attachments_organization_task_fkey',
      'attachment has a cascading composite task foreign key'
    )
) as target(
  table_name,
  constraint_name,
  description
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
      'approvals',
      'approvals_requested_by_fkey',
      'r'::"char",
      'approval requester deletion is restricted'
    ),
    (
      'approvals',
      'approvals_reviewer_id_fkey',
      'n'::"char",
      'deleted reviewer is set to null'
    ),
    (
      'comments',
      'comments_author_id_fkey',
      'r'::"char",
      'comment author deletion is restricted'
    ),
    (
      'attachments',
      'attachments_uploaded_by_fkey',
      'r'::"char",
      'attachment uploader deletion is restricted'
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
      'approvals',
      'approvals_organization_id_id_unique',
      'approvals has a composite tenant unique key'
    ),
    (
      'comments',
      'comments_organization_id_id_unique',
      'comments has a composite tenant unique key'
    ),
    (
      'attachments',
      'attachments_organization_id_id_unique',
      'attachments has a composite tenant unique key'
    )
) as target(
  table_name,
  constraint_name,
  description
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.attachments'::regclass
      and conname =
        'attachments_organization_storage_path_unique'
      and contype = 'u'
  ),
  'attachment storage paths are unique per organization'
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
      'approvals',
      'approvals_organization_task_created_at_idx',
      array[
        'organization_id',
        'task_id',
        'created_at'
      ]::text[],
      'approval task history index exists'
    ),
    (
      'approvals',
      'approvals_organization_reviewer_status_idx',
      array[
        'organization_id',
        'reviewer_id',
        'status',
        'where',
        'reviewer_id is not null'
      ]::text[],
      'partial approval reviewer index exists'
    ),
    (
      'comments',
      'comments_organization_task_created_at_idx',
      array[
        'organization_id',
        'task_id',
        'created_at'
      ]::text[],
      'comment task timeline index exists'
    ),
    (
      'comments',
      'comments_organization_author_created_at_idx',
      array[
        'organization_id',
        'author_id',
        'created_at'
      ]::text[],
      'comment author index exists'
    ),
    (
      'attachments',
      'attachments_organization_task_created_at_idx',
      array[
        'organization_id',
        'task_id',
        'created_at'
      ]::text[],
      'attachment task timeline index exists'
    ),
    (
      'attachments',
      'attachments_organization_uploader_created_at_idx',
      array[
        'organization_id',
        'uploaded_by',
        'created_at'
      ]::text[],
      'attachment uploader index exists'
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
      'approvals',
      'approvals_request_note_check',
      'approval request-note validation exists'
    ),
    (
      'approvals',
      'approvals_response_note_check',
      'approval response-note validation exists'
    ),
    (
      'approvals',
      'approvals_response_state_check',
      'approval response-state validation exists'
    ),
    (
      'approvals',
      'approvals_responded_at_check',
      'approval response-time validation exists'
    ),
    (
      'comments',
      'comments_body_check',
      'comment body validation exists'
    ),
    (
      'attachments',
      'attachments_file_name_check',
      'attachment filename validation exists'
    ),
    (
      'attachments',
      'attachments_storage_path_check',
      'attachment storage-path validation exists'
    ),
    (
      'attachments',
      'attachments_mime_type_check',
      'attachment MIME-type validation exists'
    ),
    (
      'attachments',
      'attachments_size_bytes_check',
      'attachment file-size validation exists'
    )
) as target(
  table_name,
  constraint_name,
  description
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_definition
    where trigger_definition.tgrelid =
        ('public.' || target.table_name)::regclass
      and trigger_definition.tgname =
        target.trigger_name
      and not trigger_definition.tgisinternal
      and trigger_definition.tgenabled <> 'D'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%before update%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%set_updated_at%'
  ),
  target.description
)
from (
  values
    (
      'approvals',
      'approvals_set_updated_at',
      'approval updated_at trigger exists'
    ),
    (
      'comments',
      'comments_set_updated_at',
      'comment updated_at trigger exists'
    )
) as target(
  table_name,
  trigger_name,
  description
);

select is(
  (
    select count(*)
    from pg_class
    where oid in (
      'public.approvals'::regclass,
      'public.comments'::regclass,
      'public.attachments'::regclass
    )
      and relrowsecurity
  ),
  3::bigint,
  'RLS is enabled on all collaboration tables'
);

select ok(
  not exists (
    select 1
    from (
      values
        ('approvals'),
        ('comments'),
        ('attachments')
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
  'anonymous users have no collaboration CRUD privileges'
);

select ok(
  not exists (
    select 1
    from (
      values
        ('approvals'),
        ('comments'),
        ('attachments')
    ) as target(table_name)
    cross join (
      values
        ('select'),
        ('insert'),
        ('update'),
        ('delete')
    ) as required(privilege_name)
    where not has_table_privilege(
      'authenticated',
      'public.' || target.table_name,
      required.privilege_name
    )
  ),
  'authenticated users have collaboration CRUD privileges'
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
      'approvals',
      array[
        'id',
        'status',
        'created_at',
        'updated_at'
      ]::name[],
      'approval identifiers, status, and timestamps have defaults'
    ),
    (
      'comments',
      array[
        'id',
        'created_at',
        'updated_at'
      ]::name[],
      'comment identifiers and timestamps have defaults'
    ),
    (
      'attachments',
      array[
        'id',
        'created_at'
      ]::name[],
      'attachment identifiers and timestamps have defaults'
    )
) as target(
  table_name,
  default_columns,
  description
);

select ok(
  (
    select pg_get_expr(
      default_definition.adbin,
      default_definition.adrelid
    ) ilike '%pending%'
    from pg_attribute as column_definition
    join pg_attrdef as default_definition
      on default_definition.adrelid =
        column_definition.attrelid
      and default_definition.adnum =
        column_definition.attnum
    where column_definition.attrelid =
        'public.approvals'::regclass
      and column_definition.attname = 'status'
  ),
  'approval status defaults to pending'
);

select * from finish();

rollback;