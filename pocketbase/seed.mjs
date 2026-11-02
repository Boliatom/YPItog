import { readFileSync } from 'node:fs';

const base = process.env.PB_URL || 'http://127.0.0.1:8090';
const email = process.env.PB_ADMIN_EMAIL;
const password = process.env.PB_ADMIN_PASSWORD;
const file = process.argv[2] || new URL('./seed.json', import.meta.url);

if (!email || !password) {
  console.error('Задайте PB_ADMIN_EMAIL и PB_ADMIN_PASSWORD (учётная запись суперпользователя PocketBase).');
  process.exit(2);
}

const order = [
  'service_categories',
  'services',
  'masters',
  'clients',
  'client_cards',
  'schedules',
  'appointments',
  'reviews',
  'users',
];

async function call(method, path, body, token) {
  const response = await fetch(`${base}/api${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: token } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${method} ${path} -> ${response.status} ${JSON.stringify(data)}`);
  }
  return data;
}

function clean(collection, row) {
  const { created, updated, ...rest } = row;
  const body = {};
  for (const [key, value] of Object.entries(rest)) {
    if (value === '' && ['client', 'master'].includes(key) && collection === 'users') continue;
    body[key] = value;
  }
  if (collection === 'users') body.passwordConfirm = body.password;
  return body;
}

const seed = JSON.parse(readFileSync(file, 'utf8'));
const auth = await call('POST', '/collections/_superusers/auth-with-password', {
  identity: email,
  password,
});

let total = 0;
for (const collection of order) {
  const rows = seed[collection] || [];
  for (const row of rows) {
    await call('POST', `/collections/${collection}/records`, clean(collection, row), auth.token);
    total++;
  }
  console.log(`${collection}: ${rows.length}`);
}
console.log(`Загружено записей: ${total}`);
