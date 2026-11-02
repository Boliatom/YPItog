#!/usr/bin/env node
'use strict';

const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { Browser, sleep } = require('./browser.js');

const root = path.resolve(__dirname, '..', '..');
const SHOTS = process.env.SHOTS_DIR || path.join(root, '..', 'screenshots', 'salon');
const PORT = process.env.SHOTS_PORT || '5561';
const FAST_PORT = String(Number(PORT) + 1);
const BASE = `http://localhost:${PORT}`;
const FAST = `http://localhost:${FAST_PORT}`;

const ADMIN = ['admin@salon.ru', 'Admin2026!'];
const MASTER = ['master@salon.ru', 'Master2026!'];
const CLIENT = ['client@salon.ru', 'Client2026!'];

const results = [];
function check(ok, message) {
  results.push({ ok: !!ok, message });
  console.log(`  ${ok ? 'OK ' : 'ERR'} ${message}`);
}

async function seen(page, query, timeout = 4000) {
  const started = Date.now();
  do {
    if (await page.has(query)) return true;
    await sleep(250);
  } while (Date.now() - started < timeout);
  return false;
}

async function shot(page, name) {
  const file = path.join(SHOTS, `${name}.jpg`);
  await page.shot(file);
  console.log(`  снимок ${path.relative(root, file)}`);
}

async function login(page, base, [email, password]) {
  await page.goto(`${base}/login`);
  await page.eval('localStorage.clear()');
  await page.goto(`${base}/login`);
  await page.fill('Эл. почта', email);
  await page.fill('Пароль', password);
  await page.click('Войти', { role: 'button' });
  await sleep(1800);
}

async function view(page, base, route, wait = 1600) {
  await page.goto(`${base}${route}`);
  await sleep(wait);
}

async function attempt(name, action) {
  try {
    await action();
  } catch (error) {
    check(false, `${name}: ${error.message}`);
  }
}

function startServer(dir, port) {
  return spawn(process.execPath, ['tool/serve_web.js', dir, port], { cwd: root, stdio: 'ignore' });
}

(async () => {
  for (const dir of ['build/web_local', 'build/web_fast']) {
    if (!fs.existsSync(path.join(root, dir, 'index.html'))) {
      console.error(`Нет сборки ${dir}: см. README.`);
      process.exit(2);
    }
  }
  const servers = [startServer('build/web_local', PORT), startServer('build/web_fast', FAST_PORT)];
  await sleep(1500);
  const browser = await Browser.launch({ width: 1280, height: 860 });
  try {
    const page = await browser.newPage();

    console.log('Вход и регистрация');
    await view(page, BASE, '/');
    check(await seen(page, 'Вход в систему'), 'без входа открывается форма входа');
    await shot(page, '01-login');
    await page.fill('Эл. почта', ADMIN[0]);
    await page.fill('Пароль', 'wrong');
    await page.click('Войти', { role: 'button' });
    check(await seen(page, 'Неверная почта или пароль.'), 'неверный пароль: понятное сообщение');
    await shot(page, '02-login-error');
    await view(page, BASE, '/register');
    await page.fill('Имя и фамилия', 'Тестова Ирина');
    await page.fill('Эл. почта', 'irina@example.ru');
    await page.fill('Пароль', 'Abc123');
    await sleep(500);
    await shot(page, '03-register-password');

    console.log('Клиент');
    await login(page, BASE, CLIENT);
    check((await page.location()) === '/', 'после входа открыта главная');
    await shot(page, '10-client-dashboard');
    await view(page, BASE, '/services');
    await shot(page, '11-client-services');
    await view(page, BASE, '/masters');
    await shot(page, '12-client-masters');
    await view(page, BASE, '/book');
    await page.click('Женская стрижка', { role: 'checkbox' }).catch(() => page.click('Женская стрижка'));
    await sleep(700);
    await shot(page, '13-book-services');
    await view(page, BASE, '/my-appointments');
    check(await seen(page, 'Мои записи'), 'раздел «Мои записи»');
    await shot(page, '14-my-appointments');
    await view(page, BASE, '/my-appointments?status=done&sort=startsAt,desc');
    await shot(page, '15-my-appointments-done');
    await view(page, BASE, '/admin/users');
    check(await seen(page, '403'), 'чужой адрес: экран отказа');
    await shot(page, '16-client-forbidden');
    await view(page, BASE, '/book?__fail=409');

    console.log('Мастер');
    await login(page, BASE, MASTER);
    await shot(page, '20-master-dashboard');
    await view(page, BASE, '/my-schedule');
    await shot(page, '21-master-schedule');
    await view(page, BASE, '/my-schedule?status=new&sort=startsAt,asc');
    await shot(page, '22-master-schedule-new');
    await view(page, BASE, '/clients');
    await shot(page, '23-master-clients');
    await view(page, BASE, '/appointments');
    check(await seen(page, '403'), 'мастеру закрыт список всех записей');

    console.log('Администратор');
    await login(page, BASE, ADMIN);
    await shot(page, '30-admin-dashboard');
    await view(page, BASE, '/appointments');
    await shot(page, '31-admin-appointments');
    await view(page, BASE, '/appointments?status=new&from=2026-11-05&to=2026-11-12&sort=startsAt,asc');
    await shot(page, '32-admin-appointments-filtered');
    await view(page, BASE, '/services');
    await shot(page, '33-admin-services');
    await view(page, BASE, '/services?search=zzzz');
    check(await seen(page, 'Ничего не найдено'), 'пустой результат поиска');
    await shot(page, '34-admin-empty');
    await view(page, BASE, '/services?__fail=500');
    check(await seen(page, 'Не удалось загрузить данные'), 'состояние ошибки');
    await shot(page, '35-admin-error');
    await view(page, BASE, '/services?__fail=network');
    await shot(page, '36-admin-network-error');
    await view(page, BASE, '/services?__delay=4000', 900);
    await shot(page, '37-admin-loading');
    await sleep(4200);
    await view(page, BASE, '/clients');
    await shot(page, '38-admin-clients');
    await view(page, BASE, '/cards');
    await shot(page, '39-admin-cards');
    await view(page, BASE, '/schedules');
    await shot(page, '40-admin-schedules');
    await view(page, BASE, '/reviews');
    await shot(page, '41-admin-reviews');
    await view(page, BASE, '/categories');
    await shot(page, '42-admin-categories');
    await view(page, BASE, '/masters');
    await shot(page, '43-admin-masters');
    await view(page, BASE, '/admin/users');
    await shot(page, '44-admin-users');
    await view(page, BASE, '/admin/stats', 2200);
    await shot(page, '45-admin-stats');
    await view(page, BASE, '/clients/cli000000000001');
    await shot(page, '46-admin-client-detail');
    await view(page, BASE, '/masters/mst000000000001');
    await shot(page, '47-admin-master-detail');

    console.log('Формы');
    await view(page, BASE, '/services/new');
    await page.click('Сохранить', { role: 'button' });
    await sleep(800);
    check(await seen(page, 'Обязательное поле'), 'форма: ошибки у полей');
    await shot(page, '50-form-validation');
    await page.fill('Название *', 'Женская стрижка');
    await page.fill('Длительность *', '40');
    await page.fill('Цена *', '900');
    await sleep(400);
    await page.click('Категория *');
    await sleep(500);
    await page.click('Парикмахерские услуги', { role: 'menuitem' });
    await sleep(500);
    await page.click('Сохранить', { role: 'button' });
    await sleep(1200);
    check(await seen(page, 'Такое значение уже используется'), 'ошибка сервера показана у поля');
    await shot(page, '51-form-server-error');

    console.log('Удаление и восстановление');
    await view(page, BASE, '/services?includeDeleted=true');
    await shot(page, '52-admin-show-deleted');

    console.log('Сценарии клиента');
    await page.setViewport(1280, 1500);
    await login(page, BASE, CLIENT);
    await attempt('запись на услугу', async () => {
      await view(page, BASE, '/book');
      await page.click('Женская стрижка');
      await sleep(600);
      await page.click('Мастер', { role: 'button' });
      await sleep(500);
      await page.click('Орлова', { role: 'menuitem' });
      await sleep(600);
      await page.click('Выбрать дату', { role: 'button' });
      await sleep(900);
      await page.click('ОК', { role: 'button' });
      await sleep(1500);
      await shot(page, '80-booking-slots');
      await page.click('10:00');
      await sleep(600);
      await shot(page, '81-booking-confirm');
      await page.click('Записаться', { role: 'button', index: 1 });
      await sleep(1800);
      check(await seen(page, 'Вы записаны'), 'после записи показано подтверждение');
      await shot(page, '82-booking-done');
    });
    await attempt('конфликт 409 при записи', async () => {
      await view(page, BASE, '/book?__fail=409');
      await page.click('Женская стрижка');
      await sleep(600);
      await page.click('Мастер', { role: 'button' });
      await sleep(500);
      await page.click('Орлова', { role: 'menuitem' });
      await sleep(600);
      await page.click('Выбрать дату', { role: 'button' });
      await sleep(900);
      await page.click('ОК', { role: 'button' });
      await sleep(1500);
      await page.click('11:00');
      await sleep(600);
      await page.click('Записаться', { role: 'button', index: 1 });
      await sleep(1200);
      check(await seen(page, 'уже занято'), 'ошибка 409: сообщение о занятом времени');
      await shot(page, '83-booking-conflict');
    });
    await page.setViewport(1280, 860);
    await attempt('отмена записи', async () => {
      await view(page, BASE, '/my-appointments?status=new&sort=startsAt,asc');
      await page.click('Отменить запись', { role: 'button' });
      await sleep(700);
      await shot(page, '84-cancel-confirm');
      await page.click('Отменить запись', { role: 'button' });
      await sleep(1200);
      check(await seen(page, 'Запись отменена'), 'запись отменена, показано уведомление');
    });
    await attempt('отзыв о визите', async () => {
      await view(page, BASE, '/my-appointments?status=done&sort=startsAt,desc&size=50');
      await page.click('Оставить отзыв', { role: 'button' });
      await sleep(800);
      await page.fill('Комментарий', 'Спасибо, всё понравилось!');
      await shot(page, '85-review-dialog');
      await page.click('Отправить', { role: 'button' });
      await sleep(1500);
    });

    console.log('Сценарии мастера');
    await login(page, BASE, MASTER);
    await attempt('статус записи', async () => {
      await view(page, BASE, '/my-schedule?status=new&sort=startsAt,asc');
      await page.click('Подтвердить запись', { role: 'button' });
      await sleep(1200);
      check(await seen(page, 'Запись подтверждена'), 'мастер подтвердил запись');
      await shot(page, '86-master-confirmed');
    });

    console.log('Сценарии администратора');
    await login(page, BASE, ADMIN);
    await attempt('подтверждение удаления', async () => {
      await view(page, BASE, '/services');
      await page.click('Удалить', { role: 'button' });
      await sleep(700);
      await shot(page, '87-delete-confirm');
      await page.click('Отмена', { role: 'button' });
      await sleep(500);
    });
    await attempt('множественный выбор', async () => {
      await view(page, BASE, '/services');
      await page.click('Выбрать всё', { role: 'checkbox' }).catch(() => null);
      await sleep(700);
      await shot(page, '88-selection');
    });

    console.log('Адаптивность');
    for (const [w, h] of [[360, 780], [768, 1000], [1920, 1000]]) {
      await page.setViewport(w, h);
      await view(page, BASE, '/appointments');
      await shot(page, `60-admin-appointments-${w}`);
      await view(page, BASE, '/services');
      await shot(page, `61-admin-services-${w}`);
    }
    await page.setViewport(360, 780);
    await login(page, BASE, CLIENT);
    await view(page, BASE, '/book');
    await shot(page, '62-client-book-360');
    await view(page, BASE, '/my-appointments');
    await shot(page, '63-client-my-appointments-360');
    await page.setViewport(1280, 860);

    console.log('Сессия');
    await page.goto(`${FAST}/login`);
    await page.eval('localStorage.clear()');
    await login(page, FAST, ADMIN);
    await sleep(8000);
    await shot(page, '70-inactivity-warning');
    check(await seen(page, 'Вы вышли из системы', 12000) || (await page.location()).startsWith('/login'), 'через время без действий сеанс завершается');
    await sleep(1500);
    await shot(page, '71-session-ended');
  } finally {
    await browser.close();
    for (const server of servers) server.kill();
  }
  const failed = results.filter((r) => !r.ok);
  console.log(`\nПроверок: ${results.length}, не выполнено: ${failed.length}`);
  for (const f of failed) console.log(`  не выполнено: ${f.message}`);
  process.exit(failed.length ? 1 : 0);
})().catch((e) => {
  console.error('Сбой сценария:', e);
  process.exit(1);
});
