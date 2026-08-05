create table public.approvals (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete cascade,

  task_id uuid not null,

  status public.approval_status not null
    default 'pending'::public.approval_status,

  requested_by uuid not null
    references public.profiles(id)
    on delete restrict,

  reviewer_id uuid
    references public.profiles(id)
    on delete set null,

  request_note text,
  response_note text,
  responded_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint approvals_organization_id_id_unique
    unique (organization_id, id),

  constraint approvals_organization_task_fkey
    foreign key (organization_id, task_id)
    references public.tasks (organization_id, id)
    on delete cascade,

  constraint approvals_request_note_check
    check (
      request_note is null
      or (
        request_note = btrim(request_note)
        and char_length(request_note) <= 5000
      )
    ),

  constraint approvals_response_note_check
    check (
      response_note is null
      or (
        response_note = btrim(response_note)
        and char_length(response_note) <= 5000
      )
    ),

  constraint approvals_response_state_check
    check (
      (
        status = 'pending'::public.approval_status
        and responded_at is null
      )
      or (
        status <> 'pending'::public.approval_status
        and responded_at is not null
      )
    ),

  constraint approvals_responded_at_check
    check (
      responded_at is null
      or responded_at >= created_at
    )
);

create index approvals_organization_task_created_at_idx
  on public.approvals (
    organization_id,
    task_id,
    created_at desc
  );

create index approvals_organization_reviewer_status_idx
  on public.approvals (
    organization_id,
    reviewer_id,
    status
  )
  where reviewer_id is not null;

create trigger approvals_set_updated_at
before update on public.approvals
for each row
execute function public.set_updated_at();


create table public.comments (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete cascade,

  task_id uuid not null,

  author_id uuid not null
    references public.profiles(id)
    on delete restrict,

  body text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint comments_organization_id_id_unique
    unique (organization_id, id),

  constraint comments_organization_task_fkey
    foreign key (organization_id, task_id)
    references public.tasks (organization_id, id)
    on delete cascade,

  constraint comments_body_check
    check (
      body = btrim(body)
      and char_length(body) between 1 and 5000
    )
);

create index comments_organization_task_created_at_idx
  on public.comments (
    organization_id,
    task_id,
    created_at
  );

create index comments_organization_author_created_at_idx
  on public.comments (
    organization_id,
    author_id,
    created_at
  );

create trigger comments_set_updated_at
before update on public.comments
for each row
execute function public.set_updated_at();


create table public.attachments (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete cascade,

  task_id uuid not null,

  uploaded_by uuid not null
    references public.profiles(id)
    on delete restrict,

  file_name text not null,
  storage_path text not null,
  mime_type text not null,
  size_bytes bigint not null,

  created_at timestamptz not null default now(),

  constraint attachments_organization_id_id_unique
    unique (organization_id, id),

  constraint attachments_organization_storage_path_unique
    unique (organization_id, storage_path),

  constraint attachments_organization_task_fkey
    foreign key (organization_id, task_id)
    references public.tasks (organization_id, id)
    on delete cascade,

  constraint attachments_file_name_check
    check (
      file_name = btrim(file_name)
      and char_length(file_name) between 1 and 255
      and position('/' in file_name) = 0
      and position(chr(92) in file_name) = 0
    ),

  constraint attachments_storage_path_check
    check (
      storage_path = btrim(storage_path)
      and char_length(storage_path) between 1 and 1024
    ),

  constraint attachments_mime_type_check
    check (
      mime_type = btrim(mime_type)
      and char_length(mime_type) between 3 and 100
      and position('/' in mime_type) > 1
    ),

  constraint attachments_size_bytes_check
    check (
      size_bytes > 0
      and size_bytes <= 104857600
    )
);

create index attachments_organization_task_created_at_idx
  on public.attachments (
    organization_id,
    task_id,
    created_at
  );

create index attachments_organization_uploader_created_at_idx
  on public.attachments (
    organization_id,
    uploaded_by,
    created_at
  );


alter table public.approvals enable row level security;
alter table public.comments enable row level security;
alter table public.attachments enable row level security;

revoke all on table
  public.approvals,
  public.comments,
  public.attachments
from public, anon, authenticated;

grant select, insert, update, delete
on table
  public.approvals,
  public.comments,
  public.attachments
to authenticated;

comment on table public.approvals is
  'Task approval requests and their review outcomes.';

comment on table public.comments is
  'Organization-owned discussion attached to tasks.';

comment on table public.attachments is
  'Metadata for task files stored outside PostgreSQL.';

comment on column public.attachments.storage_path is
  'Object path in the configured Supabase Storage bucket.';

comment on column public.attachments.size_bytes is
  'File size in bytes, limited to 100 MiB.';