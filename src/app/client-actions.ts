"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { requireClientWorkspace } from "@/lib/clients";

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

function validateClient(formData: FormData) {
  const name = readText(formData, "name");
  const contactName = readText(formData, "contactName");
  const contactEmail = readText(
    formData,
    "contactEmail",
  ).toLowerCase();
  const notes = readText(formData, "notes");

  if (name.length < 2 || name.length > 120) {
    return {
      ok: false,
      error: "Client name must contain 2 to 120 characters.",
    } as const;
  }

  if (
    contactName &&
    (contactName.length < 2 || contactName.length > 120)
  ) {
    return {
      ok: false,
      error: "Contact name must contain 2 to 120 characters.",
    } as const;
  }

  if (
    contactEmail &&
    (!emailPattern.test(contactEmail) ||
      contactEmail.length > 320)
  ) {
    return {
      ok: false,
      error: "Enter a valid contact email address.",
    } as const;
  }

  if (notes.length > 5000) {
    return {
      ok: false,
      error: "Notes cannot exceed 5000 characters.",
    } as const;
  }

  return {
    ok: true,
    data: {
      name,
      contact_name: contactName || null,
      contact_email: contactEmail || null,
      notes: notes || null,
    },
  } as const;
}

function clientErrorMessage(code: string | undefined) {
  return code === "23505"
    ? "A client with that name already exists in this organization."
    : "The client could not be saved. Please try again.";
}

export async function createCampaignClient(formData: FormData) {
  const validation = validateClient(formData);

  if (!validation.ok) {
    redirectWithMessage("/clients/new", "error", validation.error);
  }

  const { supabase, userId, activeOrganization, canManage } =
    await requireClientWorkspace("/clients/new");

  if (!canManage) {
    redirectWithMessage(
      "/clients",
      "error",
      "Only organization owners and managers can create clients.",
    );
  }

  const { data, error } = await supabase
    .from("clients")
    .insert({
      ...validation.data,
      organization_id: activeOrganization.id,
      created_by: userId,
    })
    .select("id")
    .single();

  if (error || !data) {
    redirectWithMessage(
      "/clients/new",
      "error",
      clientErrorMessage(error?.code),
    );
  }

  revalidatePath("/clients");
  redirectWithMessage(
    `/clients/${data.id}`,
    "message",
    "Client created successfully.",
  );
}

export async function updateCampaignClient(formData: FormData) {
  const clientId = readText(formData, "clientId");

  if (!uuidPattern.test(clientId)) {
    redirectWithMessage("/clients", "error", "Invalid client.");
  }

  const clientPath = `/clients/${clientId}`;
  const validation = validateClient(formData);

  if (!validation.ok) {
    redirectWithMessage(clientPath, "error", validation.error);
  }

  const { supabase, activeOrganization, canManage } =
    await requireClientWorkspace(clientPath);

  if (!canManage) {
    redirectWithMessage(
      clientPath,
      "error",
      "Only organization owners and managers can edit clients.",
    );
  }

  const { data, error } = await supabase
    .from("clients")
    .update(validation.data)
    .eq("organization_id", activeOrganization.id)
    .eq("id", clientId)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    redirectWithMessage(
      clientPath,
      "error",
      error
        ? clientErrorMessage(error.code)
        : "Client not found in the active organization.",
    );
  }

  revalidatePath("/clients");
  revalidatePath(clientPath);
  redirectWithMessage(
    clientPath,
    "message",
    "Client updated successfully.",
  );
}

export async function setCampaignClientArchived(
  formData: FormData,
) {
  const clientId = readText(formData, "clientId");
  const shouldArchive =
    readText(formData, "archived") === "true";

  if (!uuidPattern.test(clientId)) {
    redirectWithMessage("/clients", "error", "Invalid client.");
  }

  const { supabase, activeOrganization, canManage } =
    await requireClientWorkspace(`/clients/${clientId}`);

  if (!canManage) {
    redirectWithMessage(
      "/clients",
      "error",
      "Only organization owners and managers can archive clients.",
    );
  }

  const { data, error } = await supabase
    .from("clients")
    .update({
      archived_at: shouldArchive
        ? new Date().toISOString()
        : null,
    })
    .eq("organization_id", activeOrganization.id)
    .eq("id", clientId)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    redirectWithMessage(
      "/clients",
      "error",
      "The client could not be updated.",
    );
  }

  revalidatePath("/clients");
  revalidatePath(`/clients/${clientId}`);

  if (shouldArchive) {
    redirectWithMessage(
      "/clients?status=archived",
      "message",
      "Client archived successfully.",
    );
  }

  redirectWithMessage(
    "/clients",
    "message",
    "Client restored successfully.",
  );
}
