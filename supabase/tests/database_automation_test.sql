begin;

select plan(38);

select ok(
  exists (
    select 1
    from pg_proc as function_definition
    join pg_namespace as schema_definition
      on schema_definition.oid =
        function_definition.pronamespace
    where schema_definition.nspname = 'public'
      and function_definition.proname =
        target.function_name
      and pg_catalog.oidvectortypes(
        function_definition.proargtypes
      ) = target.argument_types
  ),
  target.description
)
from (
  values
    (
      'sync_task_completed_at',
      '',
      'task completion function exists'
    ),
    (
      'audit_business_change',
      '',
      'business audit function exists'
    ),
    (
      'create_internal_notification',
      'uuid, uuid, text, text, text, text, uuid',
      'internal notification function exists'
    ),
    (
      'notify_task_assignment',
      '',
      'task-assignment notification function exists'
    ),
    (
      'notify_approval_event',
      '',
      'approval-event notification function exists'
    )
) as target(
  function_name,
  argument_types,
  description
);

select is(
  (
    select function_definition.prosecdef
    from pg_proc as function_definition
    join pg_namespace as schema_definition
      on schema_definition.oid =
        function_definition.pronamespace
    where schema_definition.nspname = 'public'
      and function_definition.proname =
        target.function_name
      and pg_catalog.oidvectortypes(
        function_definition.proargtypes
      ) = target.argument_types
  ),
  target.expected_security_definer,
  target.description
)
from (
  values
    (
      'sync_task_completed_at',
      '',
      false,
      'task completion function uses invoker security'
    ),
    (
      'audit_business_change',
      '',
      true,
      'audit function uses definer security'
    ),
    (
      'create_internal_notification',
      'uuid, uuid, text, text, text, text, uuid',
      true,
      'internal notification function uses definer security'
    ),
    (
      'notify_task_assignment',
      '',
      true,
      'task notification function uses definer security'
    ),
    (
      'notify_approval_event',
      '',
      true,
      'approval notification function uses definer security'
    )
) as target(
  function_name,
  argument_types,
  expected_security_definer,
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
        target.function_name
      and pg_catalog.oidvectortypes(
        function_definition.proargtypes
      ) = target.argument_types
      and exists (
        select 1
        from unnest(
          coalesce(
            function_definition.proconfig,
            array[]::text[]
          )
        ) as configuration(setting)
        where split_part(
          configuration.setting,
          '=',
          1
        ) = 'search_path'
          and split_part(
            configuration.setting,
            '=',
            2
          ) in ('', '""')
      )
  ),
  target.description
)
from (
  values
    (
      'sync_task_completed_at',
      '',
      'task completion function has an empty search path'
    ),
    (
      'audit_business_change',
      '',
      'audit function has an empty search path'
    ),
    (
      'create_internal_notification',
      'uuid, uuid, text, text, text, text, uuid',
      'internal notification function has an empty search path'
    ),
    (
      'notify_task_assignment',
      '',
      'task notification function has an empty search path'
    ),
    (
      'notify_approval_event',
      '',
      'approval notification function has an empty search path'
    )
) as target(
  function_name,
  argument_types,
  description
);

select ok(
  not exists (
    select 1
    from (
      values
        (
          'sync_task_completed_at',
          ''
        ),
        (
          'audit_business_change',
          ''
        ),
        (
          'create_internal_notification',
          'uuid, uuid, text, text, text, text, uuid'
        ),
        (
          'notify_task_assignment',
          ''
        ),
        (
          'notify_approval_event',
          ''
        )
    ) as target(
      function_name,
      argument_types
    )
    join pg_proc as function_definition
      on function_definition.proname =
        target.function_name
      and pg_catalog.oidvectortypes(
        function_definition.proargtypes
      ) = target.argument_types
    join pg_namespace as schema_definition
      on schema_definition.oid =
        function_definition.pronamespace
      and schema_definition.nspname = 'public'
    cross join (
      values
        ('anon'),
        ('authenticated')
    ) as application_role(role_name)
    where has_function_privilege(
      application_role.role_name,
      function_definition.oid,
      'execute'
    )
  ),
  'application roles cannot execute protected automation functions'
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_definition
    where trigger_definition.tgrelid =
        'public.tasks'::regclass
      and trigger_definition.tgname =
        'tasks_sync_completed_at'
      and not trigger_definition.tgisinternal
      and trigger_definition.tgenabled <> 'D'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%before%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%insert%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%update%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%sync_task_completed_at%'
  ),
  'task completion synchronization trigger exists'
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
        ilike '%after%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%insert%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%update%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%delete%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%audit_business_change%'
  ),
  target.description
)
from (
  values
    (
      'clients',
      'clients_audit_changes',
      'clients audit trigger exists'
    ),
    (
      'campaigns',
      'campaigns_audit_changes',
      'campaigns audit trigger exists'
    ),
    (
      'tasks',
      'tasks_audit_changes',
      'tasks audit trigger exists'
    ),
    (
      'approvals',
      'approvals_audit_changes',
      'approvals audit trigger exists'
    ),
    (
      'comments',
      'comments_audit_changes',
      'comments audit trigger exists'
    ),
    (
      'attachments',
      'attachments_audit_changes',
      'attachments audit trigger exists'
    )
) as target(
  table_name,
  trigger_name,
  description
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_definition
    where trigger_definition.tgrelid =
        'public.tasks'::regclass
      and trigger_definition.tgname =
        'tasks_notify_assignment'
      and not trigger_definition.tgisinternal
      and trigger_definition.tgenabled <> 'D'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%after%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%insert%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%update%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%assignee_id%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%notify_task_assignment%'
  ),
  'task assignment notification trigger exists'
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_definition
    where trigger_definition.tgrelid =
        'public.approvals'::regclass
      and trigger_definition.tgname =
        'approvals_notify_event'
      and not trigger_definition.tgisinternal
      and trigger_definition.tgenabled <> 'D'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%after%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%insert%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%update%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%reviewer_id%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%status%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%notify_approval_event%'
  ),
  'approval notification trigger exists'
);

select ok(
  not exists (
    select 1
    from pg_trigger as trigger_definition
    join pg_proc as function_definition
      on function_definition.oid =
        trigger_definition.tgfoid
    where trigger_definition.tgrelid in (
      'public.audit_logs'::regclass,
      'public.notifications'::regclass
    )
      and function_definition.proname =
        'audit_business_change'
  ),
  'audit and notification tables do not recursively audit themselves'
);

select ok(
  pg_get_functiondef(
    'public.audit_business_change()'::regprocedure
  ) ilike '%auth.uid()%',
  'audit function records the authenticated actor'
);

select ok(
  pg_get_functiondef(
    'public.audit_business_change()'::regprocedure
  ) ilike '%insert into public.audit_logs%',
  'audit function writes to the audit log table'
);

select ok(
  pg_get_functiondef(
    'public.create_internal_notification(uuid,uuid,text,text,text,text,uuid)'::regprocedure
  ) ilike '%insert into public.notifications%',
  'internal notification function writes notifications'
);

select ok(
  pg_get_functiondef(
    'public.notify_task_assignment()'::regprocedure
  ) ilike '%task_assigned%'
  and pg_get_functiondef(
    'public.notify_task_assignment()'::regprocedure
  ) ilike '%create_internal_notification%',
  'task notification function creates task-assigned notifications'
);

select ok(
  pg_get_functiondef(
    'public.notify_approval_event()'::regprocedure
  ) ilike '%approval_requested%'
  and pg_get_functiondef(
    'public.notify_approval_event()'::regprocedure
  ) ilike '%approval_updated%'
  and pg_get_functiondef(
    'public.notify_approval_event()'::regprocedure
  ) ilike '%create_internal_notification%',
  'approval function creates request and update notifications'
);

create temporary table task_sync_probe (
  id integer primary key,
  status text not null,
  completed_at timestamptz
);

create trigger task_sync_probe_trigger
before insert or update on task_sync_probe
for each row
execute function public.sync_task_completed_at();

insert into task_sync_probe (
  id,
  status
)
values
  (1, 'done'),
  (2, 'todo');

select ok(
  (
    select completed_at is not null
    from task_sync_probe
    where id = 1
  ),
  'inserting a done task sets completed_at'
);

select ok(
  (
    select completed_at is null
    from task_sync_probe
    where id = 2
  ),
  'inserting a todo task leaves completed_at empty'
);

update task_sync_probe
set status = 'done'
where id = 2;

select ok(
  (
    select completed_at is not null
    from task_sync_probe
    where id = 2
  ),
  'moving a task to done sets completed_at'
);

update task_sync_probe
set status = 'todo'
where id = 1;

select ok(
  (
    select completed_at is null
    from task_sync_probe
    where id = 1
  ),
  'reopening a completed task clears completed_at'
);

select ok(
  (
    select function_definition.prorettype =
      'uuid'::regtype
    from pg_proc as function_definition
    where function_definition.oid =
      'public.create_internal_notification(uuid,uuid,text,text,text,text,uuid)'::regprocedure
  ),
  'internal notification function returns a UUID'
);

select is(
  (
    select count(*)
    from pg_proc as function_definition
    where function_definition.oid in (
      'public.sync_task_completed_at()'::regprocedure,
      'public.audit_business_change()'::regprocedure,
      'public.notify_task_assignment()'::regprocedure,
      'public.notify_approval_event()'::regprocedure
    )
      and function_definition.prorettype =
        'trigger'::regtype
  ),
  4::bigint,
  'all automation trigger functions return trigger'
);

select ok(
  pg_get_functiondef(
    'public.audit_business_change()'::regprocedure
  ) ilike '%tg_op = ''INSERT''%'
  and pg_get_functiondef(
    'public.audit_business_change()'::regprocedure
  ) ilike '%tg_op = ''UPDATE''%'
  and pg_get_functiondef(
    'public.audit_business_change()'::regprocedure
  ) ilike '%tg_op = ''DELETE''%',
  'audit function handles inserts, updates, and deletes'
);

select * from finish();

rollback;