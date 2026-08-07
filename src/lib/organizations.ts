import "server-only";

import { cookies } from "next/headers";

import { createClient } from "@/lib/supabase/server";

export const ACTIVE_ORGANIZATION_COOKIE =
  "campaignops-active-organization";

export type OrganizationRole =
  | "owner"
  | "manager"
  | "member";

export type UserOrganization = {
  id: string;
  name: string;
  slug: string;
  role: OrganizationRole;
};

type MembershipRow = {
  organization_id: string;
  role: OrganizationRole;
};

type OrganizationRow = {
  id: string;
  name: string;
  slug: string;
};

export async function getUserOrganizations(
  userId: string,
): Promise<UserOrganization[]> {
  const supabase = await createClient();

  const { data: memberships, error: membershipError } =
    await supabase
      .from("organization_members")
      .select("organization_id, role")
      .eq("user_id", userId);

  if (membershipError) {
    throw new Error("Unable to load organization memberships.");
  }

  const membershipRows =
    (memberships ?? []) as MembershipRow[];

  if (membershipRows.length === 0) {
    return [];
  }

  const roleByOrganization = new Map(
    membershipRows.map((membership) => [
      membership.organization_id,
      membership.role,
    ]),
  );

  const { data: organizations, error: organizationError } =
    await supabase
      .from("organizations")
      .select("id, name, slug")
      .in(
        "id",
        membershipRows.map(
          (membership) => membership.organization_id,
        ),
      )
      .order("name");

  if (organizationError) {
    throw new Error("Unable to load organizations.");
  }

  return ((organizations ?? []) as OrganizationRow[]).map(
    (organization) => ({
      ...organization,
      role:
        roleByOrganization.get(organization.id) ?? "member",
    }),
  );
}

export async function getOrganizationContext(
  userId: string,
) {
  const organizations = await getUserOrganizations(userId);
  const cookieStore = await cookies();
  const requestedOrganizationId = cookieStore.get(
    ACTIVE_ORGANIZATION_COOKIE,
  )?.value;

  const activeOrganization =
    organizations.find(
      (organization) =>
        organization.id === requestedOrganizationId,
    ) ??
    organizations[0] ??
    null;

  return {
    organizations,
    activeOrganization,
  };
}

export async function setActiveOrganizationCookie(
  organizationId: string,
) {
  const cookieStore = await cookies();

  cookieStore.set(
    ACTIVE_ORGANIZATION_COOKIE,
    organizationId,
    {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge: 60 * 60 * 24 * 30,
    },
  );
}

export async function clearActiveOrganizationCookie() {
  const cookieStore = await cookies();

  cookieStore.delete(ACTIVE_ORGANIZATION_COOKIE);
}
