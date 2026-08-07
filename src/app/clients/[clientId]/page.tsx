import Link from "next/link";
import { notFound } from "next/navigation";

import {
  setCampaignClientArchived,
  updateCampaignClient,
} from "@/app/client-actions";
import {
  getOrganizationClient,
  requireClientWorkspace,
} from "@/lib/clients";

type ClientPageProperties = {
  params: Promise<{ clientId: string }>;
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

export default async function ClientPage({
  params,
  searchParams,
}: ClientPageProperties) {
  const { clientId } = await params;

  if (!uuidPattern.test(clientId)) {
    notFound();
  }

  const { activeOrganization, canManage } =
    await requireClientWorkspace(`/clients/${clientId}`);
  const client = await getOrganizationClient(
    activeOrganization.id,
    clientId,
  );

  if (!client) {
    notFound();
  }

  const parameters = await searchParams;
  const error = firstValue(parameters.error);
  const message = firstValue(parameters.message);

  return (
    <main className="min-h-screen bg-slate-950 px-4 py-12 text-slate-100">
      <section className="mx-auto w-full max-w-3xl rounded-2xl border border-slate-800 bg-slate-900 p-8 shadow-2xl">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <Link
              href={
                client.archived_at
                  ? "/clients?status=archived"
                  : "/clients"
              }
              className="text-sm font-semibold text-violet-400 hover:text-violet-300"
            >
              ← All clients
            </Link>
            <h1 className="mt-5 text-3xl font-bold">
              {client.name}
            </h1>
            <p className="mt-2 text-sm text-slate-400">
              {activeOrganization.name}
              {client.archived_at ? " · Archived" : " · Active"}
            </p>
          </div>

          {canManage ? (
            <form action={setCampaignClientArchived}>
              <input
                type="hidden"
                name="clientId"
                value={client.id}
              />
              <input
                type="hidden"
                name="archived"
                value={String(!client.archived_at)}
              />
              <button
                type="submit"
                className="rounded-lg border border-slate-700 px-4 py-2 text-sm font-semibold hover:bg-slate-800"
              >
                {client.archived_at
                  ? "Restore client"
                  : "Archive client"}
              </button>
            </form>
          ) : null}
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

        {canManage ? (
          <form
            action={updateCampaignClient}
            className="mt-8 space-y-5"
          >
            <input
              type="hidden"
              name="clientId"
              value={client.id}
            />

            <label className="block">
              <span className="text-sm font-medium">Client name</span>
              <input
                required
                name="name"
                defaultValue={client.name}
                minLength={2}
                maxLength={120}
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
              />
            </label>

            <label className="block">
              <span className="text-sm font-medium">Contact name</span>
              <input
                name="contactName"
                defaultValue={client.contact_name ?? ""}
                minLength={2}
                maxLength={120}
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
              />
            </label>

            <label className="block">
              <span className="text-sm font-medium">Contact email</span>
              <input
                type="email"
                name="contactEmail"
                defaultValue={client.contact_email ?? ""}
                maxLength={320}
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
              />
            </label>

            <label className="block">
              <span className="text-sm font-medium">Notes</span>
              <textarea
                name="notes"
                defaultValue={client.notes ?? ""}
                maxLength={5000}
                rows={6}
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
              />
            </label>

            <button
              type="submit"
              className="rounded-lg bg-violet-600 px-5 py-2.5 font-semibold hover:bg-violet-500"
            >
              Save client
            </button>
          </form>
        ) : (
          <dl className="mt-8 grid gap-5 rounded-xl border border-slate-800 bg-slate-950 p-6 sm:grid-cols-2">
            <div>
              <dt className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Contact name
              </dt>
              <dd className="mt-2 text-slate-200">
                {client.contact_name ?? "Not provided"}
              </dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Contact email
              </dt>
              <dd className="mt-2 text-slate-200">
                {client.contact_email ?? "Not provided"}
              </dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Notes
              </dt>
              <dd className="mt-2 whitespace-pre-wrap text-slate-200">
                {client.notes ?? "No notes"}
              </dd>
            </div>
          </dl>
        )}
      </section>
    </main>
  );
}
