begin;

select plan(45);

select is(
  (
    select count(*)
    from pg_proc as function_definition
    where function_definition.oid in (
      'public.is_user_organization_member(uuid,uuid)'::regprocedure,
      'public.is_organization_member(uuid)'::regprocedure,
      'public.has_organization_role(uuid,public.organization_role[])'::regprocedure,
      'public.can_view_profile(uuid)'::regprocedure
    )
      and function_definition.prosecdef
      and exists (
        select 1
        from unnest(
          coalesce(
            function_definition.proconfig,
            array[]::text[]
          )
        ) as configuration(setting)
        where split_part(configuration.setting, '=', 1) =
          'search_path'
          and split_part(configuration.setting, '=', 2)
            in ('', '""')
      )
  ),
  4::bigint,
  'all RLS helper functions use definer security and empty search paths'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.is_user_organization_member(uuid,uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.is_organization_member(uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.has_organization_role(uuid,public.organization_role[])',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.can_view_profile(uuid)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.is_user_organization_member(uuid,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.is_organization_member(uuid)',
    'execute'
  ),
  'helper function execution is restricted to authenticated users'
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_definition
    where trigger_definition.tgrelid =
        'public.organizations'::regclass
      and trigger_definition.tgname =
        'organizations_add_creator_as_owner'
      and not trigger_definition.tgisinternal
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%after insert%'
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%add_organization_creator_as_owner%'
  ),
  'organization creator bootstrap trigger exists'
);

select is(
  (
    select count(*)
    from pg_trigger
    where tgname in (
      'organizations_protect_identity',
      'organization_members_protect_identity',
      'organization_invitations_protect_identity',
      'clients_protect_identity',
      'campaigns_protect_identity',
      'tasks_protect_identity',
      'approvals_protect_identity',
      'comments_protect_identity',
      'attachments_protect_identity',
      'notifications_protect_identity'
    )
      and not tgisinternal
  ),
  10::bigint,
  'immutable identity triggers protect all required tables'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = target.table_name
      and policyname = any(target.policy_names)
  ),
  cardinality(target.policy_names)::bigint,
  target.description
)
from (
  values
    (
      'profiles',
      array[
        'profiles_select_shared_organization'
      ]::name[],
      'shared-organization profile policy exists'
    ),
    (
      'organizations',
      array[
        'organizations_select_members',
        'organizations_insert_creator',
        'organizations_update_owner',
        'organizations_delete_owner'
      ]::name[],
      'organization policies exist'
    ),
    (
      'organization_members',
      array[
        'organization_members_select_members',
        'organization_members_insert_owner',
        'organization_members_update_owner',
        'organization_members_delete_owner',
        'organization_members_leave_self'
      ]::name[],
      'organization membership policies exist'
    ),
    (
      'organization_invitations',
      array[
        'organization_invitations_select_admin',
        'organization_invitations_insert_admin',
        'organization_invitations_update_admin',
        'organization_invitations_delete_admin'
      ]::name[],
      'organization invitation policies exist'
    ),
    (
      'clients',
      array[
        'clients_select_members',
        'clients_insert_admin',
        'clients_update_admin',
        'clients_delete_admin'
      ]::name[],
      'client policies exist'
    ),
    (
      'campaigns',
      array[
        'campaigns_select_members',
        'campaigns_insert_admin',
        'campaigns_update_admin',
        'campaigns_delete_admin'
      ]::name[],
      'campaign policies exist'
    ),
    (
      'tasks',
      array[
        'tasks_select_members',
        'tasks_insert_members',
        'tasks_update_members',
        'tasks_delete_admin_or_creator'
      ]::name[],
      'task policies exist'
    ),
    (
      'approvals',
      array[
        'approvals_select_members',
        'approvals_insert_members',
        'approvals_update_reviewer_or_admin',
        'approvals_delete_requester_or_admin'
      ]::name[],
      'approval policies exist'
    ),
    (
      'comments',
      array[
        'comments_select_members',
        'comments_insert_author',
        'comments_update_author',
        'comments_delete_author_or_admin'
      ]::name[],
      'comment policies exist'
    ),
    (
      'attachments',
      array[
        'attachments_select_members',
        'attachments_insert_uploader',
        'attachments_delete_uploader_or_admin'
      ]::name[],
      'attachment policies exist'
    ),
    (
      'notifications',
      array[
        'notifications_select_recipient',
        'notifications_update_recipient',
        'notifications_delete_recipient'
      ]::name[],
      'notification policies exist'
    ),
    (
      'audit_logs',
      array[
        'audit_logs_select_members'
      ]::name[],
      'audit-log policy exists'
    )
) as target(
  table_name,
  policy_names,
  description
);

select is(
  (
    select count(*)
    from pg_class as table_definition
    where table_definition.oid in (
      'public.profiles'::regclass,
      'public.organizations'::regclass,
      'public.organization_members'::regclass,
      'public.organization_invitations'::regclass,
      'public.clients'::regclass,
      'public.campaigns'::regclass,
      'public.tasks'::regclass,
      'public.approvals'::regclass,
      'public.comments'::regclass,
      'public.attachments'::regclass,
      'public.notifications'::regclass,
      'public.audit_logs'::regclass
    )
      and table_definition.relrowsecurity
  ),
  12::bigint,
  'RLS is enabled on every private application table'
);

create function pg_temp.sqlstate_of(
  statement_to_execute text
)
returns text
language plpgsql
security invoker
as $$
begin
  execute statement_to_execute;
  return null;
exception
  when others then
    return sqlstate;
end;
$$;

insert into auth.users (
  id,
  email,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    'owner-a@example.test',
    '{"display_name":"Owner A","full_name":"Owner A"}',
    now(),
    now()
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    'manager-a@example.test',
    '{"display_name":"Manager A","full_name":"Manager A"}',
    now(),
    now()
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    'member-a@example.test',
    '{"display_name":"Member A","full_name":"Member A"}',
    now(),
    now()
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    'owner-b@example.test',
    '{"display_name":"Owner B","full_name":"Owner B"}',
    now(),
    now()
  );

insert into public.organizations (
  id,
  name,
  slug,
  created_by
)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'Organization A',
    'organization-a',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'Organization B',
    'organization-b',
    '44444444-4444-4444-4444-444444444444'
  );

insert into public.organization_members (
  organization_id,
  user_id,
  role
)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    '22222222-2222-2222-2222-222222222222',
    'manager'
  ),
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    '33333333-3333-3333-3333-333333333333',
    'member'
  );

insert into public.clients (
  id,
  organization_id,
  name,
  created_by
)
values
  (
    'cccccccc-cccc-cccc-cccc-ccccccccccc1',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'Client A',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'dddddddd-dddd-dddd-dddd-ddddddddddd1',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'Client B',
    '44444444-4444-4444-4444-444444444444'
  );

insert into public.campaigns (
  id,
  organization_id,
  client_id,
  name,
  created_by
)
values
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'cccccccc-cccc-cccc-cccc-ccccccccccc1',
    'Campaign A',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'ffffffff-ffff-ffff-ffff-fffffffffff1',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'dddddddd-dddd-dddd-dddd-ddddddddddd1',
    'Campaign B',
    '44444444-4444-4444-4444-444444444444'
  );

insert into public.notifications (
  id,
  organization_id,
  recipient_id,
  kind,
  title,
  message
)
values
  (
    '55555555-5555-5555-5555-555555555551',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    '33333333-3333-3333-3333-333333333333',
    'test_notice',
    'Member notification',
    'This notification belongs to the member.'
  ),
  (
    '55555555-5555-5555-5555-555555555552',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    '22222222-2222-2222-2222-222222222222',
    'test_notice',
    'Manager notification',
    'This notification belongs to the manager.'
  );

select is(
  (
    select count(*)
    from public.organization_members
    where role = 'owner'
      and (
        (
          organization_id =
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
          and user_id =
            '11111111-1111-1111-1111-111111111111'
        )
        or (
          organization_id =
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'
          and user_id =
            '44444444-4444-4444-4444-444444444444'
        )
      )
  ),
  2::bigint,
  'organization creators automatically become owners'
);

set local role authenticated;
set local request.jwt.claim.sub =
  '11111111-1111-1111-1111-111111111111';

select is(
  (
    select count(*)
    from public.organizations
  ),
  1::bigint,
  'owner sees only their organization'
);

select is(
  (
    select count(*)
    from public.clients
  ),
  1::bigint,
  'owner sees only clients from their organization'
);

select is(
  pg_temp.sqlstate_of(
    $statement$
      insert into public.clients (
        id,
        organization_id,
        name,
        created_by
      )
      values (
        'cccccccc-cccc-cccc-cccc-ccccccccccc2',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
        'Owner Created Client',
        '11111111-1111-1111-1111-111111111111'
      )
    $statement$
  ),
  null::text,
  'owner can create clients in their organization'
);

select is(
  pg_temp.sqlstate_of(
    $statement$
      insert into public.clients (
        id,
        organization_id,
        name,
        created_by
      )
      values (
        'dddddddd-dddd-dddd-dddd-ddddddddddd2',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
        'Forbidden Cross Tenant Client',
        '11111111-1111-1111-1111-111111111111'
      )
    $statement$
  ),
  '42501',
  'owner cannot create clients in another organization'
);

with updated_rows as (
update public.organizations
      set name = 'Organization A Updated'
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
      returning 1
)
select is(
  (select count(*) from updated_rows),
  1::bigint,
  'owner can update organization settings'
);

reset role;

set local role authenticated;
set local request.jwt.claim.sub =
  '22222222-2222-2222-2222-222222222222';

select is(
  (
    select count(*)
    from public.organizations
  ),
  1::bigint,
  'manager can see their organization'
);

select is(
  pg_temp.sqlstate_of(
    $statement$
      insert into public.clients (
        id,
        organization_id,
        name,
        created_by
      )
      values (
        'cccccccc-cccc-cccc-cccc-ccccccccccc3',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
        'Manager Created Client',
        '22222222-2222-2222-2222-222222222222'
      )
    $statement$
  ),
  null::text,
  'manager can create clients'
);

with updated_rows as (
update public.organizations
      set name = 'Manager Unauthorized Update'
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
      returning 1
)
select is(
  (select count(*) from updated_rows),
  0::bigint,
  'manager cannot update organization settings'
);

reset role;

set local role authenticated;
set local request.jwt.claim.sub =
  '33333333-3333-3333-3333-333333333333';

select ok(
  (
    select count(*)
    from public.clients
  ) >= 3
  and (
    select count(*)
    from public.clients
    where organization_id =
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'
  ) = 0,
  'member sees organization clients but not cross-tenant clients'
);

select is(
  pg_temp.sqlstate_of(
    $statement$
      insert into public.clients (
        id,
        organization_id,
        name,
        created_by
      )
      values (
        'cccccccc-cccc-cccc-cccc-ccccccccccc4',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
        'Unauthorized Member Client',
        '33333333-3333-3333-3333-333333333333'
      )
    $statement$
  ),
  '42501',
  'member cannot create clients'
);

with updated_rows as (
update public.organization_members
      set role = 'owner'
      where organization_id =
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
        and user_id =
          '33333333-3333-3333-3333-333333333333'
      returning 1
)
select is(
  (select count(*) from updated_rows),
  0::bigint,
  'member cannot escalate their own role'
);

select is(
  pg_temp.sqlstate_of(
    $statement$
      insert into public.tasks (
        id,
        organization_id,
        campaign_id,
        title,
        assignee_id,
        created_by
      )
      values (
        '66666666-6666-6666-6666-666666666661',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
        'Member Created Task',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333'
      )
    $statement$
  ),
  null::text,
  'member can create a task assigned to an organization member'
);

select is(
  pg_temp.sqlstate_of(
    $statement$
      insert into public.tasks (
        id,
        organization_id,
        campaign_id,
        title,
        assignee_id,
        created_by
      )
      values (
        '66666666-6666-6666-6666-666666666662',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
        'Cross Tenant Assignment',
        '44444444-4444-4444-4444-444444444444',
        '33333333-3333-3333-3333-333333333333'
      )
    $statement$
  ),
  '42501',
  'member cannot assign a task to an outsider'
);

select is(
  pg_temp.sqlstate_of(
    $statement$
      insert into public.comments (
        id,
        organization_id,
        task_id,
        author_id,
        body
      )
      values (
        '77777777-7777-7777-7777-777777777771',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
        '66666666-6666-6666-6666-666666666661',
        '33333333-3333-3333-3333-333333333333',
        'Member comment'
      )
    $statement$
  ),
  null::text,
  'member can create their own comment'
);

select is(
  (
    select count(*)
    from public.notifications
  ),
  1::bigint,
  'member sees only their own notification'
);

with updated_rows as (
update public.notifications
      set read_at = now()
      where id = '55555555-5555-5555-5555-555555555551'
      returning 1
)
select is(
  (select count(*) from updated_rows),
  1::bigint,
  'member can mark their own notification as read'
);

with updated_rows as (
update public.notifications
      set read_at = now()
      where id = '55555555-5555-5555-5555-555555555552'
      returning 1
)
select is(
  (select count(*) from updated_rows),
  0::bigint,
  'member cannot update another user notification'
);

select ok(
  (
    select count(*)
    from public.audit_logs
    where organization_id =
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  ) > 0,
  'member can read audit history from their organization'
);

select is(
  (
    select count(*)
    from public.audit_logs
    where organization_id =
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'
  ),
  0::bigint,
  'member cannot read another organization audit history'
);

reset role;

set local role authenticated;
set local request.jwt.claim.sub =
  '22222222-2222-2222-2222-222222222222';

with updated_rows as (
update public.comments
      set body = 'Manager attempted edit'
      where id = '77777777-7777-7777-7777-777777777771'
      returning 1
)
select is(
  (select count(*) from updated_rows),
  0::bigint,
  'manager cannot edit another user comment'
);

select is(
  (
    select count(*)
    from public.comments
    where id = '77777777-7777-7777-7777-777777777771'
  ),
  1::bigint,
  'manager can read organization comments'
);

reset role;

set local role authenticated;
set local request.jwt.claim.sub =
  '44444444-4444-4444-4444-444444444444';

select ok(
  (
    select count(*)
    from public.organizations
  ) = 1
  and (
    select count(*)
    from public.organizations
    where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  ) = 0,
  'organization B owner cannot see organization A'
);

select ok(
  (
    select count(*)
    from public.clients
  ) = 1
  and (
    select count(*)
    from public.clients
    where organization_id =
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  ) = 0,
  'organization B owner cannot see organization A clients'
);

select is(
  pg_temp.sqlstate_of(
    $statement$
      insert into public.clients (
        id,
        organization_id,
        name,
        created_by
      )
      values (
        'cccccccc-cccc-cccc-cccc-ccccccccccc5',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
        'Outsider Client',
        '44444444-4444-4444-4444-444444444444'
      )
    $statement$
  ),
  '42501',
  'outsider cannot create records in organization A'
);

select ok(
  not public.is_organization_member(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  ),
  'membership helper denies an outsider'
);

reset role;

set local role anon;

select is(
  pg_temp.sqlstate_of(
    'select count(*) from public.organizations'
  ),
  '42501',
  'anonymous users cannot access private organizations'
);

reset role;

select is(
  pg_temp.sqlstate_of(
    $statement$
      update public.clients
      set organization_id =
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'
      where id =
        'cccccccc-cccc-cccc-cccc-ccccccccccc1'
    $statement$
  ),
  '22000',
  'records cannot be moved between organizations'
);

select * from finish();

rollback;