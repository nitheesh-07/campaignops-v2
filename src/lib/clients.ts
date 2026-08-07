import "server-only";

import { redirect } from "next/navigation";

import {
  getOrganizationContext,
  type OrganizationRole,
} from "@/lib/organizations";
import { createClient } from "@/lib/supabase/server";

export type ClientStatus = "active" | "archived";

export type ClientRecord = {
  id: string;
  organization_id: string;
  name: string;
  contact_name: string | null;
  contact_email: string | null;
  notes: string | null;
  created_by: string;
  archived_at: string | null;
  created_at: string;
  updated_at: string;
};

const clientColumns = [
  "id",
  "organization_id",
  "name",
  "contact_name",
  "contact_email",
  "notes",
  "created_by",
  "archived_at",
  "created_at",
  "updated_at",
].join(", ");

export function canManageClients(role: OrganizationRole) {
  return role === "owner" || role === "manager";
}

export async function requireClientWorkspace(
  nextPath = "/clients",
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
    canManage: canManageClients(activeOrganization.role),
  };
}

export async function getOrganizationClients(
  organizationId: string,
  status: ClientStatus,
) {
  const supabase = await createClient();
  let query = supabase
    .from("clients")
    .select(clientColumns)
    .eq("organization_id", organizationId)
    .order("name");

  query =
    status === "archived"
      ? query.not("archived_at", "is", null)
      : query.is("archived_at", null);

  const { data, error } = await query;

  if (error) {
    throw new Error("Unable to load clients.");
  }

  return (data ?? []) as unknown as ClientRecord[];
}

export async function getOrganizationClient(
  organizationId: string,
  clientId: string,
) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("clients")
    .select(clientColumns)
    .eq("organization_id", organizationId)
    .eq("id", clientId)
    .maybeSingle();

  if (error) {
    throw new Error("Unable to load the client.");
  }

  return data as ClientRecord | null;
}
