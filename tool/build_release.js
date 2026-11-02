#!/usr/bin/env node
'use strict';

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const flags = Object.fromEntries(
  process.argv
    .slice(2)
    .filter((a) => a.startsWith('--'))
    .map((a) => {
      const [k, ...v] = a.replace(/^--/, '').split('=');
      return [k, v.length ? v.join('=') : 'true'];
    }),
);

const backend = flags.backend || 'api';
const out = flags.out || 'build/web';
const base = flags.base;

if (backend === 'api' && !flags.api) {
  console.error('Не задан адрес API: --api=https://…/api (или --backend=persistent для работы без сервера).');
  process.exit(2);
}
if (base && !/^\/(.+\/)?$/.test(base)) {
  console.error('--base должен начинаться и заканчиваться косой чертой, например /library-client/');
  process.exit(2);
}

const args = ['build', 'web', '--release'];
if (flags.wasm) args.push('--wasm');
if (flags['no-cdn']) args.push('--no-web-resources-cdn');
if (base) args.push('--base-href', base);
if (flags.api) args.push(`--dart-define=API_BASE_URL=${flags.api}`);
args.push(`--dart-define=BACKEND=${backend}`);
args.push('--output', out);

console.log(`flutter ${args.join(' ')}`);
const flutter = process.platform === 'win32' ? 'flutter.bat' : 'flutter';
const result = spawnSync(flutter, args, { cwd: root, stdio: 'inherit', shell: process.platform === 'win32' });
if (result.status !== 0) process.exit(result.status ?? 1);

const dir = path.resolve(root, out);
fs.copyFileSync(path.join(dir, 'index.html'), path.join(dir, '404.html'));
fs.writeFileSync(path.join(dir, '.nojekyll'), '');
console.log('Создано: 404.html (копия index.html), .nojekyll');

let total = 0;
const walk = (d) => {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else total += fs.statSync(p).size;
  }
};
walk(dir);
console.log(`Каталог ${out}: ${(total / 1048576).toFixed(2)} МБ`);
