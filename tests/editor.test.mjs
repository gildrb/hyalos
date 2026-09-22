import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { Editor } from '../src/editor.ts';
import { DEFAULT, preset, documentFor } from '../src/model.ts';
const text = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('editor starts without loading a GPU or any browser dependency', () => {
  const editor = new Editor();
  assert.equal(editor.status, 'idle');
  assert.deepEqual(editor.settings, DEFAULT);
  assert.equal(editor.capabilities().webgpu, false);
  editor.detach();
});
test('recipe settings and public snapshots are independently owned', () => {
  const settings = structuredClone(DEFAULT), editor = new Editor(settings);
  settings.palette.energy[0] = 0;
  const a = editor.getScene(); a.settings.palette.energy[0] = 0;
  assert.deepEqual(editor.settings, DEFAULT);
  editor.detach();
});
test('invalid typed parameter values cannot enter editor state', () => {
  const editor = new Editor();
  assert.throws(() => editor.update({ power: Infinity }));
  assert.throws(() => editor.update({ seed: 3.5 }));
  assert.deepEqual(editor.settings, DEFAULT);
  editor.detach();
});
test('undo and redo preserve selected study, not only numerical settings', () => {
  const editor = new Editor();
  editor.select('commons'); editor.update({ power: 77 });
  editor.undo(); assert.equal(editor.settings.power, preset('commons').power);
  editor.undo(); assert.equal(editor.selected, 'the-gift'); assert.deepEqual(editor.settings, DEFAULT);
  editor.redo(); assert.equal(editor.selected, 'commons');
  editor.redo(); assert.equal(editor.settings.power, 77);
  editor.detach();
});
test('continuous slider updates create one undo boundary', () => {
  const editor = new Editor();
  editor.update({ power: 10 }, false); editor.update({ power: 20 }, false); editor.commit();
  editor.undo(); assert.deepEqual(editor.settings, DEFAULT); assert.equal(editor.canUndo, false);
  editor.detach();
});
test('imported scene identifies an exact preset and preserves explicit time', () => {
  const editor = new Editor();
  editor.setScene(documentFor(preset('memory'))); assert.equal(editor.selected, 'memory');
  editor.setParameters({ time: 3.25 });
  assert.equal(editor.getScene().settings.time, 3.25); assert.equal(editor.playing, false);
  editor.detach();
});
test('GPU-less editor rejects live image export rather than returning a poster', async () => {
  const editor = new Editor();
  await assert.rejects(editor.exportPNG(64,64), /unavailable/);
  editor.detach();
});
test('export lock prevents editing scene, quality and history', () => {
  const editor = new Editor(); editor.busy = true;
  for (const fn of [() => editor.update({ power: 10 }), () => editor.select('relay'), () => editor.undo(), () => editor.redo(), () => editor.setQuality('final')]) assert.throws(fn, /export is active/);
  editor.detach();
});
test('subscriptions unsubscribe and do not lose noncommitted updates', () => {
  const editor = new Editor(); let updates = 0;
  const unsubscribe = editor.subscribe(() => updates++);
  editor.update({ power: 20 }, false); assert.equal(updates, 1);
  unsubscribe(); editor.commit(); assert.equal(updates, 1); editor.detach();
});
test('source HTML has an early charset, relative entry and independently loaded CSS', () => {
  const html = text('index.html');
  assert.match(html.slice(0,1024), /<meta charset="utf-8">/);
  assert.match(html, /href="\.\/src\/style\.css"/);
  assert.match(html, /src="\.\/src\/main\.ts"/);
  assert.doesNotMatch(html, /(?:src|href)="\//);
  assert.match(html, /id="boot-shell"/);
  assert.match(text('src/main.ts'), /--hyalos-css-loaded/);
});
test('asset references are bundled imports instead of root-absolute paths', () => {
  assert.match(text('vite.config.ts'), /base: '\.\/'/);
  assert.match(text('src/assets.ts'), /import gift from '\.\/assets\/presets\/the-gift\.png'/);
  assert.doesNotMatch(text('src/App.tsx') + text('src/components/Viewport.tsx'), /["'`]\/presets\//);
});
test('all application modules use TypeScript and UI uses Preact', () => {
  const files = readdirSync(new URL('../src/', import.meta.url), { recursive: true });
  assert.equal(files.some(file => /\.[cm]?jsx?$/.test(file)), false);
  assert.match(text('src/App.tsx'), /from 'preact'/);
  assert.match(text('src/App.tsx'), /from 'preact\/hooks'/);
  assert.doesNotMatch(text('src/App.tsx'), /innerHTML|dangerouslySetInnerHTML/);
  assert.equal(JSON.parse(text('tsconfig.json')).compilerOptions.strict, true);
});
test('GPU loading is isolated and surface compilation uses a format signature', () => {
  const source = text('src/editor.ts');
  assert.match(source, /await import\('\.\/gpu\/renderer\.ts'\)/);
  assert.doesNotMatch(source, /^import.*from 'vgpu'/m);
  assert.doesNotMatch(text('src/gpu/renderer.ts'), /post\.compile\(screen\)/);
  assert.match(text('src/gpu/renderer.ts'), /post\.compile\(\{ colors: \[screen\.format\]/);
});
