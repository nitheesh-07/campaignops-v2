create function public.is_user_organization_member(
  p_organization_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as membership
    where membership.organization_id = p_organization_id
      and membership.user_id = p_user_id
  );
$$;

create function public.is_organization_member(
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_user_organization_member(
    p_organization_id,
    auth.uid()
  );
$$;

create function public.has_organization_role(
  p_organization_id uuid,
  p_roles public.organization_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as membership
    where membership.organization_id = p_organization_id
      and membership.user_id = auth.uid()
      and membership.role = any(p_roles)
  );
$$;

create function public.can_view_profile(
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_profile_id = auth.uid()
    or exists (
      select 1
      from public.organization_members as current_membership
      join public.organization_members as target_membership
        on target_membership.organization_id =
          current_membership.organization_id
      where current_membership.user_id = auth.uid()
        and target_membership.user_id = p_profile_id
    );
$$;

revoke all
on function public.is_user_organization_member(uuid, uuid)
from public, anon, authenticated;

revoke all
on function public.is_organization_member(uuid)
from public, anon, authenticated;

revoke all
on function public.has_organization_role(
  uuid,
  public.organization_role[]
)
from public, anon, authenticated;

revoke all
on function public.can_view_profile(uuid)
from public, anon, authenticated;

grant execute
on function public.is_user_organization_member(uuid, uuid)
to authenticated;

grant execute
on function public.is_organization_member(uuid)
to authenticated;

grant execute
on function public.has_organization_role(
  uuid,
  public.organization_role[]
)
to authenticated;

grant execute
on function public.can_view_profile(uuid)
to authenticated;


create function public.add_organization_creator_as_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.organization_members (
    organization_id,
    user_id,
    role
  )
  values (
    new.id,
    new.created_by,
    'owner'::public.organization_role
  )
  on conflict (organization_id, user_id)
  do nothing;

  return new;
end;
$$;

revoke all
on function public.add_organization_creator_as_owner()
from public, anon, authenticated;

create trigger organizations_add_creator_as_owner
after insert on public.organizations
for each row
execute function public.add_organization_creator_as_owner();


create function public.prevent_immutable_column_changes()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  immutable_column text;
begin
  foreach immutable_column in array tg_argv
  loop
    if to_jsonb(new) -> immutable_column
      is distinct from
      to_jsonb(old) -> immutable_column
    then
      raise exception
        'Column "%" is immutable on %.%',
        immutable_column,
        tg_table_schema,
        tg_table_name
        using errcode = '22000';
    end if;
  end loop;

  return new;
end;
$$;

revoke all
on function public.prevent_immutable_column_changes()
from public, anon, authenticated;

create trigger organizations_protect_identity
before update on public.organizations
for each row
execute function public.prevent_immutable_column_changes(
  'created_by'
);

create trigger organization_members_protect_identity
before update on public.organization_members
for each row
execute function public.prevent_immutable_column_changes(
  'organization_id',
  'user_id'
);

create trigger organization_invitations_protect_identity
before update on public.organization_invitations
for each row
execute function public.prevent_immutable_column_changes(
  'organization_id',
  'invited_by',
  'token_hash'
);

create trigger clients_protect_identity
before update on public.clients
for each row
execute function public.prevent_immutable_column_changes(
  'organization_id',
  'created_by'
);

create trigger campaigns_protect_identity
before update on public.campaigns
for each row
execute function public.prevent_immutable_column_changes(
  'organization_id',
  'created_by'
);

create trigger tasks_protect_identity
before update on public.tasks
for each row
execute function public.prevent_immutable_column_changes(
  'organization_id',
  'created_by'
);

create trigger approvals_protect_identity
before update on public.approvals
for each row
execute function public.prevent_immutable_column_changes(
  'organization_id',
  'task_id',
  'requested_by'
);

create trigger comments_protect_identity
before update on public.comments
for each row
execute function public.prevent_immutable_column_changes(
  'organization_id',
  'task_id',
  'author_id'
);

create trigger attachments_protect_identity
before update on public.attachments
for each row
execute function public.prevent_immutable_column_changes(
  'organization_id',
  'task_id',
  'uploaded_by',
  'storage_path'
);

create trigger notifications_protect_identity
before update on public.notifications
for each row
execute function public.prevent_immutable_column_changes(
  'organization_id',
  'recipient_id',
  'kind',
  'title',
  'message',
  'entity_type',
  'entity_id'
);


create or replace function public.create_internal_notification(
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
  if not public.is_user_organization_member(
    p_organization_id,
    p_recipient_id
  )
  then
    return null;
  end if;

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


create policy profiles_select_shared_organization
on public.profiles
for select
to authenticated
using (
  public.can_view_profile(id)
);


create policy organizations_select_members
on public.organizations
for select
to authenticated
using (
  public.is_organization_member(id)
);

create policy organizations_insert_creator
on public.organizations
for insert
to authenticated
with check (
  created_by = auth.uid()
);

create policy organizations_update_owner
on public.organizations
for update
to authenticated
using (
  public.has_organization_role(
    id,
    array['owner']::public.organization_role[]
  )
)
with check (
  public.has_organization_role(
    id,
    array['owner']::public.organization_role[]
  )
);

create policy organizations_delete_owner
on public.organizations
for delete
to authenticated
using (
  public.has_organization_role(
    id,
    array['owner']::public.organization_role[]
  )
);


create policy organization_members_select_members
on public.organization_members
for select
to authenticated
using (
  public.is_organization_member(organization_id)
);

create policy organization_members_insert_owner
on public.organization_members
for insert
to authenticated
with check (
  public.has_organization_role(
    organization_id,
    array['owner']::public.organization_role[]
  )
);

create policy organization_members_update_owner
on public.organization_members
for update
to authenticated
using (
  public.has_organization_role(
    organization_id,
    array['owner']::public.organization_role[]
  )
)
with check (
  public.has_organization_role(
    organization_id,
    array['owner']::public.organization_role[]
  )
);

create policy organization_members_delete_owner
on public.organization_members
for delete
to authenticated
using (
  public.has_organization_role(
    organization_id,
    array['owner']::public.organization_role[]
  )
);

create policy organization_members_leave_self
on public.organization_members
for delete
to authenticated
using (
  user_id = auth.uid()
  and role <> 'owner'::public.organization_role
);


create policy organization_invitations_select_admin
on public.organization_invitations
for select
to authenticated
using (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);

create policy organization_invitations_insert_admin
on public.organization_invitations
for insert
to authenticated
with check (
  invited_by = auth.uid()
  and public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);

create policy organization_invitations_update_admin
on public.organization_invitations
for update
to authenticated
using (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
)
with check (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);

create policy organization_invitations_delete_admin
on public.organization_invitations
for delete
to authenticated
using (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);


create policy clients_select_members
on public.clients
for select
to authenticated
using (
  public.is_organization_member(organization_id)
);

create policy clients_insert_admin
on public.clients
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);

create policy clients_update_admin
on public.clients
for update
to authenticated
using (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
)
with check (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);

create policy clients_delete_admin
on public.clients
for delete
to authenticated
using (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);


create policy campaigns_select_members
on public.campaigns
for select
to authenticated
using (
  public.is_organization_member(organization_id)
);

create policy campaigns_insert_admin
on public.campaigns
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);

create policy campaigns_update_admin
on public.campaigns
for update
to authenticated
using (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
)
with check (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);

create policy campaigns_delete_admin
on public.campaigns
for delete
to authenticated
using (
  public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);


create policy tasks_select_members
on public.tasks
for select
to authenticated
using (
  public.is_organization_member(organization_id)
);

create policy tasks_insert_members
on public.tasks
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.is_organization_member(organization_id)
  and (
    assignee_id is null
    or public.is_user_organization_member(
      organization_id,
      assignee_id
    )
  )
);

create policy tasks_update_members
on public.tasks
for update
to authenticated
using (
  public.is_organization_member(organization_id)
)
with check (
  public.is_organization_member(organization_id)
  and (
    assignee_id is null
    or public.is_user_organization_member(
      organization_id,
      assignee_id
    )
  )
);

create policy tasks_delete_admin_or_creator
on public.tasks
for delete
to authenticated
using (
  created_by = auth.uid()
  or public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);


create policy approvals_select_members
on public.approvals
for select
to authenticated
using (
  public.is_organization_member(organization_id)
);

create policy approvals_insert_members
on public.approvals
for insert
to authenticated
with check (
  requested_by = auth.uid()
  and public.is_organization_member(organization_id)
  and (
    reviewer_id is null
    or public.is_user_organization_member(
      organization_id,
      reviewer_id
    )
  )
);

create policy approvals_update_reviewer_or_admin
on public.approvals
for update
to authenticated
using (
  reviewer_id = auth.uid()
  or public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
)
with check (
  public.is_organization_member(organization_id)
  and (
    reviewer_id = auth.uid()
    or public.has_organization_role(
      organization_id,
      array[
        'owner',
        'manager'
      ]::public.organization_role[]
    )
  )
);

create policy approvals_delete_requester_or_admin
on public.approvals
for delete
to authenticated
using (
  requested_by = auth.uid()
  or public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);


create policy comments_select_members
on public.comments
for select
to authenticated
using (
  public.is_organization_member(organization_id)
);

create policy comments_insert_author
on public.comments
for insert
to authenticated
with check (
  author_id = auth.uid()
  and public.is_organization_member(organization_id)
);

create policy comments_update_author
on public.comments
for update
to authenticated
using (
  author_id = auth.uid()
)
with check (
  author_id = auth.uid()
  and public.is_organization_member(organization_id)
);

create policy comments_delete_author_or_admin
on public.comments
for delete
to authenticated
using (
  author_id = auth.uid()
  or public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);


create policy attachments_select_members
on public.attachments
for select
to authenticated
using (
  public.is_organization_member(organization_id)
);

create policy attachments_insert_uploader
on public.attachments
for insert
to authenticated
with check (
  uploaded_by = auth.uid()
  and public.is_organization_member(organization_id)
);

create policy attachments_delete_uploader_or_admin
on public.attachments
for delete
to authenticated
using (
  uploaded_by = auth.uid()
  or public.has_organization_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]::public.organization_role[]
  )
);


create policy notifications_select_recipient
on public.notifications
for select
to authenticated
using (
  recipient_id = auth.uid()
  and public.is_organization_member(organization_id)
);

create policy notifications_update_recipient
on public.notifications
for update
to authenticated
using (
  recipient_id = auth.uid()
  and public.is_organization_member(organization_id)
)
with check (
  recipient_id = auth.uid()
  and public.is_organization_member(organization_id)
);

create policy notifications_delete_recipient
on public.notifications
for delete
to authenticated
using (
  recipient_id = auth.uid()
  and public.is_organization_member(organization_id)
);


create policy audit_logs_select_members
on public.audit_logs
for select
to authenticated
using (
  public.is_organization_member(organization_id)
);


comment on function public.is_user_organization_member(uuid, uuid) is
  'Checks whether a profile belongs to an organization without recursive RLS.';

comment on function public.is_organization_member(uuid) is
  'Checks whether the authenticated user belongs to an organization.';

comment on function public.has_organization_role(
  uuid,
  public.organization_role[]
) is
  'Checks whether the authenticated user has one of the required tenant roles.';

comment on function public.can_view_profile(uuid) is
  'Allows profile visibility for users sharing an organization.';