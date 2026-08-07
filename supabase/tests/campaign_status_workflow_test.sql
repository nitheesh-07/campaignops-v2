begin;

select plan(19);

select ok(
  exists (
    select 1
    from pg_proc as function_definition
    join pg_namespace as schema_definition
      on schema_definition.oid = function_definition.pronamespace
    where schema_definition.nspname = 'public'
      and function_definition.proname =
        'is_valid_campaign_status_transition'
      and pg_catalog.oidvectortypes(
        function_definition.proargtypes
      ) = 'campaign_status, campaign_status'
      and function_definition.provolatile = 'i'
  ),
  'campaign transition validator exists and is immutable'
);

select ok(
  exists (
    select 1
    from pg_proc as function_definition
    join pg_namespace as schema_definition
      on schema_definition.oid = function_definition.pronamespace
    where schema_definition.nspname = 'public'
      and function_definition.proname =
        'enforce_campaign_status_transition'
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
  'campaign transition trigger function is hardened'
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_definition
    where trigger_definition.tgrelid =
        'public.campaigns'::regclass
      and trigger_definition.tgname =
        'campaigns_enforce_status_transition'
      and not trigger_definition.tgisinternal
      and pg_get_triggerdef(trigger_definition.oid)
        ilike '%before update of status%'
  ),
  'campaign transition trigger exists'
);

select ok(
  public.is_valid_campaign_status_transition('draft', 'draft'),
  'unchanged campaign status is valid'
);

select ok(
  public.is_valid_campaign_status_transition('draft', 'active'),
  'draft can become active'
);

select ok(
  public.is_valid_campaign_status_transition('draft', 'archived'),
  'draft can become archived'
);

select ok(
  public.is_valid_campaign_status_transition('active', 'in_review'),
  'active can move into review'
);

select ok(
  public.is_valid_campaign_status_transition('active', 'archived'),
  'active can become archived'
);

select ok(
  public.is_valid_campaign_status_transition('in_review', 'active'),
  'in-review campaign can return to active'
);

select ok(
  public.is_valid_campaign_status_transition('in_review', 'approved'),
  'in-review campaign can become approved'
);

select ok(
  public.is_valid_campaign_status_transition('approved', 'completed'),
  'approved campaign can become completed'
);

select ok(
  public.is_valid_campaign_status_transition('completed', 'archived'),
  'completed campaign can become archived'
);

select ok(
  not public.is_valid_campaign_status_transition('draft', 'approved'),
  'draft cannot skip directly to approved'
);

select ok(
  not public.is_valid_campaign_status_transition('active', 'completed'),
  'active cannot skip directly to completed'
);

select ok(
  not public.is_valid_campaign_status_transition('approved', 'archived'),
  'approved cannot skip directly to archived'
);

select ok(
  not public.is_valid_campaign_status_transition('archived', 'active'),
  'archived is a terminal status'
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
values (
  '99999999-9999-4999-8999-999999999901',
  'campaign-workflow-owner@example.test',
  '{"full_name":"Campaign Workflow Owner"}',
  now(),
  now()
);

insert into public.organizations (
  id,
  name,
  slug,
  created_by
)
values (
  '99999999-9999-4999-8999-999999999902',
  'Campaign Workflow Organization',
  'campaign-workflow-organization',
  '99999999-9999-4999-8999-999999999901'
);

insert into public.clients (
  id,
  organization_id,
  name,
  created_by
)
values (
  '99999999-9999-4999-8999-999999999903',
  '99999999-9999-4999-8999-999999999902',
  'Campaign Workflow Client',
  '99999999-9999-4999-8999-999999999901'
);

insert into public.campaigns (
  id,
  organization_id,
  client_id,
  name,
  created_by
)
values (
  '99999999-9999-4999-8999-999999999904',
  '99999999-9999-4999-8999-999999999902',
  '99999999-9999-4999-8999-999999999903',
  'Campaign Workflow Test',
  '99999999-9999-4999-8999-999999999901'
);

update public.campaigns
set description = 'Status did not change'
where id = '99999999-9999-4999-8999-999999999904';

select is(
  (
    select description
    from public.campaigns
    where id = '99999999-9999-4999-8999-999999999904'
  ),
  'Status did not change',
  'campaign fields can be edited without changing status'
);

select is(
  pg_temp.sqlstate_of(
    $statement$
      update public.campaigns
      set status = 'approved'
      where id = '99999999-9999-4999-8999-999999999904'
    $statement$
  ),
  '23514',
  'database trigger rejects an invalid status jump'
);

with updated_campaign as (
  update public.campaigns
  set status = 'active'
  where id = '99999999-9999-4999-8999-999999999904'
  returning status
)
select is(
  (select status from updated_campaign),
  'active'::public.campaign_status,
  'database trigger permits a valid transition'
);

select * from finish();

rollback;
