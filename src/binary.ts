export type ZipEntry = [string, string | Uint8Array];
const encoder = new TextEncoder();
const decoder = new TextDecoder('utf-8', { fatal: true });
const table = Uint32Array.from({ length: 256 }, (_, i) => {
  let c = i; for (let b = 0; b < 8; b++) c = (c & 1) ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
export function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (const b of bytes) crc = table[(crc ^ b) & 255] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}
export function concat(parts: readonly Uint8Array[]): Uint8Array {
  const result = new Uint8Array(parts.reduce((n, b) => n + b.length, 0));
  let offset = 0; for (const bytes of parts) { result.set(bytes, offset); offset += bytes.length; }
  return result;
}
// Store-only ZIP. Fixed DOS timestamp makes archive metadata deterministic.
export function zip(files: readonly ZipEntry[]): Blob {
  const local: Uint8Array[] = [], central: Uint8Array[] = []; let offset = 0, count = 0;
  for (const [path, contents] of files) {
    const name = encoder.encode(path), data = typeof contents === 'string' ? encoder.encode(contents) : contents;
    if (path.includes('..') || /[\\:\x00]/.test(path) || path.startsWith('/') || name.length > 1024) throw new Error('Unsafe ZIP path.');
    const crc = crc32(data), header = new Uint8Array(30), h = new DataView(header.buffer);
    h.setUint32(0, 0x04034b50, true); h.setUint16(4, 20, true); h.setUint16(6, 0x0800, true);
    h.setUint16(12, 33, true); h.setUint32(14, crc, true); h.setUint32(18, data.length, true); h.setUint32(22, data.length, true); h.setUint16(26, name.length, true);
    local.push(header, name, data);
    const entry = new Uint8Array(46), e = new DataView(entry.buffer);
    e.setUint32(0, 0x02014b50, true); e.setUint16(4, 20, true); e.setUint16(6, 20, true); e.setUint16(8, 0x0800, true); e.setUint16(14, 33, true);
    e.setUint32(16, crc, true); e.setUint32(20, data.length, true); e.setUint32(24, data.length, true); e.setUint16(28, name.length, true); e.setUint32(42, offset, true);
    central.push(entry, name); offset += header.length + name.length + data.length; count++;
    if (offset > 256 * 1024 * 1024 || count > 1802) throw new Error('Archive exceeds the 256 MiB or 1802-file budget.');
  }
  const end = new Uint8Array(22), e = new DataView(end.buffer);
  e.setUint32(0, 0x06054b50, true); e.setUint16(8, count, true); e.setUint16(10, count, true);
  e.setUint32(12, central.reduce((n, b) => n + b.length, 0), true); e.setUint32(16, offset, true);
  return new Blob([...local, ...central, end].map(part => new Uint8Array(part).buffer), { type: 'application/zip' });
}
const PNG_SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10];
function* pngChunks(bytes: Uint8Array) {
  if (bytes.length < 20 || !PNG_SIGNATURE.every((v, i) => bytes[i] === v)) throw new Error('Not a PNG file.');
  const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  for (let p = 8; p + 12 <= bytes.length;) {
    const n = v.getUint32(p), end = p + n + 12;
    if (end > bytes.length || n > 64 * 1024 * 1024) throw new Error('Malformed PNG chunk.');
    const type = decoder.decode(bytes.subarray(p + 4, p + 8));
    yield { type, start: p, end, data: bytes.subarray(p + 8, p + 8 + n), crc: v.getUint32(end - 4) };
    p = end; if (type === 'IEND') return;
  }
  throw new Error('Truncated PNG.');
}
export function addPngProject(bytes: Uint8Array, json: string): Uint8Array {
  if (encoder.encode(json).length > 65536) throw new Error('Project metadata too large.');
  const payload = encoder.encode(`exo.scene\0${json}`), tag = encoder.encode('tEXt');
  const chunk = new Uint8Array(payload.length + 12), view = new DataView(chunk.buffer);
  view.setUint32(0, payload.length); chunk.set(tag, 4); chunk.set(payload, 8);
  view.setUint32(chunk.length - 4, crc32(chunk.subarray(4, -4)));
  const parts = [bytes.subarray(0, 8)];
  for (const entry of pngChunks(bytes)) {
    if (entry.type === 'IEND') parts.push(chunk);
    if (entry.type === 'tEXt' && decoder.decode(entry.data.subarray(0, 10)) === 'exo.scene\0') continue;
    parts.push(bytes.subarray(entry.start, entry.end));
  }
  return concat(parts);
}
export function readPngProject(bytes: Uint8Array): string {
  for (const chunk of pngChunks(bytes)) {
    if (chunk.type !== 'tEXt' || chunk.data.length > 65546) continue;
    const text = decoder.decode(chunk.data);
    if (text.startsWith('exo.scene\0')) {
      if (crc32(bytes.subarray(chunk.start + 4, chunk.end - 4)) !== chunk.crc) throw new Error('PNG metadata checksum failed.');
      return text.slice(10);
    }
  }
  throw new Error('This PNG has no embedded Exo project.');
}
