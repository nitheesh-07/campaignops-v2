import type { ReactNode } from "react";

export default function AuthenticationLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950 px-4 py-12 text-slate-100">
      {children}
    </main>
  );
}
