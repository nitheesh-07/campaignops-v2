import "server-only";

import { redirect } from "next/navigation";

import {
  getOrganizationContext,
  type OrganizationRole,
} from "@/lib/organizations";
import { createClient } from "@/lib/supabase/server";

export const CAMPAIGN_STATUSES = [
  "draft",
  "active",
  "in_review",
  "approved",
  "completed",
  "archived",
] as const;

export type CampaignStatus =
  (typeof CAMPAIGN_STATUSES)[number];

export const CAMPAIGN_STATUS_LABELS: Record<
  CampaignStatus,
  string
> = {
  draft: "Draft",
  active: "Active",
  in_review: "In review",
  approved: "Approved",
  completed: "Completed",
  archived: "Archived",
};

export const CAMPAIGN_TRANSITIONS: Record<
  CampaignStatus,
  readonly CampaignStatus[]
> = {
  draft: ["active", "archived"],
  active: ["in_review", "archived"],
  in_review: ["active", "approved"],
  approved: ["completed"],
  completed: ["archived"],
  archived: [],
};

export type CampaignRecord = {
  id: string;
  organization_id: string;
  client_id: string;
  name: string;
  description: string | null;
  status: CampaignStatus;
  start_date: string | null;
  due_date: string | null;
  created_by: string;
  created_at: string;
  updated_at: string;
};

export type CampaignListItem = CampaignRecord & {
  client_name: string;
};

export type CampaignClientOption = {
  id: string;
  name: string;
  archived_at: string | null;
};

const campaignColumns = [
  "id",
  "organization_id",
  "client_id",
  "name",
  "description",
  "status",
  "start_date",
  "due_date",
  "created_by",
  "created_at",
  "updated_at",
].join(", ");

export function isCampaignStatus(
  value: string,
): value is CampaignStatus {
  return (CAMPAIGN_STATUSES as readonly string[]).includes(value);
}

export function canManageCampaigns(role: OrganizationRole) {
  return role === "owner" || role === "manager";
}

export async function requireCampaignWorkspace(
  nextPath = "/campaigns",
) {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub;

  if (!userId) {
    const parameters = new URLSearchParams({ next: nextPath });

    redirect(`/login?${parameters.toString()}`);
  }

  const { organizations, activeOrganization } =
    await getOrganizationContext(userId);

  if (!activeOrganization) {
    redirect("/onboarding");
  }

  return {
    supabase,
    userId,
    organizations,
    activeOrganization,
    canManage: canManageCampaigns(activeOrganization.role),
  };
}

export async function getCampaignClientOptions(
  organizationId: string,
  activeOnly = false,
) {
  const supabase = await createClient();
  let query = supabase
    .from("clients")
    .select("id, name, archived_at")
    .eq("organization_id", organizationId)
    .order("name");

  if (activeOnly) {
    query = query.is("archived_at", null);
  }

  const { data, error } = await query;

  if (error) {
    throw new Error("Unable to load campaign clients.");
  }

  return (data ?? []) as CampaignClientOption[];
}

export async function getOrganizationCampaigns(
  organizationId: string,
  status: CampaignStatus | "all",
  clientId: string | null,
) {
  const supabase = await createClient();
  let query = supabase
    .from("campaigns")
    .select(campaignColumns)
    .eq("organization_id", organizationId)
    .order("due_date", { ascending: true, nullsFirst: false })
    .order("name");

  if (status !== "all") {
    query = query.eq("status", status);
  }

  if (clientId) {
    query = query.eq("client_id", clientId);
  }

  const { data, error } = await query;

  if (error) {
    throw new Error("Unable to load campaigns.");
  }

  const campaigns = (data ?? []) as unknown as CampaignRecord[];
  const clientIds = [...new Set(
    campaigns.map((campaign) => campaign.client_id),
  )];
  const clientNames = new Map<string, string>();

  if (clientIds.length > 0) {
    const { data: clients, error: clientError } = await supabase
      .from("clients")
      .select("id, name")
      .eq("organization_id", organizationId)
      .in("id", clientIds);

    if (clientError) {
      throw new Error("Unable to load campaign clients.");
    }

    for (const client of clients ?? []) {
      clientNames.set(client.id, client.name);
    }
  }

  return campaigns.map((campaign) => ({
    ...campaign,
    client_name:
      clientNames.get(campaign.client_id) ?? "Unknown client",
  }));
}

export async function getOrganizationCampaign(
  organizationId: string,
  campaignId: string,
) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("campaigns")
    .select(campaignColumns)
    .eq("organization_id", organizationId)
    .eq("id", campaignId)
    .maybeSingle();

  if (error) {
    throw new Error("Unable to load the campaign.");
  }

  return data as CampaignRecord | null;
}
