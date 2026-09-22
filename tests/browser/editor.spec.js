import { test, expect } from '@playwright/test';
import { readPngProject } from '../../src/binary.js';
import { parseDocument } from '../../src/model.js';

test('actual vGPU compilation, deterministic pixels, tiling, presets, PNG metadata', async ({ page }) => {
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto('/tests/render.html');
  await page.waitForFunction(()=>window.gpuHarness?.ready || window.gpuHarness?.failed);
  // This must fail, not silently pass or skip, when no real GPU backend exists.
  expect(await page.evaluate(()=>window.gpuHarness.errors)).toEqual([]);
  expect(await page.evaluate(()=>window.gpuHarness.ready)).toBe(true);
  const a=await page.evaluate(()=>window.gpuHarness.pixels());
  const b=await page.evaluate(()=>window.gpuHarness.pixels());
  expect(a).toEqual(b);
  expect(new Set(a.filter((_,i)=>i%4!==3)).size).toBeGreaterThan(30);
  const tiled=await page.evaluate(()=>window.gpuHarness.pixels('the-gift',32));
  // Floating texture-coordinate rounding can differ by one encoded 8-bit value.
  expect(Math.max(...a.map((v,i)=>Math.abs(v-tiled[i])))).toBeLessThanOrEqual(1);
  for(const id of ['commons','hearth','relay','memory','ignition']) {
    const c=await page.evaluate(id=>window.gpuHarness.pixels(id),id);expect(c).not.toEqual(a);
  }
  const png=Uint8Array.from(await page.evaluate(()=>window.gpuHarness.png()));
  const doc=parseDocument(readPngProject(png));expect(doc.settings.seed).toBe(240915);expect(doc.shaderHash).toMatch(/^[a-f0-9]{64}$/);
  expect(new DataView(png.buffer).getUint32(16)).toBe(192);expect(new DataView(png.buffer).getUint32(20)).toBe(108);
  await page.evaluate(()=>window.gpuHarness.renderer.settled());
  expect(await page.evaluate(()=>window.gpuHarness.errors)).toEqual([]);expect(errors).toEqual([]);
});

test('editor controls, export and paused restore use the same live renderer', async ({ page }) => {
  await page.goto('/');expect(await page.evaluate(()=>window.hyalos.ready)).toBe(true);
  await page.locator('[data-preset="commons"]').click();expect(await page.evaluate(()=>window.hyalos.getScene().settings.scene)).toBe(1);
  await page.locator('[data-tab="light"]').click();await page.locator('[data-value="power"]').fill('77');await page.locator('[data-value="power"]').press('Tab');
  expect(await page.evaluate(()=>window.hyalos.getScene().settings.power)).toBe(77);
  await page.locator('#undo').click();expect(await page.evaluate(()=>window.hyalos.getScene().settings.power)).not.toBe(77);
  await page.locator('#redo').click();expect(await page.evaluate(()=>window.hyalos.getScene().settings.power)).toBe(77);
  await page.evaluate(()=>window.hyalos.setParameters({time:3.25}));await page.waitForTimeout(350);
  await page.reload();expect(await page.evaluate(()=>window.hyalos.ready)).toBe(true);
  expect(await page.evaluate(()=>window.hyalos.getScene().settings.time)).toBe(3.25);
  await expect(page.locator('#play')).toHaveAttribute('aria-label','Play animation');
});

test('missing WebGPU cannot produce a pretend export', async ({ page }) => {
  await page.addInitScript(()=>Object.defineProperty(navigator,'gpu',{value:undefined,configurable:true}));
  await page.goto('/');expect(await page.evaluate(()=>window.hyalos.ready)).toBe(false);
  await expect(page.locator('#gpu-error')).toBeVisible();expect(await page.evaluate(()=>window.hyalos.capabilities().webgpu)).toBe(false);
  await expect(page.locator('#play')).toBeDisabled();
  const error=await page.evaluate(async()=>{try{await window.hyalos.exportPNG();return '';}catch(e){return e.message;}});expect(error).toMatch(/unavailable/i);
  for(const width of [800,390]) {
    await page.setViewportSize({width,height:850});await page.locator('.mobile-toolbar [data-panel="presets"]').click();await expect(page.locator('.library')).toBeVisible();
    expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThanOrEqual(width);
    await page.locator('.mobile-toolbar [data-panel="presets"]').click();
  }
});
