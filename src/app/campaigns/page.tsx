import Link from "next/link";

import { signOut } from "@/app/auth-actions";
import {
  CAMPAIGN_STATUSES,
  CAMPAIGN_STATUS_LABELS,
  getCampaignClientOptions,
  getOrganizationCampaigns,
  isCampaignStatus,
  requireCampaignWorkspace,
  type CampaignStatus,
} from "@/lib/campaigns";

type CampaignsPageProperties = {
  searchParams: Promise<{
    status?: string | string[];
    client?: string | string[];
    error?: string | string[];
    message?: string | string[];
  }>;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function firstValue(
  value: string | string[] | undefined,
) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function CampaignsPage({
  searchParams,
}: CampaignsPageProperties) {
  const parameters = await searchParams;
  const requestedStatus = firstValue(parameters.status) ?? "all";
  const status: CampaignStatus | "all" =
    isCampaignStatus(requestedStatus) ? requestedStatus : "all";
  const requestedClient = firstValue(parameters.client) ?? "";
  const clientId = uuidPattern.test(requestedClient)
    ? requestedClient
    : null;
  const error = firstValue(parameters.error);
  const message = firstValue(parameters.message);
  const { activeOrganization, canManage } =
    await requireCampaignWorkspace("/campaigns");
  const [campaigns, clients] = await Promise.all([
    getOrganizationCampaigns(
      activeOrganization.id,
      status,
      clientId,
    ),
    getCampaignClientOptions(activeOrganization.id),
  ]);

  return (
    <main className="min-h-screen bg-slate-950 p-6 text-slate-100 sm:p-8">
      <div className="mx-auto max-w-6xl">
        <header className="flex flex-wrap items-center justify-between gap-5 border-b border-slate-800 pb-6">
          <div>
            <Link
              href="/dashboard"
              className="text-sm font-semibold text-violet-400 hover:text-violet-300"
            >
              CampaignOps
            </Link>
            <h1 className="mt-1 text-3xl font-bold">Campaigns</h1>
            <p className="mt-2 text-sm text-slate-400">
              {activeOrganization.name} · {activeOrganization.role}
            </p>
          </div>

          <div className="flex items-center gap-3">
            {canManage ? (
              <Link
                href="/campaigns/new"
                className="rounded-lg bg-violet-600 px-4 py-2 text-sm font-semibold hover:bg-violet-500"
              >
                Add campaign
              </Link>
            ) : null}
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

        {message ? (
          <p
            role="status"
            className="mt-6 rounded-lg border border-emerald-900 bg-emerald-950/60 p-3 text-sm text-emerald-200"
          >
            {message}
          </p>
        ) : null}

        <form
          action="/campaigns"
          className="mt-8 grid gap-4 rounded-2xl border border-slate-800 bg-slate-900 p-5 sm:grid-cols-[1fr_1fr_auto]"
        >
          <label>
            <span className="text-sm font-medium">Campaign status</span>
            <select
              name="status"
              defaultValue={status}
              className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5"
            >
              <option value="all">All statuses</option>
              {CAMPAIGN_STATUSES.map((campaignStatus) => (
                <option key={campaignStatus} value={campaignStatus}>
                  {CAMPAIGN_STATUS_LABELS[campaignStatus]}
                </option>
              ))}
            </select>
          </label>

          <label>
            <span className="text-sm font-medium">Client</span>
            <select
              name="client"
              defaultValue={clientId ?? ""}
              className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5"
            >
              <option value="">All clients</option>
              {clients.map((client) => (
                <option key={client.id} value={client.id}>
                  {client.name}
                  {client.archived_at ? " (archived)" : ""}
                </option>
              ))}
            </select>
          </label>

          <button
            type="submit"
            className="self-end rounded-lg border border-slate-700 px-5 py-2.5 font-semibold hover:bg-slate-800"
          >
            Apply filters
          </button>
        </form>

        <section className="mt-6">
          {campaigns.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-slate-700 bg-slate-900/60 p-10 text-center">
              <h2 className="text-xl font-semibold">No campaigns found</h2>
              <p className="mt-2 text-sm text-slate-400">
                {canManage
                  ? "Create a campaign or change the current filters."
                  : "No campaigns match the current filters."}
              </p>
            </div>
          ) : (
            <ul className="grid gap-4">
              {campaigns.map((campaign) => (
                <li
                  key={campaign.id}
                  className="rounded-2xl border border-slate-800 bg-slate-900 p-6"
                >
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div>
                      <Link
                        href={`/campaigns/${campaign.id}`}
                        className="text-xl font-semibold hover:text-violet-300"
                      >
                        {campaign.name}
                      </Link>
                      <p className="mt-2 text-sm text-slate-400">
                        {campaign.client_name}
                      </p>
                    </div>
                    <span className="rounded-full border border-violet-800 bg-violet-950/60 px-3 py-1 text-xs font-semibold text-violet-200">
                      {CAMPAIGN_STATUS_LABELS[campaign.status]}
                    </span>
                  </div>
                  <div className="mt-5 flex flex-wrap gap-x-8 gap-y-2 border-t border-slate-800 pt-4 text-sm text-slate-400">
                    <span>
                      Start: {campaign.start_date ?? "Not set"}
                    </span>
                    <span>
                      Due: {campaign.due_date ?? "Not set"}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </main>
  );
}
