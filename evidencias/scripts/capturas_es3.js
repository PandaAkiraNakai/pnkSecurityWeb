// ES3: capturas reproducibles de la app y de phpMyAdmin (Chromium headless vía Playwright).
// Uso: NODE_PATH=<node_modules con playwright> PNK_CLAVE_PRUEBA=... [PNK_PMA_URL=http://127.0.0.1:18081
//      PNK_PMA_USUARIO=... PNK_PMA_CLAVE=... PNK_ROOT_CLAVE=...] node capturas_es3.js <baseURL> <dirSalida> <prefijo>
// Las claves se pasan por entorno y nunca se escriben en las capturas (los campos de clave se ven como puntos).
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const [base, out, pre] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
const archivo = (n) => path.join(out, `${pre}_${n}.png`);

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 860 }, locale: 'es-CL' });
  const p = await ctx.newPage();
  const terceros = new Set();
  p.on('request', (r) => { const u = new URL(r.url()); if (u.origin !== new URL(base).origin && !u.origin.startsWith('http://127.0.0.1')) terceros.add(u.host); });

  await p.goto(`${base}/?id=1`, { waitUntil: 'networkidle' });
  await p.screenshot({ path: archivo('C01_carta') });
  await p.fill('input[name=frmusuario]', 'alondra@gmail.com');
  await p.fill('input[name=frmpassword]', process.env.PNK_CLAVE_PRUEBA);
  await Promise.all([p.waitForNavigation(), p.click('nav button[type=submit]')]);
  await p.screenshot({ path: archivo('C02_sesion_iniciada'), clip: { x: 0, y: 0, width: 1280, height: 140 } });
  await p.click('a.button');
  await p.waitForSelector('#myModal.show');
  await p.waitForTimeout(400);
  await p.screenshot({ path: archivo('C03_carrito_modal') });
  await p.goto(`${base}/mostrar_carrito.php?id=1`, { waitUntil: 'networkidle' });
  await p.screenshot({ path: archivo('C04_carrito') });
  await p.goto(`${base}/?id=1`);
  const caja = await (await p.$('#comentarios')).boundingBox();
  await p.screenshot({ path: archivo('C05_comentarios'), fullPage: true, clip: { x: 0, y: caja.y - 20, width: 1280, height: 860 } });
  // Intento de cerrar sesión con un enlace GET (como lo haría una página ajena): 405.
  await p.goto(`${base}/setup/cerrar_sesion.php`);
  await p.screenshot({ path: archivo('C06_logout_get_405'), clip: { x: 0, y: 0, width: 1280, height: 260 } });
  console.log('Recursos de terceros cargados:', terceros.size ? [...terceros].join(', ') : 'ninguno');

  if (process.env.PNK_PMA_URL) {
    const pma = await (await browser.newContext({ viewport: { width: 1280, height: 760 }, locale: 'es-CL' })).newPage();
    const entrar = async (usuario, clave) => {
      await pma.goto(process.env.PNK_PMA_URL, { waitUntil: 'networkidle' });
      await pma.fill('#input_username', usuario);
      await pma.fill('#input_password', clave);
      await Promise.all([pma.waitForLoadState('networkidle'), pma.click('#input_go')]);
      await pma.waitForTimeout(800);
    };
    await pma.goto(process.env.PNK_PMA_URL, { waitUntil: 'networkidle' });
    await pma.screenshot({ path: archivo('P01_phpmyadmin_login_por_tunel') });
    await entrar('root', process.env.PNK_ROOT_CLAVE || 'x');
    await pma.screenshot({ path: archivo('P02_phpmyadmin_root_rechazado') });
    await entrar(process.env.PNK_PMA_USUARIO, process.env.PNK_PMA_CLAVE);
    await pma.screenshot({ path: archivo('P03_phpmyadmin_pnk_admin') });
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
