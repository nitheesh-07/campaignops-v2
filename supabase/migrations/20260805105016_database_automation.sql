create function public.sync_task_completed_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.status::text = 'done' then
    if new.completed_at is null then
      new.completed_at := now();
    end if;
  else
    new.completed_at := null;
  end if;

  return new;
end;
$$;

revoke all
on function public.sync_task_completed_at()
from public, anon, authenticated;

create trigger tasks_sync_completed_at
before insert or update on public.tasks
for each row
execute function public.sync_task_completed_at();


create function public.audit_business_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  audit_organization_id uuid;
  audit_entity_id uuid;
  audit_old_data jsonb;
  audit_new_data jsonb;
begin
  if tg_op = 'INSERT' then
    audit_organization_id := new.organization_id;
    audit_entity_id := new.id;
    audit_old_data := null;
    audit_new_data := to_jsonb(new);

  elsif tg_op = 'UPDATE' then
    audit_organization_id := new.organization_id;
    audit_entity_id := new.id;
    audit_old_data := to_jsonb(old);
    audit_new_data := to_jsonb(new);

  elsif tg_op = 'DELETE' then
    audit_organization_id := old.organization_id;
    audit_entity_id := old.id;
    audit_old_data := to_jsonb(old);
    audit_new_data := null;
  end if;

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    old_data,
    new_data
  )
  values (
    audit_organization_id,
    auth.uid(),
    lower(tg_op),
    tg_table_name,
    audit_entity_id,
    audit_old_data,
    audit_new_data
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

revoke all
on function public.audit_business_change()
from public, anon, authenticated;


create trigger clients_audit_changes
after insert or update or delete on public.clients
for each row
execute function public.audit_business_change();

create trigger campaigns_audit_changes
after insert or update or delete on public.campaigns
for each row
execute function public.audit_business_change();

create trigger tasks_audit_changes
after insert or update or delete on public.tasks
for each row
execute function public.audit_business_change();

create trigger approvals_audit_changes
after insert or update or delete on public.approvals
for each row
execute function public.audit_business_change();

create trigger comments_audit_changes
after insert or update or delete on public.comments
for each row
execute function public.audit_business_change();

create trigger attachments_audit_changes
after insert or update or delete on public.attachments
for each row
execute function public.audit_business_change();


create function public.create_internal_notification(
  p_organization_id uuid,
  p_recipient_id uuid,
  p_kind text,
  p_title text,
  p_message text,
  p_entity_type text,
  p_entity_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_notification_id uuid;
begin
  insert into public.notifications (
    organization_id,
    recipient_id,
    kind,
    title,
    message,
    entity_type,
    entity_id
  )
  values (
    p_organization_id,
    p_recipient_id,
    p_kind,
    p_title,
    p_message,
    p_entity_type,
    p_entity_id
  )
  returning id into created_notification_id;

  return created_notification_id;
end;
$$;

revoke all
on function public.create_internal_notification(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  uuid
)
from public, anon, authenticated;


create function public.notify_task_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  assignment_changed boolean;
begin
  if tg_op = 'INSERT' then
    assignment_changed := new.assignee_id is not null;
  else
    assignment_changed :=
      new.assignee_id is not null
      and old.assignee_id is distinct from new.assignee_id;
  end if;

  if assignment_changed
    and new.assignee_id is distinct from auth.uid()
  then
    perform public.create_internal_notification(
      new.organization_id,
      new.assignee_id,
      'task_assigned',
      'Task assigned',
      'You were assigned to task: ' || new.title,
      'task',
      new.id
    );
  end if;

  return new;
end;
$$;

revoke all
on function public.notify_task_assignment()
from public, anon, authenticated;

create trigger tasks_notify_assignment
after insert or update of assignee_id on public.tasks
for each row
execute function public.notify_task_assignment();


create function public.notify_approval_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  reviewer_changed boolean := false;
  status_changed boolean := false;
begin
  if tg_op = 'INSERT' then
    reviewer_changed := new.reviewer_id is not null;
  else
    reviewer_changed :=
      new.reviewer_id is not null
      and old.reviewer_id is distinct from new.reviewer_id;

    status_changed :=
      old.status is distinct from new.status;
  end if;

  if reviewer_changed
    and new.reviewer_id is distinct from auth.uid()
  then
    perform public.create_internal_notification(
      new.organization_id,
      new.reviewer_id,
      'approval_requested',
      'Approval requested',
      'A task approval is waiting for your review.',
      'approval',
      new.id
    );
  end if;

  if status_changed
    and new.requested_by is distinct from auth.uid()
  then
    perform public.create_internal_notification(
      new.organization_id,
      new.requested_by,
      'approval_updated',
      'Approval updated',
      'Your approval request status changed to '
        || new.status::text
        || '.',
      'approval',
      new.id
    );
  end if;

  return new;
end;
$$;

revoke all
on function public.notify_approval_event()
from public, anon, authenticated;

create trigger approvals_notify_event
after insert or update of reviewer_id, status
on public.approvals
for each row
execute function public.notify_approval_event();


comment on function public.sync_task_completed_at() is
  'Synchronizes task completed_at with the done status.';

comment on function public.audit_business_change() is
  'Records business-table changes in immutable audit logs.';

comment on function public.create_internal_notification(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  uuid
) is
  'Protected helper for database-generated notifications.';

comment on function public.notify_task_assignment() is
  'Creates notifications when task assignments change.';

comment on function public.notify_approval_event() is
  'Creates notifications for approval assignment and status events.';