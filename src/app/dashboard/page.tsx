import Link from "next/link";
import { redirect } from "next/navigation";

import { signOut } from "@/app/auth-actions";
import { selectOrganization } from "@/app/organization-actions";
import { getOrganizationContext } from "@/lib/organizations";
import { createClient } from "@/lib/supabase/server";

type DashboardPageProperties = {
  searchParams: Promise<{
    error?: string | string[];
  }>;
};

function firstValue(
  value: string | string[] | undefined,
) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function DashboardPage({
  searchParams,
}: DashboardPageProperties) {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub;

  if (!userId) {
    redirect("/login");
  }

  const [profileResult, organizationContext] =
    await Promise.all([
      supabase
        .from("profiles")
        .select("full_name")
        .eq("id", userId)
        .maybeSingle(),
      getOrganizationContext(userId),
    ]);

  const { organizations, activeOrganization } =
    organizationContext;

  if (!activeOrganization) {
    redirect("/onboarding");
  }

  const displayName =
    typeof profileResult.data?.full_name === "string"
      ? profileResult.data.full_name
      : "CampaignOps user";

  const parameters = await searchParams;
  const error = firstValue(parameters.error);

  return (
    <main className="min-h-screen bg-slate-950 p-8 text-slate-100">
      <div className="mx-auto max-w-5xl">
        <header className="flex flex-wrap items-center justify-between gap-6 border-b border-slate-800 pb-6">
          <div>
            <p className="text-sm font-semibold text-violet-400">
              CampaignOps
            </p>
            <h1 className="mt-1 text-3xl font-bold">
              Dashboard
            </h1>
          </div>

          <div className="flex items-center gap-3">
            <form action={selectOrganization}>
              <label className="sr-only" htmlFor="organizationId">
                Active organization
              </label>
              <select
                id="organizationId"
                name="organizationId"
                defaultValue={activeOrganization.id}
                className="rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
              >
                {organizations.map((organization) => (
                  <option
                    key={organization.id}
                    value={organization.id}
                  >
                    {organization.name}
                  </option>
                ))}
              </select>

              <button
                type="submit"
                className="ml-2 rounded-lg bg-violet-600 px-3 py-2 text-sm font-semibold hover:bg-violet-500"
              >
                Switch
              </button>
            </form>

            <form action={signOut}>
              <button
                type="submit"
                className="rounded-lg border border-slate-700 px-4 py-2 text-sm font-semibold hover:bg-slate-900"
              >
                Sign out
              </button>
            </form>
          </div>
        </header>

        {error ? (
          <p
            role="alert"
            className="mt-6 rounded-lg border border-red-900 bg-red-950/60 p-3 text-sm text-red-200"
          >
            {error}
          </p>
        ) : null}

        <section className="mt-10 rounded-2xl border border-slate-800 bg-slate-900 p-8">
          <p className="text-sm font-semibold uppercase tracking-wider text-violet-400">
            Active organization
          </p>
          <h2 className="mt-2 text-2xl font-semibold">
            {activeOrganization.name}
          </h2>
          <p className="mt-1 font-mono text-sm text-slate-500">
            {activeOrganization.slug}
          </p>

          <div className="mt-8 border-t border-slate-800 pt-8">
            <h3 className="text-xl font-semibold">
              Welcome, {displayName}
            </h3>
            <p className="mt-3 text-slate-400">
              Your private campaign workspace is ready.
            </p>

            <div className="mt-6 flex flex-wrap gap-3">
              <Link
                href="/clients"
                className="inline-flex rounded-lg bg-violet-600 px-4 py-2.5 text-sm font-semibold hover:bg-violet-500"
              >
                Manage clients
              </Link>
              <Link
                href="/campaigns"
                className="inline-flex rounded-lg border border-slate-700 px-4 py-2.5 text-sm font-semibold hover:bg-slate-800"
              >
                Manage campaigns
              </Link>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
