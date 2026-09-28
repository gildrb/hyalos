import { test } from 'vite-plus/test';
import assert from 'node:assert/strict';
import { DEFAULT, PRESETS, RANGES, preset, validateSettings, documentFor, parseDocument, nextSeed, loopPhase, validateExport, exportTiles, History } from '../src/model.ts';
import { oklchToLinear, gamutMap } from '../src/color.ts';
import { uniforms } from '../src/gpu/uniforms.ts';

for (const p of PRESETS) test(`preset ${p.id}: complete, valid and independent`, () => {
  const a = preset(p.id), b = preset(p.id);
  assert.deepEqual(validateSettings(a), a); a.palette.energy[0] = 0;
  assert.notDeepEqual(a, b); assert.deepEqual(preset(p.id), b);
});
test('schema includes every numeric setting', () => {
  assert.deepEqual(Object.keys(DEFAULT).filter(k => k !== 'palette').sort(), Object.keys(RANGES).sort());
});
test('project JSON round-trips exactly', () => {
  const doc = documentFor(DEFAULT, 'abc'); assert.deepEqual(parseDocument(JSON.stringify(doc)), doc);
});
for (const bad of [null, [], {}, '', 1, { ...DEFAULT, seed: 1.4 }, { ...DEFAULT, power: NaN }, { ...DEFAULT, time: Infinity }, { ...DEFAULT, zoom: 0 }, { ...DEFAULT, palette: { energy: [0, 0, 0] } }]) test(`invalid settings rejected ${JSON.stringify(bad).slice(0, 50)}`, () => assert.throws(() => validateSettings(bad)));
test('unknown properties cannot pollute restored settings', () => {
  const source = JSON.parse(JSON.stringify(DEFAULT).replace('"seed":', '"__proto__":{"polluted":true},"seed":'));
  assert.deepEqual(validateSettings(source), DEFAULT); assert.equal({}.polluted, undefined);
});
for (const [key, [min, max, step]] of Object.entries(RANGES)) test(`parameter bounds: ${key}`, () => {
  assert.equal(validateSettings({ ...DEFAULT, [key]: min })[key], min);
  assert.equal(validateSettings({ ...DEFAULT, [key]: max })[key], max);
  assert.throws(() => validateSettings({ ...DEFAULT, [key]: min - step }));
  assert.throws(() => validateSettings({ ...DEFAULT, [key]: max + step }));
});
test('recipe parser rejects unknown engine, version, null and oversized data', () => {
  const doc = documentFor(DEFAULT);
  for (const value of [{ ...doc, version: 2 }, { ...doc, engine: 'different' }, null, []]) assert.throws(() => parseDocument(JSON.stringify(value)));
  assert.throws(() => parseDocument(' '.repeat(65537))); assert.throws(() => parseDocument(null));
});
test('seed sequence is repeatable, non-constant and within exact f32 integer range', () => {
  const sequence = () => { let n = 240915; return Array.from({ length: 1000 }, () => n = nextSeed(n)); };
  const a = sequence(); assert.deepEqual(a, sequence()); assert.equal(new Set(a).size, 1000);
  assert.ok(a.every(v => Number.isInteger(v) && v >= 0 && v < 16777216));
});
test('explicit time makes animation periodic', () => {
  for (const t of [0, 0.5, 2, 4.5]) assert.ok(Math.abs(loopPhase(t, 12) - loopPhase(t + 12, 12)) < 1e-12);
});
test('history is immutable and undo/redo keeps exact palette and time', () => {
  const h = new History(DEFAULT), p = preset('ignition'); h.commit(p); p.palette.energy[0] = 0;
  assert.deepEqual(h.undo(), DEFAULT); assert.deepEqual(h.redo(), preset('ignition'));
  h.undo(); h.commit(preset('relay')); assert.equal(h.future.length, 0);
  const empty = new History(DEFAULT), c = empty.undo(); c.seed = 0; assert.equal(empty.current.seed, DEFAULT.seed);
});
test('history bounds retained operations', () => { const h = new History(DEFAULT); for (let i = 0; i < 100; i++) h.commit({ ...DEFAULT, seed: i }); assert.equal(h.past.length, 80); });
for (const dimensions of [[1920,1080], [3840,2160], [7680,4320], [8192,4096], [64,64]]) test(`export allows ${dimensions}`, () => validateExport(...dimensions));
for (const dimensions of [[8192,8192],[0,1080],[8193,64],[1920.5,1080],[Infinity,64],[64,NaN]]) test(`export rejects ${dimensions}`, () => assert.throws(() => validateExport(...dimensions)));
test('tiles cover every pixel once and include optical halo', () => {
  for (const [w,h,tile,halo] of [[131,97,32,7],[192,192,64,40],[65,64,100,3]]) {
    const coverage = new Uint8Array(w*h);
    for (const p of exportTiles(w,h,tile,halo)) {
      assert.ok(p.left >= 0 && p.top >= 0 && p.left+p.width <= w && p.top+p.height <= h);
      assert.equal(p.left, Math.max(0,p.x-halo)); assert.equal(p.top, Math.max(0,p.y-halo));
      for(let y=p.y;y<p.y+p.h;y++) for(let x=p.x;x<p.x+p.w;x++) coverage[y*w+x]++;
    }
    assert.ok(coverage.every(n=>n===1));
  }
});
test('invalid tiling inputs fail explicitly', () => { assert.throws(()=>[...exportTiles(128,128,0)]); assert.throws(()=>[...exportTiles(128,128,32,-1)]); });
test('OKLCH conversion black, white, neutral and hue periodicity', () => {
  assert.deepEqual(oklchToLinear([0,0,0]), [0,0,0]);
  assert.ok(oklchToLinear([1,0,0]).every(n=>Math.abs(n-1)<1e-6));
  assert.ok(oklchToLinear([0.5,0,0]).every(n=>Math.abs(n-0.125)<1e-6));
  const a=oklchToLinear([0.6,0.1,0]), b=oklchToLinear([0.6,0.1,360]);
  assert.ok(a.every((v,i)=>Math.abs(v-b[i])<1e-12));
});
test('chroma reduction maps authored colors into display gamut', () => {
  for(let l=0;l<=1;l+=0.1) for(let h=0;h<360;h+=15) {
    const c=gamutMap([l,0.4,h]); assert.ok(c.every(v=>Number.isFinite(v)&&v>=0&&v<=1));
  }
});
test('uniform packing matches 16 vec4 slots and remains independent', () => {
  const tile={left:0,top:0,width:640,height:360};
  for(const p of PRESETS) {
    const u=uniforms(preset(p.id),640,360,tile);
    assert.equal(Object.keys(u).length,16); assert.ok(Object.values(u).every(a=>a.length===4&&a.every(Number.isFinite)));
    assert.deepEqual(u,uniforms(preset(p.id),640,360,tile));
  }
});
