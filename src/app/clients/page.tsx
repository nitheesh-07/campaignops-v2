import Link from "next/link";

import { signOut } from "@/app/auth-actions";
import { setCampaignClientArchived } from "@/app/client-actions";
import {
  getOrganizationClients,
  requireClientWorkspace,
  type ClientStatus,
} from "@/lib/clients";

type ClientsPageProperties = {
  searchParams: Promise<{
    status?: string | string[];
    error?: string | string[];
    message?: string | string[];
  }>;
};

function firstValue(
  value: string | string[] | undefined,
) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function ClientsPage({
  searchParams,
}: ClientsPageProperties) {
  const parameters = await searchParams;
  const status: ClientStatus =
    firstValue(parameters.status) === "archived"
      ? "archived"
      : "active";
  const error = firstValue(parameters.error);
  const message = firstValue(parameters.message);
  const { activeOrganization, canManage } =
    await requireClientWorkspace("/clients");
  const clients = await getOrganizationClients(
    activeOrganization.id,
    status,
  );

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
            <h1 className="mt-1 text-3xl font-bold">Clients</h1>
            <p className="mt-2 text-sm text-slate-400">
              {activeOrganization.name} · {activeOrganization.role}
            </p>
          </div>

          <div className="flex items-center gap-3">
            {canManage ? (
              <Link
                href="/clients/new"
                className="rounded-lg bg-violet-600 px-4 py-2 text-sm font-semibold hover:bg-violet-500"
              >
                Add client
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

        <nav
          aria-label="Client status"
          className="mt-8 flex gap-2"
        >
          <Link
            href="/clients"
            aria-current={status === "active" ? "page" : undefined}
            className={`rounded-lg px-4 py-2 text-sm font-semibold ${
              status === "active"
                ? "bg-slate-100 text-slate-950"
                : "border border-slate-700 text-slate-300 hover:bg-slate-900"
            }`}
          >
            Active
          </Link>
          <Link
            href="/clients?status=archived"
            aria-current={status === "archived" ? "page" : undefined}
            className={`rounded-lg px-4 py-2 text-sm font-semibold ${
              status === "archived"
                ? "bg-slate-100 text-slate-950"
                : "border border-slate-700 text-slate-300 hover:bg-slate-900"
            }`}
          >
            Archived
          </Link>
        </nav>

        <section className="mt-6">
          {clients.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-slate-700 bg-slate-900/60 p-10 text-center">
              <h2 className="text-xl font-semibold">
                No {status} clients
              </h2>
              <p className="mt-2 text-sm text-slate-400">
                {status === "active" && canManage
                  ? "Add the first client for this organization."
                  : `This organization has no ${status} clients.`}
              </p>
            </div>
          ) : (
            <ul className="grid gap-4">
              {clients.map((client) => (
                <li
                  key={client.id}
                  className="flex flex-wrap items-center justify-between gap-5 rounded-2xl border border-slate-800 bg-slate-900 p-6"
                >
                  <div>
                    <Link
                      href={`/clients/${client.id}`}
                      className="text-xl font-semibold hover:text-violet-300"
                    >
                      {client.name}
                    </Link>
                    <p className="mt-2 text-sm text-slate-400">
                      {client.contact_name ?? "No contact name"}
                      {client.contact_email
                        ? ` · ${client.contact_email}`
                        : ""}
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
                        value={String(status === "active")}
                      />
                      <button
                        type="submit"
                        className="rounded-lg border border-slate-700 px-4 py-2 text-sm font-semibold hover:bg-slate-800"
                      >
                        {status === "active"
                          ? "Archive client"
                          : "Restore client"}
                      </button>
                    </form>
                  ) : null}
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </main>
  );
}
