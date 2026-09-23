import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { readPngProject } from '../../src/binary.ts';
import { parseDocument } from '../../src/model.ts';

async function preserve(name, bytes) {
  const path = test.info().outputPath(name);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, Buffer.from(bytes));
  await test.info().attach(name, { path, contentType: name.endsWith('.png') ? 'image/png' : 'application/json' });
}
test.afterEach(async ({ page }) => {
  await page.evaluate(() => window.gpuHarness?.renderer?.dispose()).catch(() => {});
});

test('actual vGPU compilation, deterministic pixels, tiling, presets, PNG metadata', async ({ page }) => {
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto('/tests/render.html');
  await page.waitForFunction(()=>window.gpuHarness?.ready || window.gpuHarness?.failed);
  // A missing real adapter is a failure, never a passing mock or a silent skip.
  expect(await page.evaluate(()=>window.gpuHarness.errors)).toEqual([]);
  expect(await page.evaluate(()=>window.gpuHarness.ready)).toBe(true);
  const adapterInfo = await page.evaluate(async () => {
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) throw new Error('GPU adapter missing during evidence capture.');
    return { vendor: adapter.info.vendor, architecture: adapter.info.architecture, device: adapter.info.device, description: adapter.info.description };
  });
  await preserve('adapter.json', JSON.stringify(adapterInfo, null, 2));
  const a=await page.evaluate(()=>window.gpuHarness.pixels());
  const b=await page.evaluate(()=>window.gpuHarness.pixels());
  expect(a).toEqual(b);
  expect(new Set(a.filter((_,i)=>i%4!==3)).size).toBeGreaterThan(30);
  const tiled=await page.evaluate(()=>window.gpuHarness.pixels('the-gift',32));
  expect(Math.max(...a.map((v,i)=>Math.abs(v-tiled[i])))).toBeLessThanOrEqual(1);
  for(const id of ['commons','hearth','relay','memory','ignition']) {
    const c=await page.evaluate(id=>window.gpuHarness.pixels(id),id);expect(c).not.toEqual(a);
  }
  const png=Uint8Array.from(await page.evaluate(()=>window.gpuHarness.png()));
  const doc=parseDocument(readPngProject(png));expect(doc.settings.seed).toBe(240915);expect(doc.shaderHash).toMatch(/^[a-f0-9]{64}$/);
  expect(new DataView(png.buffer).getUint32(16)).toBe(192);expect(new DataView(png.buffer).getUint32(20)).toBe(108);
  await preserve('the-gift-webgpu.png', png);
  await page.evaluate(()=>window.gpuHarness.renderer.settled());
  expect(await page.evaluate(()=>window.gpuHarness.errors)).toEqual([]);expect(errors).toEqual([]);
});

test('editor controls, export and manual-render restore use the same live renderer', async ({ page }) => {
  await page.goto('/');await page.waitForFunction(()=>!!window.hyalos);
  const ready = await page.evaluate(()=>window.hyalos.ready);
  expect(ready, await page.locator('#gpu-error').innerText()).toBe(true);
  await page.locator('[data-preset="commons"]').click();expect(await page.evaluate(()=>window.hyalos.getScene().settings.scene)).toBe(1);
  await page.locator('[data-tab="light"]').click();await page.locator('[data-value="power"]').fill('77');await page.locator('[data-value="power"]').press('Tab');
  expect(await page.evaluate(()=>window.hyalos.getScene().settings.power)).toBe(77);
  await page.locator('#undo').click();expect(await page.evaluate(()=>window.hyalos.getScene().settings.power)).not.toBe(77);
  await page.locator('#redo').click();expect(await page.evaluate(()=>window.hyalos.getScene().settings.power)).toBe(77);
  const exported = await page.evaluate(async () => Array.from(new Uint8Array(await (await window.hyalos.exportPNG(192,108)).arrayBuffer())));
  const recipe = parseDocument(readPngProject(Uint8Array.from(exported)));
  expect(recipe.settings.power).toBe(77);expect(recipe.settings.scene).toBe(1);
  await preserve('commons-editor-webgpu.png', exported);
  await page.evaluate(()=>window.hyalos.setParameters({time:3.25}));await page.waitForTimeout(350);
  await page.reload();await page.waitForFunction(()=>!!window.hyalos);
  expect(await page.evaluate(()=>window.hyalos.ready), await page.locator('#gpu-error').innerText()).toBe(true);
  expect(await page.evaluate(()=>window.hyalos.getScene().settings.time)).toBe(3.25);
  await expect(page.locator('#poster')).toBeVisible();
  await expect(page.locator('#canvas')).toHaveAttribute('aria-hidden', 'true');
  await page.locator('#render-preview').click();
  await expect(page.locator('#poster')).toBeHidden({ timeout: 120000 });
  await expect(page.locator('#canvas')).toHaveAttribute('aria-hidden', 'false');
  await expect(page.locator('#render-preview')).toBeEnabled();
  await page.screenshot({ path: test.info().outputPath('editor-live.png') });
});
