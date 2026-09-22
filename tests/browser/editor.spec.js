import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  // These tests qualify the real Preact UI and built assets, not GPU rendering.
  await page.addInitScript(() => Object.defineProperty(navigator, 'gpu', { value: undefined, configurable: true }));
});

test('production HTML loads CSS, Preact, UTF-8 and all images at either base path', async ({ page }) => {
  const failed = [], errors = [];
  page.on('requestfailed', request => failed.push(request.url()));
  page.on('pageerror', error => errors.push(String(error)));
  const response = await page.goto('./');
  expect(response.headers()['content-type']).toMatch(/charset=utf-8/i);
  const html = await response.text();
  expect(html).not.toContain('./src/main.ts');
  await page.waitForFunction(() => !!window.hyalos);
  expect(await page.evaluate(() => window.hyalos.ready)).toBe(false);
  await expect(page.locator('.topbar')).toBeVisible();
  await expect(page.locator('#boot-shell')).toBeHidden();
  await expect(page.locator('#gpu-error')).toBeVisible();
  expect(await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--hyalos-css-loaded').trim())).toBe('1');
  expect(await page.locator('.workspace').evaluate(node => getComputedStyle(node).display)).toBe('grid');
  expect(await page.evaluate(() => document.characterSet)).toBe('UTF-8');
  await page.waitForFunction(() => Array.from(document.images).every(image => image.complete && image.naturalWidth > 0));
  expect(await page.locator('.preset-card').count()).toBe(6);
  expect(errors).toEqual([]); expect(failed).toEqual([]);
});

test('controls, undo, redo and recipe export remain usable without a GPU', async ({ page }) => {
  await page.goto('./'); await page.waitForFunction(() => !!window.hyalos);
  await page.locator('[data-preset="commons"]').click();
  expect(await page.evaluate(() => window.hyalos.getScene().settings.scene)).toBe(1);
  await page.getByRole('tab', { name: 'Light', exact: true }).click();
  await page.locator('[data-value="power"]').fill('77');
  await page.locator('[data-value="power"]').press('Tab');
  expect(await page.evaluate(() => window.hyalos.getScene().settings.power)).toBe(77);
  await page.locator('#undo').click();
  expect(await page.evaluate(() => window.hyalos.getScene().settings.power)).not.toBe(77);
  await page.locator('#redo').click();
  expect(await page.evaluate(() => window.hyalos.getScene().settings.power)).toBe(77);
  await page.locator('#open-export').click();
  await expect(page.locator('#export-submit')).toBeDisabled();
  await page.locator('#export-format').selectOption('project');
  await expect(page.locator('#export-submit')).toBeEnabled();
  const download = page.waitForEvent('download');
  await page.locator('#export-submit').click();
  expect((await download).suggestedFilename()).toMatch(/\.hyalos\.json$/);
  await page.evaluate(() => window.hyalos.setParameters({ time: 3.25 }));
  await page.waitForTimeout(350);
  await page.reload(); await page.waitForFunction(() => !!window.hyalos);
  expect(await page.evaluate(() => window.hyalos.getScene().settings.time)).toBe(3.25);
  await expect(page.locator('#play')).toBeDisabled();
});

test('responsive library drawer remains accessible without horizontal overflow', async ({ page }) => {
  await page.goto('./'); await page.waitForFunction(() => !!window.hyalos);
  for (const width of [800, 390]) {
    await page.setViewportSize({ width, height: 850 });
    await page.locator('.mobile-toolbar [data-panel="presets"]').click();
    await expect(page.locator('.library')).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(width);
    await page.locator('.mobile-toolbar [data-panel="presets"]').click();
  }
});

test('blocked stylesheet produces a readable diagnostic instead of unstyled editor HTML', async ({ page }) => {
  await page.route(/\.css(?:\?.*)?$/, route => route.abort());
  await page.goto('./');
  await expect(page.locator('#startup-detail')).toContainText('stylesheet did not load');
  await expect(page.locator('#boot-shell')).toBeVisible();
  await expect(page.locator('.topbar')).toHaveCount(0);
});

test('failed UI chunk produces a visible boot error', async ({ page }) => {
  await page.route(/\/assets\/App-[^/]+\.js(?:\?.*)?$/, route => route.abort());
  await page.goto('./');
  await expect(page.locator('#startup-detail')).not.toHaveText('Loading TypeScript and Preact application modules.');
  await expect(page.locator('#boot-shell')).toBeVisible();
});
