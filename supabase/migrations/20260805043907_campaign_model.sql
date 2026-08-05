create table public.campaigns (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete cascade,

  client_id uuid not null,

  name text not null,
  description text,

  status public.campaign_status not null
    default 'draft'::public.campaign_status,

  start_date date,
  due_date date,

  created_by uuid not null
    references public.profiles(id)
    on delete restrict,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint campaigns_organization_id_id_unique
    unique (organization_id, id),

  constraint campaigns_organization_client_fkey
    foreign key (organization_id, client_id)
    references public.clients (organization_id, id)
    on delete restrict,

  constraint campaigns_name_check
    check (
      name = btrim(name)
      and char_length(name) between 2 and 160
    ),

  constraint campaigns_description_check
    check (
      description is null
      or (
        description = btrim(description)
        and char_length(description) <= 5000
      )
    ),

  constraint campaigns_date_range_check
    check (
      due_date is null
      or start_date is null
      or due_date >= start_date
    )
);

create unique index campaigns_client_name_unique_idx
  on public.campaigns (
    organization_id,
    client_id,
    lower(name)
  );

create index campaigns_organization_status_idx
  on public.campaigns (organization_id, status);

create index campaigns_organization_due_date_idx
  on public.campaigns (organization_id, due_date)
  where due_date is not null;

create trigger campaigns_set_updated_at
before update on public.campaigns
for each row
execute function public.set_updated_at();

alter table public.campaigns enable row level security;

revoke all on table public.campaigns
from public, anon, authenticated;

grant select, insert, update, delete
on table public.campaigns
to authenticated;

comment on table public.campaigns is
  'Organization-owned client marketing campaigns.';

comment on column public.campaigns.organization_id is
  'Organization that owns the campaign.';

comment on column public.campaigns.client_id is
  'Client belonging to the same organization as the campaign.';

comment on column public.campaigns.status is
  'Current campaign lifecycle status.';

comment on column public.campaigns.created_by is
  'Profile that created the campaign.';