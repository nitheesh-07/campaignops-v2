import { expect, test } from "@playwright/test";

test("user creates an organization during onboarding", async ({
  page,
}) => {
  const uniqueId = Date.now();
  const email = `organization-${uniqueId}@example.com`;
  const password = "CampaignOps-Test-123!";
  const fullName = "Organization Owner";
  const organizationName = `Northstar ${uniqueId}`;
  const organizationSlug = `northstar-${uniqueId}`;

  await page.goto("/sign-up");
  await page.getByLabel(/full name/i).fill(fullName);
  await page.getByLabel(/email/i).fill(email);
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
    .fill(organizationSlug);
  await page
    .getByRole("button", { name: /create organization/i })
    .click();

  await expect(page).toHaveURL(/\/dashboard/);
  await expect(
    page.getByRole("heading", { name: organizationName }),
  ).toBeVisible();
  await expect(page.getByText(organizationSlug)).toBeVisible();
  await expect(page.getByText(fullName)).toBeVisible();

  const unauthorizedOrganizationId =
    "99999999-9999-4999-8999-999999999999";

  await page.locator("#organizationId").evaluate(
    (selectElement, unauthorizedId) => {
      const option = document.createElement("option");

      option.value = unauthorizedId;
      option.textContent = "Unauthorized organization";
      selectElement.append(option);
    },
    unauthorizedOrganizationId,
  );

  await page
    .locator("#organizationId")
    .selectOption(unauthorizedOrganizationId);
  await page
    .getByRole("button", { name: /switch/i })
    .click();

  await expect(page.getByRole("alert")).toContainText(
    /do not have access/i,
  );
  await expect(
    page.getByRole("heading", { name: organizationName }),
  ).toBeVisible();
});
