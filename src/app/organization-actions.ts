"use server";

import { randomUUID } from "node:crypto";

import { redirect } from "next/navigation";

import {
  setActiveOrganizationCookie,
} from "@/lib/organizations";
import { createClient } from "@/lib/supabase/server";

const slugPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function readText(formData: FormData, field: string) {
  const value = formData.get(field);

  return typeof value === "string" ? value.trim() : "";
}

function redirectWithError(
  pathname: string,
  error: string,
): never {
  const parameters = new URLSearchParams({ error });

  redirect(`${pathname}?${parameters.toString()}`);
}

async function getAuthenticatedUserId() {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub;

  if (!userId) {
    redirect("/login");
  }

  return { supabase, userId };
}

export async function createOrganization(formData: FormData) {
  const name = readText(formData, "name");
  const slug = readText(formData, "slug").toLowerCase();

  if (name.length < 2 || name.length > 120) {
    redirectWithError(
      "/onboarding",
      "Organization name must contain 2 to 120 characters.",
    );
  }

  if (
    slug.length < 2 ||
    slug.length > 63 ||
    !slugPattern.test(slug)
  ) {
    redirectWithError(
      "/onboarding",
      "Slug must use lowercase letters, numbers, and single hyphens.",
    );
  }

  const { supabase, userId } =
    await getAuthenticatedUserId();
  const organizationId = randomUUID();

  const { error } = await supabase.from("organizations").insert({
    id: organizationId,
    name,
    slug,
    created_by: userId,
  });

  if (error) {
    const message =
      error.code === "23505"
        ? "That organization slug is already in use."
        : "Organization creation failed. Please try again.";

    redirectWithError("/onboarding", message);
  }

  await setActiveOrganizationCookie(organizationId);
  redirect("/dashboard");
}

export async function selectOrganization(formData: FormData) {
  const organizationId = readText(
    formData,
    "organizationId",
  );

  if (!uuidPattern.test(organizationId)) {
    redirectWithError(
      "/dashboard",
      "Select a valid organization.",
    );
  }

  const { supabase, userId } =
    await getAuthenticatedUserId();

  const { data: membership, error } = await supabase
    .from("organization_members")
    .select("organization_id")
    .eq("organization_id", organizationId)
    .eq("user_id", userId)
    .maybeSingle();

  if (error || !membership) {
    redirectWithError(
      "/dashboard",
      "You do not have access to that organization.",
    );
  }

  await setActiveOrganizationCookie(organizationId);
  redirect("/dashboard");
}
