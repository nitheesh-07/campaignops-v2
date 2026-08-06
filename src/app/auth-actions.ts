"use server";

import { redirect } from "next/navigation";

import { siteUrl } from "@/lib/supabase/config";
import { createClient } from "@/lib/supabase/server";

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function readText(
  formData: FormData,
  field: string,
) {
  const value = formData.get(field);

  return typeof value === "string"
    ? value.trim()
    : "";
}

function safeInternalPath(value: string) {
  if (
    !value.startsWith("/") ||
    value.startsWith("//")
  ) {
    return "/dashboard";
  }

  return value;
}

function redirectToForm(
  pathname: string,
  values: Record<string, string>,
): never {
  const parameters = new URLSearchParams(values);

  redirect(`${pathname}?${parameters.toString()}`);
}

export async function signIn(
  formData: FormData,
) {
  const email = readText(formData, "email").toLowerCase();
  const password = readText(formData, "password");
  const nextPath = safeInternalPath(
    readText(formData, "next"),
  );

  if (
    !emailPattern.test(email) ||
    email.length > 320
  ) {
    redirectToForm("/login", {
      error: "Enter a valid email address.",
      next: nextPath,
    });
  }

  if (!password) {
    redirectToForm("/login", {
      error: "Enter your password.",
      next: nextPath,
    });
  }

  const supabase = await createClient();

  const { error } =
    await supabase.auth.signInWithPassword({
      email,
      password,
    });

  if (error) {
    redirectToForm("/login", {
      error: "Invalid email or password.",
      next: nextPath,
    });
  }

  redirect(nextPath);
}

export async function signUp(
  formData: FormData,
) {
  const fullName = readText(formData, "fullName");
  const email = readText(formData, "email").toLowerCase();
  const password = readText(formData, "password");
  const confirmation = readText(
    formData,
    "passwordConfirmation",
  );

  if (
    fullName.length < 2 ||
    fullName.length > 120
  ) {
    redirectToForm("/sign-up", {
      error: "Name must contain 2 to 120 characters.",
    });
  }

  if (
    !emailPattern.test(email) ||
    email.length > 320
  ) {
    redirectToForm("/sign-up", {
      error: "Enter a valid email address.",
    });
  }

  if (
    password.length < 8 ||
    password.length > 72
  ) {
    redirectToForm("/sign-up", {
      error: "Password must contain 8 to 72 characters.",
    });
  }

  if (password !== confirmation) {
    redirectToForm("/sign-up", {
      error: "Passwords do not match.",
    });
  }

  const supabase = await createClient();

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: fullName,
      },
      emailRedirectTo:
        `${siteUrl}/auth/callback?next=/dashboard`,
    },
  });

  if (error) {
    const message = error.message
      .toLowerCase()
      .includes("already registered")
      ? "An account with this email already exists."
      : "Account creation failed. Please try again.";

    redirectToForm("/sign-up", {
      error: message,
    });
  }

  if (data.session) {
    redirect("/dashboard");
  }

  redirectToForm("/login", {
    message:
      "Account created. Check your email to confirm it.",
  });
}

export async function signOut() {
  const supabase = await createClient();

  await supabase.auth.signOut();

  redirectToForm("/login", {
    message: "You have signed out.",
  });
}
