create table public.notifications (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete cascade,

  recipient_id uuid not null
    references public.profiles(id)
    on delete cascade,

  kind text not null,
  title text not null,
  message text not null,

  entity_type text,
  entity_id uuid,

  read_at timestamptz,
  created_at timestamptz not null default now(),

  constraint notifications_organization_id_id_unique
    unique (organization_id, id),

  constraint notifications_kind_check
    check (
      kind = btrim(kind)
      and kind ~ '^[a-z][a-z0-9_]{1,49}$'
    ),

  constraint notifications_title_check
    check (
      title = btrim(title)
      and char_length(title) between 1 and 160
    ),

  constraint notifications_message_check
    check (
      message = btrim(message)
      and char_length(message) between 1 and 2000
    ),

  constraint notifications_entity_reference_check
    check (
      (
        entity_type is null
        and entity_id is null
      )
      or (
        entity_type is not null
        and entity_id is not null
        and entity_type = btrim(entity_type)
        and entity_type ~ '^[a-z][a-z0-9_]{1,49}$'
      )
    ),

  constraint notifications_read_at_check
    check (
      read_at is null
      or read_at >= created_at
    )
);

create index notifications_recipient_created_at_idx
  on public.notifications (
    organization_id,
    recipient_id,
    created_at desc
  );

create index notifications_unread_recipient_idx
  on public.notifications (
    organization_id,
    recipient_id,
    created_at desc
  )
  where read_at is null;

create index notifications_entity_idx
  on public.notifications (
    organization_id,
    entity_type,
    entity_id
  )
  where entity_id is not null;


create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete cascade,

  actor_id uuid
    references public.profiles(id)
    on delete set null,

  action text not null,
  entity_type text not null,
  entity_id uuid not null,

  old_data jsonb,
  new_data jsonb,

  created_at timestamptz not null default now(),

  constraint audit_logs_organization_id_id_unique
    unique (organization_id, id),

  constraint audit_logs_action_check
    check (
      action = btrim(action)
      and action ~ '^[a-z][a-z0-9_]{1,49}$'
    ),

  constraint audit_logs_entity_type_check
    check (
      entity_type = btrim(entity_type)
      and entity_type ~ '^[a-z][a-z0-9_]{1,49}$'
    ),

  constraint audit_logs_old_data_check
    check (
      old_data is null
      or jsonb_typeof(old_data) = 'object'
    ),

  constraint audit_logs_new_data_check
    check (
      new_data is null
      or jsonb_typeof(new_data) = 'object'
    ),

  constraint audit_logs_change_data_check
    check (
      old_data is not null
      or new_data is not null
    )
);

create index audit_logs_organization_created_at_idx
  on public.audit_logs (
    organization_id,
    created_at desc
  );

create index audit_logs_entity_created_at_idx
  on public.audit_logs (
    organization_id,
    entity_type,
    entity_id,
    created_at desc
  );

create index audit_logs_actor_created_at_idx
  on public.audit_logs (
    organization_id,
    actor_id,
    created_at desc
  )
  where actor_id is not null;


create function public.prevent_audit_log_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'Audit log records are immutable'
    using errcode = '55000';
end;
$$;

revoke all
on function public.prevent_audit_log_mutation()
from public;

create trigger audit_logs_prevent_mutation
before update or delete on public.audit_logs
for each row
execute function public.prevent_audit_log_mutation();


alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

revoke all on table
  public.notifications,
  public.audit_logs
from public, anon, authenticated;

grant select, delete
on table public.notifications
to authenticated;

grant update (read_at)
on table public.notifications
to authenticated;

grant select
on table public.audit_logs
to authenticated;


comment on table public.notifications is
  'Organization-owned notifications delivered to individual profiles.';

comment on column public.notifications.kind is
  'Machine-readable notification category.';

comment on column public.notifications.entity_id is
  'Optional polymorphic reference to the related record.';

comment on table public.audit_logs is
  'Immutable organization audit history.';

comment on column public.audit_logs.old_data is
  'JSON object containing values before a change.';

comment on column public.audit_logs.new_data is
  'JSON object containing values after a change.';