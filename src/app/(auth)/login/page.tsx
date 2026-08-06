import Link from "next/link";

import { signIn } from "@/app/auth-actions";

type LoginPageProperties = {
  searchParams: Promise<{
    error?: string | string[];
    message?: string | string[];
    next?: string | string[];
  }>;
};

function firstValue(
  value: string | string[] | undefined,
) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function LoginPage({
  searchParams,
}: LoginPageProperties) {
  const parameters = await searchParams;
  const error = firstValue(parameters.error);
  const message = firstValue(parameters.message);
  const nextPath =
    firstValue(parameters.next) ?? "/dashboard";

  return (
    <section className="w-full max-w-md rounded-2xl border border-slate-800 bg-slate-900 p-8 shadow-2xl">
      <p className="text-sm font-semibold text-violet-400">
        CampaignOps
      </p>

      <h1 className="mt-2 text-3xl font-bold">
        Sign in
      </h1>

      <p className="mt-2 text-sm text-slate-400">
        Continue to your campaign workspace.
      </p>

      {error ? (
        <p
          role="alert"
          className="mt-6 rounded-lg border border-red-900 bg-red-950/60 p-3 text-sm text-red-200"
        >
          {error}
        </p>
      ) : null}

      {message ? (
        <p className="mt-6 rounded-lg border border-emerald-900 bg-emerald-950/60 p-3 text-sm text-emerald-200">
          {message}
        </p>
      ) : null}

      <form action={signIn} className="mt-6 space-y-5">
        <input
          type="hidden"
          name="next"
          value={nextPath}
        />

        <label className="block">
          <span className="text-sm font-medium">
            Email
          </span>
          <input
            required
            type="email"
            name="email"
            autoComplete="email"
            maxLength={320}
            className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
          />
        </label>

        <label className="block">
          <span className="text-sm font-medium">
            Password
          </span>
          <input
            required
            type="password"
            name="password"
            autoComplete="current-password"
            className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2.5 outline-none focus:border-violet-500"
          />
        </label>

        <button
          type="submit"
          className="w-full rounded-lg bg-violet-600 px-4 py-2.5 font-semibold hover:bg-violet-500"
        >
          Sign in
        </button>
      </form>

      <p className="mt-6 text-center text-sm text-slate-400">
        No account?{" "}
        <Link
          href="/sign-up"
          className="font-semibold text-violet-400 hover:text-violet-300"
        >
          Create one
        </Link>
      </p>
    </section>
  );
}
