import { expect, type Page, test } from "@playwright/test";

const SERVER_ACTION_TIMEOUT = 30_000;

async function createCampaignWorkspace(
  page: Page,
  label: string,
) {
  const uniqueId = `${Date.now()}-${Math.floor(Math.random() * 10000)}`;
  const clientName = `${label} Client ${uniqueId}`;

  await page.goto("/sign-up");

  await page.getByLabel(/full name/i).fill(`${label} Owner`);
  await page
    .getByLabel(/email/i)
    .fill(`${label.toLowerCase()}-${uniqueId}@example.com`);
  await page
    .getByLabel("Password", { exact: true })
    .fill("CampaignOps-Test-123!");
  await page
    .getByLabel(/confirm password/i)
    .fill("CampaignOps-Test-123!");

  await page
    .getByRole("button", { name: /create account/i })
    .click();

  await expect(page).toHaveURL(/\/onboarding/, {
    timeout: SERVER_ACTION_TIMEOUT,
  });

  await page
    .getByLabel(/organization name/i)
    .fill(`${label} Workspace ${uniqueId}`);

  await page
    .getByLabel(/organization slug/i)
    .fill(`${label.toLowerCase()}-${uniqueId}`);

  await page
    .getByRole("button", { name: /create organization/i })
    .click();

  await expect(page).toHaveURL(/\/dashboard/, {
    timeout: SERVER_ACTION_TIMEOUT,
  });

  await page.goto("/clients/new");

  const clientNameInput = page.getByLabel(/client name/i);
  await clientNameInput.fill(clientName);
  await expect(clientNameInput).toHaveValue(clientName);

  await page
    .getByRole("button", { name: /create client/i })
    .click();

  await expect(page).toHaveURL(/\/clients\/[0-9a-f-]+/i, {
    timeout: SERVER_ACTION_TIMEOUT,
  });

  return { clientName };
}

async function fillCampaignForm(
  page: Page,
  campaignName: string,
  clientName: string,
  startDate = "2026-08-10",
  dueDate = "2026-08-20",
) {
  await page.getByLabel(/campaign name/i).fill(campaignName);
  await page.getByLabel(/description/i).fill("Campaign brief");
  await page.getByLabel(/start date/i).fill(startDate);
  await page.getByLabel(/due date/i).fill(dueDate);

  // Select last to prevent hydration from resetting the dropdown.
  const clientSelect = page.getByLabel("Client");

  await clientSelect.selectOption({
    label: clientName,
  });

  await expect(
    clientSelect.locator("option:checked"),
  ).toHaveText(clientName);
}

test("owner creates, edits, filters, and advances a campaign", async ({
  page,
}) => {
  const uniqueId = Date.now();
  const campaignName = `Launch ${uniqueId}`;
  const updatedName = `Launch Updated ${uniqueId}`;

  const { clientName } = await createCampaignWorkspace(
    page,
    "CampaignFlow",
  );

  await page.goto("/campaigns");

  await page
    .getByRole("link", { name: /add campaign/i })
    .click();

  await fillCampaignForm(
    page,
    campaignName,
    clientName,
  );

  await page
    .getByRole("button", { name: /create campaign/i })
    .click();

  await expect(page).toHaveURL(
    /\/campaigns\/[0-9a-f-]+/i,
    {
      timeout: SERVER_ACTION_TIMEOUT,
    },
  );

  await expect(page.getByRole("status")).toContainText(
    /created successfully/i,
  );

  await page
    .getByLabel(/campaign name/i)
    .fill(updatedName);

  await page
    .getByRole("button", { name: /save campaign/i })
    .click();

  await expect(page.getByRole("status")).toContainText(
    /updated successfully/i,
  );

  await page
    .getByRole("button", { name: /move to active/i })
    .click();

  await expect(page.getByRole("status")).toContainText(
    /status updated successfully/i,
  );

  await expect(
    page.getByText("Active", { exact: true }),
  ).toBeVisible();

  await page.goto("/campaigns");

  await page
    .getByLabel(/campaign status/i)
    .selectOption("active");

  await page
    .getByLabel("Client")
    .selectOption({ label: clientName });

  await page
    .getByRole("button", { name: /apply filters/i })
    .click();

  await expect(page).toHaveURL(/status=active/, {
    timeout: SERVER_ACTION_TIMEOUT,
  });

  await expect(
    page.getByText(updatedName),
  ).toBeVisible();
});

test("campaign date and duplicate-name validation are enforced", async ({
  page,
}) => {
  const campaignName = `Validation ${Date.now()}`;

  const { clientName } = await createCampaignWorkspace(
    page,
    "CampaignValidation",
  );

  await page.goto("/campaigns/new");

  await fillCampaignForm(
    page,
    campaignName,
    clientName,
    "2026-08-20",
    "2026-08-10",
  );

  await page
    .getByRole("button", { name: /create campaign/i })
    .click();

  await expect(
    page.getByText(/due date cannot be earlier/i),
  ).toBeVisible({
    timeout: SERVER_ACTION_TIMEOUT,
  });

  await page.goto("/campaigns/new");

  await fillCampaignForm(
    page,
    campaignName,
    clientName,
  );

  await page
    .getByRole("button", { name: /create campaign/i })
    .click();

  await expect(page).toHaveURL(
    /\/campaigns\/[0-9a-f-]+/i,
    {
      timeout: SERVER_ACTION_TIMEOUT,
    },
  );

  await page.goto("/campaigns/new");

  await fillCampaignForm(
    page,
    campaignName.toUpperCase(),
    clientName,
  );

  await page
    .getByRole("button", { name: /create campaign/i })
    .click();

  await expect(
    page.getByText(/already exists/i),
  ).toBeVisible({
    timeout: SERVER_ACTION_TIMEOUT,
  });
});