import { expect, type Page, test } from "@playwright/test";

async function createOwnerWorkspace(
  page: Page,
  label: string,
) {
  const uniqueId = `${Date.now()}-${Math.floor(Math.random() * 10000)}`;
  const password = "CampaignOps-Test-123!";
  const organizationName = `${label} Workspace ${uniqueId}`;

  await page.goto("/sign-up");
  await page.getByLabel(/full name/i).fill(`${label} Owner`);
  await page
    .getByLabel(/email/i)
    .fill(`${label.toLowerCase()}-${uniqueId}@example.com`);
  await page
    .getByLabel("Password", { exact: true })
    .fill(password);
  await page.getByLabel(/confirm password/i).fill(password);
  await page
    .getByRole("button", { name: /create account/i })
    .click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page
    .getByLabel(/organization name/i)
    .fill(organizationName);
  await page
    .getByLabel(/organization slug/i)
    .fill(`${label.toLowerCase()}-${uniqueId}`);
  await page
    .getByRole("button", { name: /create organization/i })
    .click();

  await expect(page).toHaveURL(/\/dashboard/);
}

test("owner creates, edits, archives, and restores a client", async ({
  page,
}) => {
  const uniqueId = Date.now();
  const clientName = `Atlas ${uniqueId}`;
  const updatedName = `Atlas Updated ${uniqueId}`;

  await createOwnerWorkspace(page, "ClientFlow");
  await page
    .getByRole("link", { name: /manage clients/i })
    .click();
  await expect(page).toHaveURL(/\/clients$/);

  await page.getByRole("link", { name: /add client/i }).click();
  await page.getByLabel(/client name/i).fill(clientName);
  await page.getByLabel(/contact name/i).fill("Avery Stone");
  await page
    .getByLabel(/contact email/i)
    .fill("avery@example.com");
  await page.getByLabel(/notes/i).fill("Priority client");
  await page
    .getByRole("button", { name: /create client/i })
    .click();

  await expect(page).toHaveURL(/\/clients\/[0-9a-f-]+/i);
  await expect(page.getByRole("status")).toContainText(
    /created successfully/i,
  );

  await page.getByLabel(/client name/i).fill(updatedName);
  await page
    .getByRole("button", { name: /save client/i })
    .click();
  await expect(page.getByRole("status")).toContainText(
    /updated successfully/i,
  );
  await expect(
    page.getByRole("heading", { name: updatedName }),
  ).toBeVisible();

  await page
    .getByRole("button", { name: /archive client/i })
    .click();
  await expect(page).toHaveURL(/\/clients\?status=archived/);
  await expect(page.getByText(updatedName)).toBeVisible();

  await page
    .getByRole("button", { name: /restore client/i })
    .click();
  await expect(page).toHaveURL(/\/clients\?message=/);
  await expect(page.getByText(updatedName)).toBeVisible();
});

test("duplicate client names are rejected per organization", async ({
  page,
}) => {
  const clientName = `Duplicate ${Date.now()}`;

  await createOwnerWorkspace(page, "DuplicateFlow");
  await page.goto("/clients/new");
  await page.getByLabel(/client name/i).fill(clientName);
  await page
    .getByRole("button", { name: /create client/i })
    .click();
  await expect(page).toHaveURL(/\/clients\/[0-9a-f-]+/i);

  await page.goto("/clients/new");
  await page.getByLabel(/client name/i).fill(clientName.toUpperCase());
  await page
    .getByRole("button", { name: /create client/i })
    .click();

  await expect(page).toHaveURL(/\/clients\/new\?error=/);
  await expect(page.getByRole("alert")).toContainText(
    /already exists/i,
  );
});
