const supabaseHealthEndpoints = [
  "http://127.0.0.1:54321/auth/v1/health",
  "http://127.0.0.1:54321/rest/v1/",
];

const wait = (milliseconds: number) =>
  new Promise((resolve) => setTimeout(resolve, milliseconds));

export default async function globalSetup() {
  const deadline = Date.now() + 60000;

  while (Date.now() < deadline) {
    try {
      const responses = await Promise.all(
        supabaseHealthEndpoints.map((endpoint) =>
          fetch(endpoint, {
            signal: AbortSignal.timeout(3000),
          }),
        ),
      );

      if (responses.every((response) => response.status < 500)) {
        return;
      }
    } catch {
      // Local Supabase may still be restarting after db:reset.
    }

    await wait(500);
  }

  throw new Error(
    "Local Supabase did not become ready within 60 seconds.",
  );
}
