
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint organizations_name_length_check
    check (char_length(btrim(name)) between 2 and 120),

  constraint organizations_slug_unique
    unique (slug),

  constraint organizations_slug_format_check
    check (
      char_length(slug::text) between 2 and 63
      and slug::text = lower(slug::text)
      and slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    )
);

create table public.organization_members (
  organization_id uuid not null
    references public.organizations(id) on delete cascade,

  user_id uuid not null
    references public.profiles(id) on delete cascade,

  role public.organization_role not null default 'member',
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint organization_members_pkey
    primary key (organization_id, user_id)
);

create table public.organization_invitations (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id) on delete cascade,

  email text not null,
  role public.organization_role not null default 'member',

  token_hash text not null,
  invited_by uuid not null
    references public.profiles(id) on delete restrict,

  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),

  constraint organization_invitations_token_hash_unique
    unique (token_hash),

  constraint organization_invitations_email_check
    check (
      char_length(email::text) between 3 and 320
      and position('@' in email::text) > 1
    ),

  constraint organization_invitations_role_check
    check (role in ('manager', 'member')),

  constraint organization_invitations_token_hash_check
    check (token_hash ~ '^[0-9a-f]{64}$'),

  constraint organization_invitations_expiry_check
    check (expires_at > created_at),

  constraint organization_invitations_accepted_at_check
    check (accepted_at is null or accepted_at >= created_at)
);

create unique index organization_invitations_pending_email_idx
  on public.organization_invitations (
    organization_id,
    lower(email)
  )
  where accepted_at is null;

create index organization_members_user_id_idx
  on public.organization_members (user_id);

create index organization_members_organization_role_idx
  on public.organization_members (organization_id, role);

create index organization_invitations_expires_at_idx
  on public.organization_invitations (expires_at);

create trigger organizations_set_updated_at
before update on public.organizations
for each row
execute function public.set_updated_at();

create trigger organization_members_set_updated_at
before update on public.organization_members
for each row
execute function public.set_updated_at();

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.organization_invitations enable row level security;

revoke all on table
  public.organizations,
  public.organization_members,
  public.organization_invitations
from public, anon, authenticated;

grant select, insert, update, delete on table
  public.organizations,
  public.organization_members,
  public.organization_invitations
to authenticated;

comment on table public.organizations is
  'Tenant workspaces in CampaignOps.';

comment on table public.organization_members is
  'Connects authenticated users to organizations with a tenant role.';

comment on table public.organization_invitations is
  'Pending organization invitations. Tokens are stored only as SHA-256 hashes.';

