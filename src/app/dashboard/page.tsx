import { redirect } from "next/navigation";

import { signOut } from "@/app/auth-actions";
import { createClient } from "@/lib/supabase/server";

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub;

  if (!userId) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name")
    .eq("id", userId)
    .maybeSingle();

  const displayName =
    typeof profile?.full_name === "string"
      ? profile.full_name
      : "CampaignOps user";

  return (
    <main className="min-h-screen bg-slate-950 p-8 text-slate-100">
      <div className="mx-auto max-w-5xl">
        <header className="flex items-center justify-between border-b border-slate-800 pb-6">
          <div>
            <p className="text-sm font-semibold text-violet-400">
              CampaignOps
            </p>
            <h1 className="mt-1 text-3xl font-bold">
              Dashboard
            </h1>
          </div>

          <form action={signOut}>
            <button
              type="submit"
              className="rounded-lg border border-slate-700 px-4 py-2 text-sm font-semibold hover:bg-slate-900"
            >
              Sign out
            </button>
          </form>
        </header>

        <section className="mt-10 rounded-2xl border border-slate-800 bg-slate-900 p-8">
          <h2 className="text-2xl font-semibold">
            Welcome, {displayName}
          </h2>
          <p className="mt-3 text-slate-400">
            Authentication is working. Organization
            onboarding comes next.
          </p>
        </section>
      </div>
    </main>
  );
}
