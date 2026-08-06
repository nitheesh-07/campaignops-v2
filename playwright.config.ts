import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: "http://127.0.0.1:3001",
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: "npm run dev -- --webpack --port 3001",
    url: "http://127.0.0.1:3001/login",
    reuseExistingServer: true,
    timeout: 120000,
    env: {
      ...process.env,
      NEXT_PUBLIC_SITE_URL: "http://127.0.0.1:3001",
    },
  },
});
