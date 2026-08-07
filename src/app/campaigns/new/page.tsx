import Link from "next/link";
import { redirect } from "next/navigation";

import { createCampaign } from "@/app/campaign-actions";
import {
  getCampaignClientOptions,
  requireCampaignWorkspace,
} from "@/lib/campaigns";

type NewCampaignPageProperties = {
  searchParams: Promise<{
    error?: string | string[];
  }>;
};

function firstValue(
  value: string | string[] | undefined,
) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function NewCampaignPage({
  searchParams,
}: NewCampaignPageProperties) {
  const { activeOrganization, canManage } =
    await requireCampaignWorkspace("/campaigns/new");

  if (!canManage) {
    redirect(
      "/campaigns?error=Only+organization+owners+and+managers+can+create+campaigns.",
    );
  }

  const clients = await getCampaignClientOptions(
    activeOrganization.id,
    true,
  );
  const parameters = await searchParams;
  const error = firstValue(parameters.error);

  return (
    <main className="min-h-screen bg-slate-950 px-4 py-12 text-slate-100">
      <section className="mx-auto w-full max-w-2xl rounded-2xl border border-slate-800 bg-slate-900 p-8 shadow-2xl">
        <Link
          href="/campaigns"
          className="text-sm font-semibold text-violet-400 hover:text-violet-300"
        >
          ← All campaigns
        </Link>

        <h1 className="mt-5 text-3xl font-bold">Add campaign</h1>
        <p className="mt-2 text-sm text-slate-400">
          New campaigns begin in Draft status.
        </p>

        {error ? (
          <p
            role="alert"
            className="mt-6 rounded-lg border border-red-900 bg-red-950/60 p-3 text-sm text-red-200"
          >
            {error}
          </p>
        ) : null}

        {clients.length === 0 ? (
          <div className="mt-8 rounded-xl border border-amber-900 bg-amber-950/50 p-5 text-amber-100">
            <p className="font-semibold">An active client is required.</p>
            <Link
              href="/clients/new"
              className="mt-3 inline-block text-sm font-semibold underline"
            >
              Add a client first
            </Link>
          </div>
        ) : (
          <form action={createCampaign} className="mt-8 space-y-5">
            <label className="block">
              <span className="text-sm font-medium">Client</span>
              <select
                required
                name="clientId"
                defaultValue=""
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5"
              >
                <option value="" disabled>
                  Select a client
                </option>
                {clients.map((client) => (
                  <option key={client.id} value={client.id}>
                    {client.name}
                  </option>
                ))}
              </select>
            </label>

            <label className="block">
              <span className="text-sm font-medium">Campaign name</span>
              <input
                required
                name="name"
                minLength={2}
                maxLength={160}
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
              />
            </label>

            <label className="block">
              <span className="text-sm font-medium">Description</span>
              <textarea
                name="description"
                maxLength={5000}
                rows={6}
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
              />
            </label>

            <div className="grid gap-5 sm:grid-cols-2">
              <label>
                <span className="text-sm font-medium">Start date</span>
                <input
                  type="date"
                  name="startDate"
                  className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5"
                />
              </label>
              <label>
                <span className="text-sm font-medium">Due date</span>
                <input
                  type="date"
                  name="dueDate"
                  className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5"
                />
              </label>
            </div>

            <div className="flex flex-wrap gap-3">
              <button
                type="submit"
                className="rounded-lg bg-violet-600 px-5 py-2.5 font-semibold hover:bg-violet-500"
              >
                Create campaign
              </button>
              <Link
                href="/campaigns"
                className="rounded-lg border border-slate-700 px-5 py-2.5 font-semibold hover:bg-slate-800"
              >
                Cancel
              </Link>
            </div>
          </form>
        )}
      </section>
    </main>
  );
}
