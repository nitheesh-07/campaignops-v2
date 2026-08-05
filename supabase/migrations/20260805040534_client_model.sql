create table public.clients (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id) on delete cascade,

  name text not null,
  contact_name text,
  contact_email text,
  notes text,

  created_by uuid not null
    references public.profiles(id) on delete restrict,

  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint clients_organization_id_id_unique
    unique (organization_id, id),

  constraint clients_name_check
    check (
      name = btrim(name)
      and char_length(name) between 2 and 120
    ),

  constraint clients_contact_name_check
    check (
      contact_name is null
      or (
        contact_name = btrim(contact_name)
        and char_length(contact_name) between 2 and 120
      )
    ),

  constraint clients_contact_email_check
    check (
      contact_email is null
      or (
        contact_email = btrim(contact_email)
        and char_length(contact_email) between 3 and 320
        and position('@' in contact_email) > 1
      )
    ),

  constraint clients_notes_length_check
    check (
      notes is null
      or char_length(notes) <= 5000
    ),

  constraint clients_archived_at_check
    check (
      archived_at is null
      or archived_at >= created_at
    )
);

create unique index clients_organization_name_unique_idx
  on public.clients (
    organization_id,
    lower(name)
  );

create index clients_organization_archived_at_idx
  on public.clients (
    organization_id,
    archived_at
  );

create trigger clients_set_updated_at
before update on public.clients
for each row
execute function public.set_updated_at();

alter table public.clients enable row level security;

revoke all on table public.clients
from public, anon, authenticated;

grant select, insert, update, delete
on table public.clients
to authenticated;

comment on table public.clients is
  'Organization-owned client records used by CampaignOps campaigns.';

comment on constraint clients_organization_id_id_unique
on public.clients is
  'Supports composite foreign keys that prevent cross-organization campaign references.';