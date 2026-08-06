import { NextResponse } from "next/server";

import { createClient } from "@/lib/supabase/server";

function safeInternalPath(value: string | null) {
  if (
    !value ||
    !value.startsWith("/") ||
    value.startsWith("//")
  ) {
    return "/dashboard";
  }

  return value;
}

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const nextPath = safeInternalPath(
    requestUrl.searchParams.get("next"),
  );

  if (code) {
    const supabase = await createClient();
    const { error } =
      await supabase.auth.exchangeCodeForSession(code);

    if (!error) {
      return NextResponse.redirect(
        new URL(nextPath, requestUrl.origin),
      );
    }
  }

  const loginUrl = new URL(
    "/login",
    requestUrl.origin,
  );

  loginUrl.searchParams.set(
    "error",
    "Unable to confirm authentication. Try signing in again.",
  );

  return NextResponse.redirect(loginUrl);
}
