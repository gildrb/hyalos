import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../dist/', import.meta.url));
if (!existsSync(resolve(root, 'index.html'))) {
  console.error('No production build. Run vp run build first. For development use vp dev.');
  process.exit(1);
}
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml; charset=utf-8', '.png': 'image/png', '.wasm': 'application/wasm' };
const port = Number(process.env.PORT || 4173);
const base = process.env.BASE_PATH || '/';
if (!base.startsWith('/') || !base.endsWith('/') || base.includes('..')) throw new Error('BASE_PATH must start and end with / and cannot contain ..');
const server = createServer((req, res) => {
  try {
    const url = new URL(req.url || '/', 'http://localhost');
    if (url.pathname === base.slice(0, -1) && base !== '/') { res.writeHead(308, { Location: base }); res.end(); return; }
    if (!url.pathname.startsWith(base)) { res.writeHead(404); res.end('Not found'); return; }
    const relative = decodeURIComponent(url.pathname.slice(base.length));
    const file = resolve(root, relative || 'index.html');
    if (!file.startsWith(root.endsWith(sep) ? root : root + sep) || !existsSync(file) || !statSync(file).isFile()) { res.writeHead(404); res.end('Not found'); return; }
    res.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream', 'X-Content-Type-Options': 'nosniff', 'Cache-Control': extname(file) === '.html' ? 'no-store' : 'no-cache' });
    createReadStream(file).on('error', () => res.destroy()).pipe(res);
  } catch { res.writeHead(400); res.end('Bad request'); }
});
server.listen(port, '127.0.0.1', () => console.log(`Hyalos: http://127.0.0.1:${port}${base}`));
