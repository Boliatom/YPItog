'use strict';

const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function findBrowser() {
  const fromEnv = process.env.BROWSER;
  const candidates = [
    fromEnv,
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/microsoft-edge',
  ].filter(Boolean);
  const found = candidates.find((p) => fs.existsSync(p));
  if (!found) throw new Error('Не найден Edge или Chrome. Укажите путь в переменной BROWSER.');
  return found;
}

class Browser {
  static async launch({ width = 1280, height = 860, headless = true } = {}) {
    const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'e2e-profile-'));
    const args = [
      `--remote-debugging-port=0`,
      `--user-data-dir=${profile}`,
      `--window-size=${width},${height}`,
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      '--enable-unsafe-swiftshader',
      '--disable-gpu',
      '--force-device-scale-factor=1',
      '--hide-scrollbars',
      '--lang=ru-RU',
      ...(headless ? ['--headless=new'] : []),
      'about:blank',
    ];
    const child = spawn(findBrowser(), args, { stdio: ['ignore', 'ignore', 'pipe'] });

    const portFile = path.join(profile, 'DevToolsActivePort');
    let stderr = '';
    child.stderr.on('data', (chunk) => (stderr += chunk.toString()));
    let port = null;
    let browserPath = null;
    for (let i = 0; i < 160 && port === null; i++) {
      await sleep(125);
      if (fs.existsSync(portFile)) {
        const [first, second] = fs.readFileSync(portFile, 'utf8').split('\n');
        if (Number(first) > 0 && second) {
          port = Number(first);
          browserPath = second.trim();
        }
      }
      const m = stderr.match(/DevTools listening on ws:\/\/127\.0\.0\.1:(\d+)\//);
      if (port === null && m) port = Number(m[1]);
    }
    if (port === null) {
      child.kill();
      throw new Error('Браузер не сообщил порт отладки');
    }

    return new Browser(child, port, profile, { width, height }, browserPath);
  }

  constructor(child, port, profile, size, browserPath = null) {
    this.child = child;
    this.port = port;
    this.profile = profile;
    this.size = size;
    this.browserPath = browserPath;
  }

  async newPage() {
    let targets = [];
    for (let i = 0; i < 40 && !targets.length; i++) {
      const res = await fetch(`http://127.0.0.1:${this.port}/json/list`);
      targets = (await res.json()).filter((t) => t.type === 'page');
      if (!targets.length) await sleep(150);
    }
    const page = new Page(targets[0].webSocketDebuggerUrl, this.size);
    await page.connect();
    return page;
  }

  async close() {
    if (this.browserPath) {
      try {
        const ws = new WebSocket(`ws://127.0.0.1:${this.port}${this.browserPath}`);
        await new Promise((resolve, reject) => {
          ws.onopen = resolve;
          ws.onerror = reject;
        });
        ws.send(JSON.stringify({ id: 1, method: 'Browser.close' }));
        await sleep(1500);
        ws.close();
      } catch {
      }
    }
    this.child.kill();
    await sleep(300);
    try {
      fs.rmSync(this.profile, { recursive: true, force: true });
    } catch {
    }
  }
}

class Page {
  constructor(wsUrl, size) {
    this.wsUrl = wsUrl;
    this.size = size;
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
    this.console = [];
    this.requests = new Map();
  }

  async connect() {
    this.ws = new WebSocket(this.wsUrl);
    await new Promise((resolve, reject) => {
      this.ws.onopen = resolve;
      this.ws.onerror = reject;
    });
    this.ws.onmessage = (event) => this._onMessage(JSON.parse(event.data));
    for (const domain of ['Page', 'Runtime', 'Network', 'Log']) await this.send(`${domain}.enable`);
    await this.setViewport(this.size.width, this.size.height);
    await this.send('Emulation.setEmulatedMedia', {
      features: [{ name: 'prefers-color-scheme', value: 'light' }],
    });
    this.on('Runtime.consoleAPICalled', (p) =>
      this.console.push({ level: p.type, text: p.args.map((a) => a.value ?? a.description ?? '').join(' ') }),
    );
    this.on('Runtime.exceptionThrown', (p) =>
      this.console.push({ level: 'exception', text: p.exceptionDetails?.exception?.description ?? p.exceptionDetails?.text }),
    );
    this.on('Log.entryAdded', (p) => this.console.push({ level: p.entry.level, text: p.entry.text, url: p.entry.url }));
    this.on('Network.requestWillBeSent', (p) =>
      this.requests.set(p.requestId, { method: p.request.method, url: p.request.url, headers: p.request.headers, status: null, type: p.type }),
    );
    this.on('Network.responseReceived', (p) => {
      const r = this.requests.get(p.requestId);
      if (r) Object.assign(r, { status: p.response.status, mime: p.response.mimeType });
    });
    this.on('Network.loadingFailed', (p) => {
      const r = this.requests.get(p.requestId);
      if (r) Object.assign(r, { failed: p.errorText, blocked: p.blockedReason });
    });
  }

  _onMessage(msg) {
    if (msg.id && this.pending.has(msg.id)) {
      const { resolve, reject } = this.pending.get(msg.id);
      this.pending.delete(msg.id);
      msg.error ? reject(new Error(`${msg.error.message}`)) : resolve(msg.result);
    } else if (msg.method) {
      for (const cb of this.listeners.get(msg.method) ?? []) cb(msg.params);
    }
  }

  on(method, cb) {
    if (!this.listeners.has(method)) this.listeners.set(method, []);
    this.listeners.get(method).push(cb);
  }

  send(method, params = {}) {
    const id = this.nextId++;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }

  async setViewport(width, height) {
    this.size = { width, height };
    await this.send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
  }

  async eval(expression) {
    const r = await this.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description ?? 'ошибка в странице');
    return r.result.value;
  }

  async goto(url, { settle = 1200 } = {}) {
    this.semantics = false;
    await this.send('Page.navigate', { url });
    for (let i = 0; i < 100; i++) {
      await sleep(200);
      if (await this.eval('!!document.querySelector("flt-glass-pane")').catch(() => false)) break;
    }
    await sleep(settle);
  }

  async gotoHtml(html) {
    await this.send('Page.navigate', { url: 'data:text/html;charset=utf-8,' + encodeURIComponent(html) });
    await sleep(500);
    this.semantics = false;
  }

  async reload() {
    this.semantics = false;
    await this.send('Page.reload');
    for (let i = 0; i < 100; i++) {
      await sleep(200);
      if (await this.eval('!!document.querySelector("flt-glass-pane")').catch(() => false)) break;
    }
    await sleep(1200);
  }

  async enableSemantics() {
    if (this.semantics) return;
    await this.eval('document.querySelector("flt-semantics-placeholder")?.click()');
    for (let i = 0; i < 40; i++) {
      await sleep(150);
      if ((await this.eval('document.querySelectorAll("flt-semantics").length')) > 0) break;
    }
    this.semantics = true;
    await sleep(300);
    await this.clickAt(3, 3);
    await sleep(400);
  }

  async nudge() {
    await this.send('Page.captureScreenshot', {
      format: 'jpeg',
      quality: 1,
      clip: { x: 0, y: 0, width: 1, height: 1, scale: 1 },
    }).catch(() => {});
    await sleep(150);
  }

  async nodes() {
    await this.enableSemantics();
    return this.eval(`[...document.querySelectorAll('flt-semantics')].map((e) => {
      const r = e.getBoundingClientRect();
      const input = e.querySelector(':scope > input, :scope > textarea');
      return {
        role: e.getAttribute('role') || (input ? 'textbox' : ''),
        label: (e.getAttribute('aria-label') || (input && input.getAttribute('aria-label')) || e.textContent || '').trim(),
        value: input ? input.value : '',
        x: r.x, y: r.y, w: r.width, h: r.height,
        disabled: e.getAttribute('aria-disabled') === 'true',
        checked: e.getAttribute('aria-checked'),
      };
    }).filter((n) => n.w > 0 && n.h > 0)`);
  }

  static matches(node, query) {
    const texts = [node.label, node.value].filter(Boolean);
    if (query instanceof RegExp) return texts.some((t) => query.test(t));
    return texts.some((t) => t === query || t.includes(query));
  }

  async find(query, { index = 0, role, timeout = 6000 } = {}) {
    const started = Date.now();
    while (Date.now() - started < timeout) {
      const all = await this.nodes();
      let hits = all.filter((n) => Page.matches(n, query) && (!role || n.role === role));
      const exact = hits.filter((n) => n.label === query || n.value === query);
      if (exact.length) hits = exact;
      const picked = index < 0 ? hits[hits.length + index] : hits[index];
      if (picked) return picked;
      await sleep(250);
    }
    throw new Error(`Не найден элемент: ${query}`);
  }

  async clickAt(x, y) {
    await this.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
    await this.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
    await this.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
  }

  async click(query, options = {}) {
    const node = await this.find(query, options);
    await this.clickAt(node.x + node.w / 2, node.y + node.h / 2);
    await sleep(options.wait ?? 500);
    return node;
  }

  async type(text) {
    await this.send('Input.insertText', { text });
    await sleep(150);
  }

  async key(key, { modifiers = 0 } = {}) {
    const codes = { Enter: 13, Backspace: 8, Escape: 27, Tab: 9, a: 65 };
    const base = { key, windowsVirtualKeyCode: codes[key] ?? 0, modifiers };
    await this.send('Input.dispatchKeyEvent', { type: 'keyDown', ...base });
    await this.send('Input.dispatchKeyEvent', { type: 'keyUp', ...base });
  }

  async fill(query, text, options = {}) {
    await this.click(query, { role: 'textbox', wait: 250, ...options });
    await this.key('a', { modifiers: 2 });
    await this.key('Backspace');
    if (text) await this.type(text);
    await sleep(200);
  }

  async shot(file) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const { data } = await this.send('Page.captureScreenshot', { format: 'jpeg', quality: 85 });
    fs.writeFileSync(file, Buffer.from(data, 'base64'));
  }

  async visibleText() {
    return (await this.nodes()).map((n) => n.label).join('\n');
  }

  async has(query) {
    return (await this.nodes()).some((n) => Page.matches(n, query));
  }

  async waitFor(query, timeout = 8000) {
    return this.find(query, { timeout });
  }

  async location() {
    return this.eval('location.pathname + location.search');
  }

  async close() {
    this.ws?.close();
  }
}

module.exports = { Browser, Page, sleep };
