import test from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT } from '../src/model.ts';
import { renderPixels, exportSequence } from '../src/export.ts';
import { crc32, zip, addPngProject, readPngProject } from '../src/binary.ts';

const encode = s => new TextEncoder().encode(s);
// Public-domain, one-pixel PNG test fixture. No reference art is embedded in the project.
const PNG = Uint8Array.from(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jfLkAAAAASUVORK5CYII=','base64'));
test('CRC32 standard check value', () => assert.equal(crc32(encode('123456789')),0xcbf43926));
test('ZIP is deterministic and has valid CRCs, local headers and directory', async () => {
  const files=[['hello.txt','hello'],['frames/00000.txt','world']];
  const a=new Uint8Array(await zip(files).arrayBuffer()), b=new Uint8Array(await zip(files).arrayBuffer());
  assert.deepEqual(a,b); const v=new DataView(a.buffer);
  assert.equal(v.getUint32(0,true),0x04034b50); assert.equal(v.getUint32(14,true),crc32(encode('hello')));
  assert.equal(v.getUint32(a.length-22,true),0x06054b50); assert.equal(v.getUint16(a.length-12,true),2);
});
test('unsafe archive filenames are rejected', () => {
  for(const name of ['../bad','/bad','x/../../bad']) assert.throws(()=>zip([[name,'data']]));
});
test('PNG recipe embed, recover, and replace metadata', () => {
  const a=addPngProject(PNG,'{"first":1}'); assert.equal(readPngProject(a),'{"first":1}');
  const b=addPngProject(a,'{"second":2}'); assert.equal(readPngProject(b),'{"second":2}');
  assert.equal(new TextDecoder().decode(b).split('hyalos.scene').length,2);
});
test('PNG metadata checksum detects tampering', () => {
  const a=addPngProject(PNG,'{"test":1}'); const i=Buffer.from(a).indexOf('hyalos.scene'); a[i+15]^=1;
  assert.throws(()=>readPngProject(a),/checksum/i);
});
test('missing, oversized, invalid and truncated PNG metadata is rejected', () => {
  assert.throws(()=>readPngProject(PNG)); assert.throws(()=>readPngProject(new Uint8Array(50)));
  assert.throws(()=>addPngProject(PNG.subarray(0,30),'{}')); assert.throws(()=>addPngProject(PNG,'x'.repeat(65537)));
});
function gradientRenderer(hook = () => {}) {
  return { maxTexture:256, async readTile(s,w,h,t) {
    hook(s); const bytes=new Uint8Array(t.width*t.height*4);
    for(let y=0;y<t.height;y++) for(let x=0;x<t.width;x++) bytes.set([(x+t.left)%256,(y+t.top)%256,s.seed%256,255],(y*t.width+x)*4);
    return bytes;
  }};
}
test('export tiles assemble exact RGBA order without flips or seams', async () => {
  const progress=[];const result=await renderPixels(gradientRenderer(),DEFAULT,131,97,{tileSize:32,onProgress:p=>progress.push(p)});
  for(let y=0;y<97;y++) for(let x=0;x<131;x++) assert.deepEqual([...result.slice((y*131+x)*4,(y*131+x+1)*4)],[x,y,DEFAULT.seed%256,255]);
  assert.equal(progress.at(-1),1); assert.ok(progress.every((p,i)=>i===0||p>progress[i-1]));
});
test('readback snapshots are not affected by edits during export', async () => {
  const s=structuredClone(DEFAULT),seed=s.seed;
  const result=await renderPixels(gradientRenderer(()=>{s.seed=0;}),s,128,96,{tileSize:32});
  assert.ok(result.filter((_,i)=>i%4===2).every(v=>v===seed%256));
});
test('pre-cancelled export performs no GPU work', async () => {
  const c=new AbortController();c.abort();let calls=0;
  await assert.rejects(renderPixels(gradientRenderer(()=>calls++),DEFAULT,64,64,{signal:c.signal}),{name:'AbortError'});assert.equal(calls,0);
});
test('cancellation between readback and copy does not return partial export', async () => {
  const c=new AbortController();let calls=0;
  await assert.rejects(renderPixels(gradientRenderer(()=>{calls++;c.abort();}),DEFAULT,128,96,{signal:c.signal,tileSize:32}),{name:'AbortError'});assert.equal(calls,1);
});
test('invalid GPU readback is rejected', async () => {
  await assert.rejects(renderPixels({maxTexture:1024,readTile:async()=>new Uint8Array(1)},DEFAULT,64,64),/readback/);
});
test('GPU allocation constraints fail before readback', async () => {
  await assert.rejects(renderPixels({maxTexture:32},DEFAULT,64,64),/texture limit/);
});
test('sequence budgets and noninteger rates fail before encoding', async () => {
  for(const [w,h,fps,seconds] of [[3840,2160,30,1],[1920,1080,60,11],[64,64,0,1],[64,64,29.97,1],[64,64,10,0]]) {
    await assert.rejects(exportSequence({},DEFAULT,w,h,fps,seconds),/Sequences/);
  }
});
