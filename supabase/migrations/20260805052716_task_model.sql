create table public.tasks (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete cascade,

  campaign_id uuid not null,

  title text not null,
  description text,

  status public.task_status not null
    default 'todo'::public.task_status,

  assignee_id uuid
    references public.profiles(id)
    on delete set null,

  due_date date,
  completed_at timestamptz,

  created_by uuid not null
    references public.profiles(id)
    on delete restrict,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tasks_organization_id_id_unique
    unique (organization_id, id),

  constraint tasks_organization_campaign_fkey
    foreign key (organization_id, campaign_id)
    references public.campaigns (organization_id, id)
    on delete cascade,

  constraint tasks_title_check
    check (
      title = btrim(title)
      and char_length(title) between 2 and 200
    ),

  constraint tasks_description_check
    check (
      description is null
      or (
        description = btrim(description)
        and char_length(description) <= 5000
      )
    ),

  constraint tasks_completed_at_check
    check (
      completed_at is null
      or completed_at >= created_at
    )
);

create index tasks_organization_campaign_status_idx
  on public.tasks (
    organization_id,
    campaign_id,
    status
  );

create index tasks_organization_assignee_status_idx
  on public.tasks (
    organization_id,
    assignee_id,
    status
  )
  where assignee_id is not null;

create index tasks_organization_due_date_idx
  on public.tasks (
    organization_id,
    due_date
  )
  where due_date is not null
    and completed_at is null;

create trigger tasks_set_updated_at
before update on public.tasks
for each row
execute function public.set_updated_at();

alter table public.tasks enable row level security;

revoke all on table public.tasks
from public, anon, authenticated;

grant select, insert, update, delete
on table public.tasks
to authenticated;

comment on table public.tasks is
  'Organization-owned work items belonging to campaigns.';

comment on column public.tasks.campaign_id is
  'Campaign belonging to the same organization as the task.';

comment on column public.tasks.assignee_id is
  'Optional profile currently responsible for the task.';

comment on column public.tasks.completed_at is
  'Timestamp at which the task was completed.';