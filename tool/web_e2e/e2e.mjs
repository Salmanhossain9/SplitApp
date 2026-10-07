import { chromium } from 'playwright-core';
import http from 'node:http'; import fs from 'node:fs'; import path from 'node:path';
// Usage: node e2e.mjs <flutter build/web dir> [screenshot dir]
// Env: CHROMIUM=/path/to/chrome (default: Playwright's bundled one)
const root = process.argv[2];
const outDir = process.argv[3] ?? '.';
fs.mkdirSync(outDir, { recursive: true });
const here = path.dirname(new URL(import.meta.url).pathname);
const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html';
  const f = path.join(root, p);
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.statusCode = 404; return res.end(); }
  const ext = path.extname(f); res.setHeader('content-type', { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm' }[ext] || 'application/octet-stream');
  res.end(fs.readFileSync(f));
}).listen(8768);
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
const ctx = await browser.newContext({ viewport: { width: 390, height: 1700 }, deviceScaleFactor: 1 });
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message.slice(0, 300)));
page.on('console', (m) => { const t = m.text(); if (m.type() === 'error' && !t.includes('ERR_FAILED')) errors.push('console: ' + t.slice(0, 300)); });
await page.route('https://www.gstatic.com/flutter-canvaskit/**', async (route) => {
  const rel = new URL(route.request().url()).pathname.split('/').slice(3).join('/');
  const f = path.join(root, 'canvaskit', rel);
  if (fs.existsSync(f)) return route.fulfill({ status: 200, contentType: f.endsWith('.wasm') ? 'application/wasm' : 'text/javascript', headers: { 'access-control-allow-origin': '*' }, body: fs.readFileSync(f) });
  return route.abort();
});
await page.route('https://fonts.gstatic.com/**', (r) => r.abort());
await page.goto('http://127.0.0.1:8768/');
await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
await page.waitForTimeout(2500);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForTimeout(800);

let n = 0;
const shot = async (name) => { n++; await page.waitForTimeout(400); await page.screenshot({ path: path.join(outDir, `e2e_${String(n).padStart(2, '0')}_${name}.png`) }); };
// Find the semantics node whose text is exactly `label` (smallest one), return its centre.
async function find(label, nth = 0) {
  return page.evaluate(({ label, nth }) => {
    const text = (e) => (e.getAttribute('aria-label') || e.textContent || '').trim();
    const all = [...document.querySelectorAll('flt-semantics')]
      .map((e) => ({ r: e.getBoundingClientRect(), t: text(e) }))
      .filter((h) => h.r.width > 0 && h.r.height > 0 && h.t);
    const exact = all.filter((h) => h.t === label || h.t.split('\n')[0].trim() === label)
      .sort((a, b) => a.r.top - b.r.top || a.r.left - b.r.left);
    let hits = exact;
    if (hits.length === 0) {
      // Fallback: the smallest nodes that merely contain the text.
      hits = all.filter((h) => h.t.includes(label)).sort((a, b) => a.t.length - b.t.length || a.r.top - b.r.top);
    }
    const h = hits[nth];
    return h ? { x: h.r.left + h.r.width / 2, y: h.r.top + h.r.height / 2, count: hits.length } : null;
  }, { label, nth });
}
async function tap(label, nth = 0, wait = 700) {
  const p = await find(label, nth);
  if (!p) throw new Error(`cannot find "${label}" #${nth}`);
  await page.mouse.click(p.x, p.y);
  await page.waitForTimeout(wait);
}
const has = async (label) => !!(await find(label));
const expectText = async (label) => { if (!(await has(label))) console.log(`  (note: no semantic node for "${label}")`); };

let flowOk = false;
try {
  await expectText('good evening.');
  await shot('home');
  await tap('new bill');
  await expectText('where are we eating?'); await shot('new_bill');
  await page.mouse.click(90, 168); await page.waitForTimeout(500); // the place field (headline)
  await page.keyboard.type('Chillox', { delay: 60 }); await page.waitForTimeout(500);
  await tap('NSU boys');
  await expectText('with NSU boys . 4 of 4 here'); await shot('group_loaded');
  await tap('scan receipt');
  await expectText('add items'); await page.waitForTimeout(1200); await shot('items_scan_tab');
  const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 8000 }), tap('upload from photos', 0, 300)]);
  await chooser.setFiles(path.join(here, 'receipt.png'));
  await page.waitForTimeout(700); await shot('scanning');
  await page.waitForTimeout(2500);
  await expectText('does this match your receipt?'); await shot('items_after_scan');
  await tap('not yet'); await expectText('yes');
  await tap('who had what?');
  await expectText('every item is claimed').catch(() => {}); await shot('claim_empty');
  // chips: 4 per card (You, Rafi, Nabil, Tania); claims as in the Chillox sample
  for (const [card, who] of [[0, [0]], [1, [1, 2]], [2, [0, 3]], [3, [0, 1, 3]]]) {
    for (const p of who) { const label = ['You', 'Rafi', 'Nabil', 'Tania'][p]; await tap(label, card, 350); }
  }
  await expectText('every item is claimed'); await shot('claim_done');
  await tap('equally', 0); await shot('claim_equally'); await tap('custom'); await shot('claim_custom'); await tap('by items');
  await tap('vat and service charge');
  await expectText('how should we split the extras?'); await tap('by what they ate'); await shot('charges');
  await tap('send bills', 0, 1500);
  await expectText('bills sent.'); await shot('share_sheet');
  await tap('settle up');
  await expectText('collected'); await tap('bKash', 0); await tap('cash', 1); await tap('owes me', 2); await shot('settle');
  await tap('finish bill', 0, 1800);
  await expectText('all settled.'); await page.waitForTimeout(1200); await shot('all_settled');
  await tap('back to home', 0, 1200);
  await expectText('good evening.'); await shot('home_after_settle');
  await tap('money', 0).catch(() => {});
  flowOk = true;
  console.log('flow complete');
} catch (e) { console.log('STEP FAILED:', e.message); await shot('failed'); }
// The flow ended on the home screen: Chillox is on top with a tab, and Tania's 234.78 (her
// "by what they ate" share from the golden table) is on the open tab.
const finalText = (await page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()).join('\n')));
const checks = [
  ['Chillox is on the home list', finalText.includes('Chillox')],
  ['the bill total is 2,236', finalText.includes('৳2,236')],
  ['Tania owes her by-items share', finalText.includes('Tania owes you') && finalText.includes('৳234.78')],
  ['no page or console errors', errors.length === 0],
];
let failed = !flowOk;
for (const [name, ok] of checks) { console.log(ok ? 'ok  ' : 'FAIL', name); if (!ok) failed = true; }
if (errors.length) console.log(JSON.stringify(errors, null, 1));
await browser.close(); server.close();
process.exit(failed ? 1 : 0);
