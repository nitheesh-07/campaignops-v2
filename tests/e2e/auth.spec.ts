import { expect, test } from "@playwright/test";

test("unauthenticated users are redirected to login", async ({ page }) => {
  await page.goto("/dashboard");
  await expect(page).toHaveURL(/\/login\?next=(%2F|\/)dashboard/);
  await expect(page.getByRole("heading", { name: /sign in/i })).toBeVisible();
});

test("user can sign up, sign out, and sign in", async ({ page }) => {
  const email = "playwright-" + Date.now() + "@example.com";
  const password = "CampaignOps-Test-123!";
  const fullName = "Playwright Tester";

  await page.goto("/sign-up");
  await page.getByLabel(/full name/i).fill(fullName);
  await page.getByLabel(/email/i).fill(email);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.getByLabel(/confirm password/i).fill(password);
  await page.getByRole("button", { name: /create account|sign up/i }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await expect(
    page.getByRole("heading", {
      name: /create your organization/i,
    }),
  ).toBeVisible();

  await page.getByRole("button", { name: /sign out/i }).click();
  await expect(page).toHaveURL(/\/login/);

  await page.getByLabel(/email/i).fill(email);
  await page.getByLabel(/password/i).fill("WrongPassword-123!");
  await page.getByRole("button", { name: /sign in/i }).click();
  await expect(page.getByText(/invalid email or password/i)).toBeVisible();

  await page.getByLabel(/email/i).fill(email);
  await page.getByLabel(/password/i).fill(password);
  await page.getByRole("button", { name: /sign in/i }).click();
  await expect(page).toHaveURL(/\/onboarding/);
});
