import Link from "next/link";
import { redirect } from "next/navigation";

import { createCampaignClient } from "@/app/client-actions";
import { requireClientWorkspace } from "@/lib/clients";

type NewClientPageProperties = {
  searchParams: Promise<{
    error?: string | string[];
  }>;
};

function firstValue(
  value: string | string[] | undefined,
) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function NewClientPage({
  searchParams,
}: NewClientPageProperties) {
  const { activeOrganization, canManage } =
    await requireClientWorkspace("/clients/new");

  if (!canManage) {
    redirect(
      "/clients?error=Only+organization+owners+and+managers+can+create+clients.",
    );
  }

  const parameters = await searchParams;
  const error = firstValue(parameters.error);

  return (
    <main className="min-h-screen bg-slate-950 px-4 py-12 text-slate-100">
      <section className="mx-auto w-full max-w-2xl rounded-2xl border border-slate-800 bg-slate-900 p-8 shadow-2xl">
        <Link
          href="/clients"
          className="text-sm font-semibold text-violet-400 hover:text-violet-300"
        >
          ← All clients
        </Link>

        <h1 className="mt-5 text-3xl font-bold">Add client</h1>
        <p className="mt-2 text-sm text-slate-400">
          Create a client inside {activeOrganization.name}.
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
          action={createCampaignClient}
          className="mt-8 space-y-5"
        >
          <label className="block">
            <span className="text-sm font-medium">Client name</span>
            <input
              required
              name="name"
              minLength={2}
              maxLength={120}
              autoComplete="organization"
              className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
            />
          </label>

          <label className="block">
            <span className="text-sm font-medium">Contact name</span>
            <input
              name="contactName"
              minLength={2}
              maxLength={120}
              autoComplete="name"
              className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
            />
          </label>

          <label className="block">
            <span className="text-sm font-medium">Contact email</span>
            <input
              type="email"
              name="contactEmail"
              maxLength={320}
              autoComplete="email"
              className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
            />
          </label>

          <label className="block">
            <span className="text-sm font-medium">Notes</span>
            <textarea
              name="notes"
              maxLength={5000}
              rows={6}
              className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
            />
          </label>

          <div className="flex flex-wrap gap-3">
            <button
              type="submit"
              className="rounded-lg bg-violet-600 px-5 py-2.5 font-semibold hover:bg-violet-500"
            >
              Create client
            </button>
            <Link
              href="/clients"
              className="rounded-lg border border-slate-700 px-5 py-2.5 font-semibold hover:bg-slate-800"
            >
              Cancel
            </Link>
          </div>
        </form>
      </section>
    </main>
  );
}
