"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  CAMPAIGN_TRANSITIONS,
  isCampaignStatus,
  requireCampaignWorkspace,
  type CampaignStatus,
} from "@/lib/campaigns";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

function readText(formData: FormData, field: string) {
  const value = formData.get(field);

  return typeof value === "string" ? value.trim() : "";
}

function redirectWithMessage(
  pathname: string,
  type: "error" | "message",
  value: string,
): never {
  const parameters = new URLSearchParams({ [type]: value });
  const separator = pathname.includes("?") ? "&" : "?";

  redirect(`${pathname}${separator}${parameters.toString()}`);
}

function isValidDate(value: string) {
  if (!datePattern.test(value)) {
    return false;
  }

  const parsedDate = new Date(`${value}T00:00:00.000Z`);

  return (
    !Number.isNaN(parsedDate.getTime()) &&
    parsedDate.toISOString().slice(0, 10) === value
  );
}

function validateCampaign(formData: FormData) {
  const clientId = readText(formData, "clientId");
  const name = readText(formData, "name");
  const description = readText(formData, "description");
  const startDate = readText(formData, "startDate");
  const dueDate = readText(formData, "dueDate");

  if (!uuidPattern.test(clientId)) {
    return { ok: false, error: "Select a valid client." } as const;
  }

  if (name.length < 2 || name.length > 160) {
    return {
      ok: false,
      error: "Campaign name must contain 2 to 160 characters.",
    } as const;
  }

  if (description.length > 5000) {
    return {
      ok: false,
      error: "Description cannot exceed 5000 characters.",
    } as const;
  }

  if (startDate && !isValidDate(startDate)) {
    return { ok: false, error: "Enter a valid start date." } as const;
  }

  if (dueDate && !isValidDate(dueDate)) {
    return { ok: false, error: "Enter a valid due date." } as const;
  }

  if (startDate && dueDate && dueDate < startDate) {
    return {
      ok: false,
      error: "Due date cannot be earlier than the start date.",
    } as const;
  }

  return {
    ok: true,
    data: {
      client_id: clientId,
      name,
      description: description || null,
      start_date: startDate || null,
      due_date: dueDate || null,
    },
  } as const;
}

function campaignSaveError(code: string | undefined) {
  if (code === "23505") {
    return "A campaign with that name already exists for this client.";
  }

  if (code === "23514") {
    return "The campaign dates or status transition are invalid.";
  }

  return "The campaign could not be saved. Please try again.";
}

async function getOrganizationClient(
  organizationId: string,
  clientId: string,
) {
  const { supabase } = await requireCampaignWorkspace();
  const { data, error } = await supabase
    .from("clients")
    .select("id, archived_at")
    .eq("organization_id", organizationId)
    .eq("id", clientId)
    .maybeSingle();

  if (error) {
    return null;
  }

  return data as {
    id: string;
    archived_at: string | null;
  } | null;
}

export async function createCampaign(formData: FormData) {
  const validation = validateCampaign(formData);

  if (!validation.ok) {
    redirectWithMessage("/campaigns/new", "error", validation.error);
  }

  const { supabase, userId, activeOrganization, canManage } =
    await requireCampaignWorkspace("/campaigns/new");

  if (!canManage) {
    redirectWithMessage(
      "/campaigns",
      "error",
      "Only organization owners and managers can create campaigns.",
    );
  }

  const client = await getOrganizationClient(
    activeOrganization.id,
    validation.data.client_id,
  );

  if (!client || client.archived_at) {
    redirectWithMessage(
      "/campaigns/new",
      "error",
      "Select an active client from this organization.",
    );
  }

  const { data, error } = await supabase
    .from("campaigns")
    .insert({
      ...validation.data,
      organization_id: activeOrganization.id,
      created_by: userId,
      status: "draft" satisfies CampaignStatus,
    })
    .select("id")
    .single();

  if (error || !data) {
    redirectWithMessage(
      "/campaigns/new",
      "error",
      campaignSaveError(error?.code),
    );
  }

  revalidatePath("/campaigns");
  redirectWithMessage(
    `/campaigns/${data.id}`,
    "message",
    "Campaign created successfully.",
  );
}

export async function updateCampaign(formData: FormData) {
  const campaignId = readText(formData, "campaignId");

  if (!uuidPattern.test(campaignId)) {
    redirectWithMessage("/campaigns", "error", "Invalid campaign.");
  }

  const campaignPath = `/campaigns/${campaignId}`;
  const validation = validateCampaign(formData);

  if (!validation.ok) {
    redirectWithMessage(campaignPath, "error", validation.error);
  }

  const { supabase, activeOrganization, canManage } =
    await requireCampaignWorkspace(campaignPath);

  if (!canManage) {
    redirectWithMessage(
      campaignPath,
      "error",
      "Only organization owners and managers can edit campaigns.",
    );
  }

  const { data: existingCampaign, error: existingError } =
    await supabase
      .from("campaigns")
      .select("id, client_id")
      .eq("organization_id", activeOrganization.id)
      .eq("id", campaignId)
      .maybeSingle();

  if (existingError || !existingCampaign) {
    redirectWithMessage(
      "/campaigns",
      "error",
      "Campaign not found in the active organization.",
    );
  }

  const client = await getOrganizationClient(
    activeOrganization.id,
    validation.data.client_id,
  );

  if (
    !client ||
    (client.archived_at &&
      client.id !== existingCampaign.client_id)
  ) {
    redirectWithMessage(
      campaignPath,
      "error",
      "Select an active client from this organization.",
    );
  }

  const { data, error } = await supabase
    .from("campaigns")
    .update(validation.data)
    .eq("organization_id", activeOrganization.id)
    .eq("id", campaignId)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    redirectWithMessage(
      campaignPath,
      "error",
      error
        ? campaignSaveError(error.code)
        : "Campaign not found in the active organization.",
    );
  }

  revalidatePath("/campaigns");
  revalidatePath(campaignPath);
  redirectWithMessage(
    campaignPath,
    "message",
    "Campaign updated successfully.",
  );
}

export async function transitionCampaignStatus(
  formData: FormData,
) {
  const campaignId = readText(formData, "campaignId");
  const nextStatusValue = readText(formData, "nextStatus");

  if (!uuidPattern.test(campaignId)) {
    redirectWithMessage("/campaigns", "error", "Invalid campaign.");
  }

  const campaignPath = `/campaigns/${campaignId}`;

  if (!isCampaignStatus(nextStatusValue)) {
    redirectWithMessage(
      campaignPath,
      "error",
      "Select a valid campaign status.",
    );
  }

  const { supabase, activeOrganization, canManage } =
    await requireCampaignWorkspace(campaignPath);

  if (!canManage) {
    redirectWithMessage(
      campaignPath,
      "error",
      "Only organization owners and managers can change campaign status.",
    );
  }

  const { data: campaign, error: campaignError } = await supabase
    .from("campaigns")
    .select("id, status")
    .eq("organization_id", activeOrganization.id)
    .eq("id", campaignId)
    .maybeSingle();

  if (campaignError || !campaign) {
    redirectWithMessage(
      "/campaigns",
      "error",
      "Campaign not found in the active organization.",
    );
  }

  const currentStatus = campaign.status as CampaignStatus;

  if (!CAMPAIGN_TRANSITIONS[currentStatus].includes(nextStatusValue)) {
    redirectWithMessage(
      campaignPath,
      "error",
      `Cannot move a campaign from ${currentStatus} to ${nextStatusValue}.`,
    );
  }

  const { data, error } = await supabase
    .from("campaigns")
    .update({ status: nextStatusValue })
    .eq("organization_id", activeOrganization.id)
    .eq("id", campaignId)
    .eq("status", currentStatus)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    redirectWithMessage(
      campaignPath,
      "error",
      error?.code === "23514"
        ? "That campaign status transition is not allowed."
        : "The campaign changed elsewhere. Refresh and try again.",
    );
  }

  revalidatePath("/campaigns");
  revalidatePath(campaignPath);
  redirectWithMessage(
    campaignPath,
    "message",
    "Campaign status updated successfully.",
  );
}
