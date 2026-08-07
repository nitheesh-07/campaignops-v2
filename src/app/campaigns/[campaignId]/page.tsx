import Link from "next/link";
import { notFound } from "next/navigation";

import {
  transitionCampaignStatus,
  updateCampaign,
} from "@/app/campaign-actions";
import {
  CAMPAIGN_STATUS_LABELS,
  CAMPAIGN_TRANSITIONS,
  getCampaignClientOptions,
  getOrganizationCampaign,
  requireCampaignWorkspace,
} from "@/lib/campaigns";

type CampaignPageProperties = {
  params: Promise<{ campaignId: string }>;
  searchParams: Promise<{
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

export default async function CampaignPage({
  params,
  searchParams,
}: CampaignPageProperties) {
  const { campaignId } = await params;

  if (!uuidPattern.test(campaignId)) {
    notFound();
  }

  const { activeOrganization, canManage } =
    await requireCampaignWorkspace(`/campaigns/${campaignId}`);
  const [campaign, clients] = await Promise.all([
    getOrganizationCampaign(activeOrganization.id, campaignId),
    getCampaignClientOptions(activeOrganization.id),
  ]);

  if (!campaign) {
    notFound();
  }

  const currentClient = clients.find(
    (client) => client.id === campaign.client_id,
  );
  const editableClients = clients.filter(
    (client) => !client.archived_at || client.id === campaign.client_id,
  );
  const parameters = await searchParams;
  const error = firstValue(parameters.error);
  const message = firstValue(parameters.message);
  const nextStatuses = CAMPAIGN_TRANSITIONS[campaign.status];

  return (
    <main className="min-h-screen bg-slate-950 px-4 py-12 text-slate-100">
      <section className="mx-auto w-full max-w-3xl rounded-2xl border border-slate-800 bg-slate-900 p-8 shadow-2xl">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <Link
              href="/campaigns"
              className="text-sm font-semibold text-violet-400 hover:text-violet-300"
            >
              ← All campaigns
            </Link>
            <h1 className="mt-5 text-3xl font-bold">{campaign.name}</h1>
            <p className="mt-2 text-sm text-slate-400">
              {currentClient?.name ?? "Unknown client"} ·{" "}
              {CAMPAIGN_STATUS_LABELS[campaign.status]}
            </p>
          </div>
          <span className="rounded-full border border-violet-800 bg-violet-950/60 px-3 py-1 text-xs font-semibold text-violet-200">
            {CAMPAIGN_STATUS_LABELS[campaign.status]}
          </span>
        </div>

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

        {canManage && nextStatuses.length > 0 ? (
          <section className="mt-8 rounded-xl border border-slate-800 bg-slate-950 p-5">
            <h2 className="font-semibold">Change campaign status</h2>
            <div className="mt-4 flex flex-wrap gap-3">
              {nextStatuses.map((nextStatus) => (
                <form key={nextStatus} action={transitionCampaignStatus}>
                  <input
                    type="hidden"
                    name="campaignId"
                    value={campaign.id}
                  />
                  <input
                    type="hidden"
                    name="nextStatus"
                    value={nextStatus}
                  />
                  <button
                    type="submit"
                    className="rounded-lg border border-violet-700 px-4 py-2 text-sm font-semibold text-violet-200 hover:bg-violet-950"
                  >
                    Move to {CAMPAIGN_STATUS_LABELS[nextStatus]}
                  </button>
                </form>
              ))}
            </div>
          </section>
        ) : null}

        {canManage ? (
          <form action={updateCampaign} className="mt-8 space-y-5">
            <input
              type="hidden"
              name="campaignId"
              value={campaign.id}
            />

            <label className="block">
              <span className="text-sm font-medium">Client</span>
              <select
                required
                name="clientId"
                defaultValue={campaign.client_id}
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5"
              >
                {editableClients.map((client) => (
                  <option key={client.id} value={client.id}>
                    {client.name}
                    {client.archived_at ? " (archived)" : ""}
                  </option>
                ))}
              </select>
            </label>

            <label className="block">
              <span className="text-sm font-medium">Campaign name</span>
              <input
                required
                name="name"
                defaultValue={campaign.name}
                minLength={2}
                maxLength={160}
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
              />
            </label>

            <label className="block">
              <span className="text-sm font-medium">Description</span>
              <textarea
                name="description"
                defaultValue={campaign.description ?? ""}
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
                  defaultValue={campaign.start_date ?? ""}
                  className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5"
                />
              </label>
              <label>
                <span className="text-sm font-medium">Due date</span>
                <input
                  type="date"
                  name="dueDate"
                  defaultValue={campaign.due_date ?? ""}
                  className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5"
                />
              </label>
            </div>

            <button
              type="submit"
              className="rounded-lg bg-violet-600 px-5 py-2.5 font-semibold hover:bg-violet-500"
            >
              Save campaign
            </button>
          </form>
        ) : (
          <dl className="mt-8 grid gap-5 rounded-xl border border-slate-800 bg-slate-950 p-6 sm:grid-cols-2">
            <div>
              <dt className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Start date
              </dt>
              <dd className="mt-2">{campaign.start_date ?? "Not set"}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Due date
              </dt>
              <dd className="mt-2">{campaign.due_date ?? "Not set"}</dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Description
              </dt>
              <dd className="mt-2 whitespace-pre-wrap">
                {campaign.description ?? "No description"}
              </dd>
            </div>
          </dl>
        )}
      </section>
    </main>
  );
}
