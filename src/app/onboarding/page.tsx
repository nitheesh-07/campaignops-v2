import { redirect } from "next/navigation";

import { signOut } from "@/app/auth-actions";
import { createOrganization } from "@/app/organization-actions";
import { getUserOrganizations } from "@/lib/organizations";
import { createClient } from "@/lib/supabase/server";

type OnboardingPageProperties = {
  searchParams: Promise<{
    error?: string | string[];
  }>;
};

function firstValue(
  value: string | string[] | undefined,
) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function OnboardingPage({
  searchParams,
}: OnboardingPageProperties) {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub;

  if (!userId) {
    redirect("/login?next=%2Fonboarding");
  }

  const organizations = await getUserOrganizations(userId);

  if (organizations.length > 0) {
    redirect("/dashboard");
  }

  const parameters = await searchParams;
  const error = firstValue(parameters.error);

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950 px-4 py-12 text-slate-100">
      <section className="w-full max-w-lg rounded-2xl border border-slate-800 bg-slate-900 p-8 shadow-2xl">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="text-sm font-semibold text-violet-400">
              CampaignOps
            </p>
            <h1 className="mt-2 text-3xl font-bold">
              Create your organization
            </h1>
          </div>

          <form action={signOut}>
            <button
              type="submit"
              className="text-sm font-semibold text-slate-400 hover:text-slate-100"
            >
              Sign out
            </button>
          </form>
        </div>

        <p className="mt-3 text-sm text-slate-400">
          Your organization is the private workspace where
          your team manages clients, campaigns, and tasks.
        </p>

        {error ? (
          <p
            role="alert"
            className="mt-6 rounded-lg border border-red-900 bg-red-950/60 p-3 text-sm text-red-200"
          >
            {error}
          </p>
        ) : null}

        <form
          action={createOrganization}
          className="mt-6 space-y-5"
        >
          <label className="block">
            <span className="text-sm font-medium">
              Organization name
            </span>
            <input
              required
              name="name"
              minLength={2}
              maxLength={120}
              autoComplete="organization"
              placeholder="Acme Marketing"
              className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
            />
          </label>

          <label className="block">
            <span className="text-sm font-medium">
              Organization slug
            </span>
            <input
              required
              name="slug"
              minLength={2}
              maxLength={63}
              pattern="[a-z0-9]+(-[a-z0-9]+)*"
              placeholder="acme-marketing"
              className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 font-mono text-sm outline-none focus:border-violet-500"
            />
            <span className="mt-2 block text-xs text-slate-500">
              Use lowercase letters, numbers, and hyphens.
            </span>
          </label>

          <button
            type="submit"
            className="w-full rounded-lg bg-violet-600 px-4 py-2.5 font-semibold hover:bg-violet-500"
          >
            Create organization
          </button>
        </form>
      </section>
    </main>
  );
}
