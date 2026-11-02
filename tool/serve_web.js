#!/usr/bin/env node
'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const args = process.argv.slice(2);
const flags = Object.fromEntries(
  args
    .filter((a) => a.startsWith('--'))
    .map((a) => {
      const [key, value = 'true'] = a.replace(/^--/, '').split('=');
      return [key, value];
    }),
);
const positional = args.filter((a) => !a.startsWith('--'));

const root = path.resolve(positional[0] || 'build/web');
const port = Number(positional[1] || 5555);
const mode = flags.mode || 'spa';
const compress = flags.compress || 'none';
let base = flags.base || '/';
if (!base.startsWith('/')) base = '/' + base;
if (!base.endsWith('/')) base += '/';

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.symbols': 'application/octet-stream',
};
const COMPRESSIBLE = new Set(['.html', '.js', '.mjs', '.json', '.css', '.wasm', '.svg', '.txt', '.otf', '.ttf', '.symbols']);

if (!fs.existsSync(path.join(root, 'index.html'))) {
  console.error(`В папке ${root} нет index.html. Сначала выполните flutter build web.`);
  process.exit(1);
}

const cache = new Map();

function encodingFor(req, file) {
  if (compress === 'none' || !COMPRESSIBLE.has(path.extname(file).toLowerCase())) return null;
  const accept = String(req.headers['accept-encoding'] || '');
  if (compress === 'br' && /\bbr\b/.test(accept)) return 'br';
  if (/\bgzip\b/.test(accept)) return 'gzip';
  return null;
}

function send(req, res, file, status = 200) {
  const type = TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream';
  const headers = { 'Content-Type': type, 'Cache-Control': 'no-cache' };
  const encoding = encodingFor(req, file);
  if (!encoding) {
    res.writeHead(status, headers);
    return fs.createReadStream(file).pipe(res);
  }
  const key = `${file}|${encoding}`;
  let body = cache.get(key);
  if (!body) {
    const raw = fs.readFileSync(file);
    body =
      encoding === 'br'
        ? zlib.brotliCompressSync(raw, { params: { [zlib.constants.BROTLI_PARAM_QUALITY]: 6 } })
        : zlib.gzipSync(raw, { level: 6 });
    cache.set(key, body);
  }
  res.writeHead(status, { ...headers, 'Content-Encoding': encoding, 'Content-Length': body.length, Vary: 'Accept-Encoding' });
  res.end(body);
}

http
  .createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    let pathname = decodeURIComponent(url.pathname);

    if (base !== '/' && pathname === base.slice(0, -1)) {
      res.writeHead(301, { Location: base + url.search });
      return res.end();
    }
    if (!pathname.startsWith(base)) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('Not found');
    }
    pathname = '/' + pathname.slice(base.length);

    const requested = path.normalize(pathname).replace(/^(\.\.[/\\])+/, '');
    const file = path.join(root, requested);

    if (!file.startsWith(root)) {
      res.writeHead(403);
      return res.end('Forbidden');
    }

    fs.stat(file, (err, stat) => {
      if (!err && stat.isFile()) return send(req, res, file);
      if (!err && stat.isDirectory() && fs.existsSync(path.join(file, 'index.html'))) {
        return send(req, res, path.join(file, 'index.html'));
      }
      if (path.extname(requested) && !requested.endsWith('.html')) {
        res.writeHead(404);
        return res.end('Not found');
      }
      if (mode === 'plain') {
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        return res.end('Error response: File not found');
      }
      if (mode === 'pages') {
        const page = path.join(root, '404.html');
        if (fs.existsSync(page)) return send(req, res, page, 404);
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        return res.end('404\nFile not found\n\nThe site configured at this address does not contain the requested file.');
      }
      send(req, res, path.join(root, 'index.html'));
    });
  })
  .listen(port, 'localhost', () => {
    console.log(`Клиент: http://localhost:${port}${base}   (папка ${root}, режим ${mode}, сжатие ${compress})`);
  });
