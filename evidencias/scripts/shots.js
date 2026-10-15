// Capturas de pantalla reproducibles de la app (Chromium headless vía Playwright).
// Uso: NODE_PATH=<node_modules con playwright> node shots.js <baseURL> <dirSalida> <prefijo> [login]
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const [base, out, prefix, doLogin] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  const shot = async (name, url, opts = {}) => {
    const r = await page.goto(base + url, { waitUntil: 'load' });
    const file = path.join(out, `${prefix}_${name}.png`);
    await page.screenshot({ path: file, fullPage: opts.full !== false, clip: opts.clip });
    console.log(`${name}: HTTP ${r.status()} -> ${file}`);
  };
  await shot('S01_id_1', '/?id=1', { full: false });
  await shot('S02_sin_id', '/', { full: false });
  await shot('S03_id_abc', '/?id=abc', { full: false });
  await shot('S04_id_999', '/?id=999', { full: false });
  await shot('S05_info_php', '/info.php', { full: false });
  await shot('S06_mostrar_carrito', '/mostrar_carrito.php?keyid=1', { full: false });
  if (doLogin) {
    await page.goto(base + '/?id=1');
    await page.fill('input[name=frmusuario]', 'alondra@gmail.com');
    await page.fill('input[name=frmpassword]', process.env.PNK_CLAVE_PRUEBA);
    await Promise.all([page.waitForNavigation(), page.click('button[type=submit]')]);
    await page.goto(base + '/?id=1');
    // Zona de comentarios al final de la página
    const h = await page.evaluate(() => document.body.scrollHeight);
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    const file = path.join(out, `${prefix}_S07_comentarios.png`);
    await page.screenshot({ path: file, clip: { x: 0, y: Math.max(0, h - 900), width: 1280, height: 900 }, fullPage: true });
    console.log(`S07_comentarios: -> ${file}`);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({ path: path.join(out, `${prefix}_S08_sesion.png`), clip: { x: 0, y: 0, width: 1280, height: 120 }, fullPage: true });
    console.log('S08_sesion: ok');
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
