create function public.is_valid_campaign_status_transition(
  previous_status public.campaign_status,
  next_status public.campaign_status
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select
    previous_status = next_status
    or (
      previous_status = 'draft'
      and next_status in ('active', 'archived')
    )
    or (
      previous_status = 'active'
      and next_status in ('in_review', 'archived')
    )
    or (
      previous_status = 'in_review'
      and next_status in ('active', 'approved')
    )
    or (
      previous_status = 'approved'
      and next_status = 'completed'
    )
    or (
      previous_status = 'completed'
      and next_status = 'archived'
    );
$$;

revoke all
on function public.is_valid_campaign_status_transition(
  public.campaign_status,
  public.campaign_status
)
from public, anon, authenticated;


create function public.enforce_campaign_status_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_valid_campaign_status_transition(
    old.status,
    new.status
  ) then
    raise exception using
      errcode = '23514',
      message = format(
        'invalid campaign status transition: %s -> %s',
        old.status,
        new.status
      );
  end if;

  return new;
end;
$$;

revoke all
on function public.enforce_campaign_status_transition()
from public, anon, authenticated;


create trigger campaigns_enforce_status_transition
before update of status on public.campaigns
for each row
when (old.status is distinct from new.status)
execute function public.enforce_campaign_status_transition();


comment on function public.is_valid_campaign_status_transition(
  public.campaign_status,
  public.campaign_status
) is
  'Returns whether a campaign status transition follows the CampaignOps lifecycle.';

comment on function public.enforce_campaign_status_transition() is
  'Rejects invalid campaign lifecycle transitions at the database boundary.';
