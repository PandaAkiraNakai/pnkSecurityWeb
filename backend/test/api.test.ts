// Pruebas de la API: validación, autenticación, autorización y no exposición de datos.
// Corren sin base de datos (repositorio en memoria), así que Jenkins las ejecuta en cada commit.
import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import { crearApp, COOKIE, MAX_INTENTOS } from '../src/app.js';
import { crearRepoMemoria, CLAVE_PRUEBA } from './repo-memoria.js';

process.env.NODE_ENV = 'test';
const OPCIONES = { jwtSecret: 'clave-de-pruebas-de-al-menos-32-caracteres!', cookieSecure: true, version: 'test' };

let ctx: Awaited<ReturnType<typeof crearRepoMemoria>>;
let app: ReturnType<typeof crearApp>;

beforeEach(async () => {
  ctx = await crearRepoMemoria();
  app = crearApp(ctx.repo, OPCIONES);
});

async function iniciarSesion(email = 'alondra@pnk.test') {
  const r = await request(app).post('/api/auth/login').send({ email, password: CLAVE_PRUEBA });
  expect(r.status).toBe(200);
  const cookie = ([] as string[]).concat(r.headers['set-cookie'] ?? [])[0]!;
  return cookie.split(';')[0]!;
}

describe('estado y cabeceras', () => {
  it('GET /api/health responde ok con la versión', async () => {
    const r = await request(app).get('/api/health');
    expect(r.status).toBe(200);
    expect(r.body).toEqual({ estado: 'ok', version: 'test' });
  });
  it('envía cabeceras de seguridad y oculta la tecnología', async () => {
    const r = await request(app).get('/api/health');
    expect(r.headers['x-powered-by']).toBeUndefined();
    expect(r.headers['x-content-type-options']).toBe('nosniff');
    expect(r.headers['content-security-policy']).toContain("default-src 'none'");
    expect(r.headers['cache-control']).toBe('no-store');
  });
  it('una ruta inexistente responde 404 en JSON', async () => {
    const r = await request(app).get('/api/no-existe');
    expect(r.status).toBe(404);
    expect(r.body.error).toBeTruthy();
  });
});

describe('autenticación', () => {
  it('rechaza una contraseña incorrecta con un mensaje genérico', async () => {
    const r = await request(app).post('/api/auth/login').send({ email: 'alondra@pnk.test', password: 'mala' });
    expect(r.status).toBe(401);
    expect(r.body.error).toBe('Correo o contraseña incorrectos');
    expect(r.headers['set-cookie']).toBeUndefined();
  });
  it('un correo inexistente recibe el mismo mensaje (no revela cuentas)', async () => {
    const r = await request(app).post('/api/auth/login').send({ email: 'nadie@pnk.test', password: 'x' });
    expect(r.status).toBe(401);
    expect(r.body.error).toBe('Correo o contraseña incorrectos');
  });
  it('una cuenta inactiva no puede entrar aunque la clave sea correcta', async () => {
    const r = await request(app).post('/api/auth/login').send({ email: 'inactiva@pnk.test', password: CLAVE_PRUEBA });
    expect(r.status).toBe(401);
  });
  it('valida el formato del login (400) y rechaza campos extra', async () => {
    expect((await request(app).post('/api/auth/login').send({ email: 'no-es-correo', password: 'x' })).status).toBe(400);
    expect((await request(app).post('/api/auth/login').send({ email: 'alondra@pnk.test', password: CLAVE_PRUEBA, admin: true })).status).toBe(400);
  });
  it('inicia sesión con cookie HttpOnly, Secure y SameSite=Strict, sin exponer el hash', async () => {
    const r = await request(app).post('/api/auth/login').send({ email: 'ALONDRA@pnk.test ', password: CLAVE_PRUEBA });
    expect(r.status).toBe(200);
    expect(r.body).toEqual({ id: 1, nombre: 'Alondra', email: 'alondra@pnk.test' });
    const cookie = ([] as string[]).concat(r.headers['set-cookie'] ?? [])[0]!;
    expect(cookie).toContain(`${COOKIE}=`);
    expect(cookie).toMatch(/HttpOnly/i);
    expect(cookie).toMatch(/Secure/i);
    expect(cookie).toMatch(/SameSite=Strict/i);
    expect(JSON.stringify(r.body)).not.toContain('$2');
  });
  it(`bloquea la cuenta tras ${MAX_INTENTOS} intentos fallidos (429), incluso con la clave correcta`, async () => {
    for (let i = 0; i < MAX_INTENTOS; i++) {
      await request(app).post('/api/auth/login').send({ email: 'alondra@pnk.test', password: 'mala' });
    }
    const r = await request(app).post('/api/auth/login').send({ email: 'alondra@pnk.test', password: CLAVE_PRUEBA });
    expect(r.status).toBe(429);
  });
  it('una cookie alterada se trata como sin sesión', async () => {
    const r = await request(app).get('/api/auth/yo').set('Cookie', `${COOKIE}=eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.`);
    expect(r.status).toBe(401);
  });
});

describe('comentarios: validación y persistencia', () => {
  it('sin sesión no se puede comentar (401) y no se guarda nada', async () => {
    const r = await request(app).post('/api/restaurantes/1/comentarios').send({ texto: 'hola' });
    expect(r.status).toBe(401);
    expect(ctx.comentarios).toHaveLength(1);
  });
  it.each([
    ['vacío', ''],
    ['solo espacios', '    '],
    ['501 caracteres', 'a'.repeat(501)],
  ])('un comentario %s se rechaza (400) y no se guarda', async (_n, texto) => {
    const cookie = await iniciarSesion();
    const r = await request(app).post('/api/restaurantes/1/comentarios').set('Cookie', cookie).send({ texto });
    expect(r.status).toBe(400);
    expect(ctx.comentarios).toHaveLength(1);
  });
  it('rechaza un tipo incorrecto en el texto (400)', async () => {
    const cookie = await iniciarSesion();
    const r = await request(app).post('/api/restaurantes/1/comentarios').set('Cookie', cookie).send({ texto: { $ne: 1 } });
    expect(r.status).toBe(400);
  });
  it('rechaza peticiones que no son JSON (415): un formulario de otro sitio no sirve', async () => {
    const cookie = await iniciarSesion();
    const r = await request(app).post('/api/restaurantes/1/comentarios').set('Cookie', cookie).type('form').send('texto=hola');
    expect(r.status).toBe(415);
    expect(ctx.comentarios).toHaveLength(1);
  });
  it('rechaza un identificador inválido (400), por ejemplo con SQL', async () => {
    const r = await request(app).get('/api/restaurantes/1%20OR%201=1/comentarios');
    expect(r.status).toBe(400);
  });
  it('un comentario válido se guarda (201) y se puede volver a consultar', async () => {
    const cookie = await iniciarSesion();
    const r = await request(app).post('/api/restaurantes/1/comentarios').set('Cookie', cookie).send({ texto: '  Excelente servicio  ' });
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ autor: 'Alondra', texto: 'Excelente servicio', propio: true });
    const lista = await request(app).get('/api/restaurantes/1/comentarios').set('Cookie', cookie);
    expect(lista.body[0]).toMatchObject({ id: r.body.id, texto: 'Excelente servicio', propio: true });
  });
  it('la lista no expone correos ni identificadores de usuario', async () => {
    const r = await request(app).get('/api/restaurantes/1/comentarios');
    expect(Object.keys(r.body[0]).sort()).toEqual(['autor', 'creado', 'id', 'propio', 'texto']);
    expect(JSON.stringify(r.body)).not.toContain('@');
  });
  it('restaurante inexistente: 404', async () => {
    expect((await request(app).get('/api/restaurantes/999')).status).toBe(404);
    expect((await request(app).get('/api/restaurantes/999/comentarios')).status).toBe(404);
  });
});

describe('comentarios: autorización por dueño', () => {
  it('no se puede editar el comentario de otra persona (403) y queda intacto', async () => {
    const cookie = await iniciarSesion('alondra@pnk.test');
    const r = await request(app).put('/api/comentarios/1').set('Cookie', cookie).send({ texto: 'cambiado' });
    expect(r.status).toBe(403);
    expect(ctx.comentarios[0]!.texto).toBe('Comentario de Bruno');
  });
  it('no se puede borrar el comentario de otra persona (403)', async () => {
    const cookie = await iniciarSesion('alondra@pnk.test');
    const r = await request(app).delete('/api/comentarios/1').set('Cookie', cookie).set('Content-Type', 'application/json');
    expect(r.status).toBe(403);
    expect(ctx.comentarios).toHaveLength(1);
  });
  it('el dueño sí puede editar y borrar su comentario', async () => {
    const cookie = await iniciarSesion('bruno@pnk.test');
    const e = await request(app).put('/api/comentarios/1').set('Cookie', cookie).send({ texto: 'Editado por Bruno' });
    expect(e.status).toBe(200);
    expect(e.body.texto).toBe('Editado por Bruno');
    const d = await request(app).delete('/api/comentarios/1').set('Cookie', cookie).set('Content-Type', 'application/json');
    expect(d.status).toBe(204);
    expect(ctx.comentarios).toHaveLength(0);
  });
});

describe('carta', () => {
  it('devuelve el restaurante con su carta', async () => {
    const r = await request(app).get('/api/restaurantes/1');
    expect(r.status).toBe(200);
    expect(r.body.cartas[0].categorias[0].items[0]).toMatchObject({ nombre: 'Lomo a lo pobre', precio: 12500 });
  });
});

describe('registro de cuentas', () => {
  const nueva = { nombre: 'Camila Pérez', email: 'Camila@Pnk.test', password: 'Una-clave-larga-1' };

  it('crea la cuenta (201), guarda solo el hash y deja la sesión iniciada', async () => {
    const r = await request(app).post('/api/auth/registro').send(nueva);
    expect(r.status).toBe(201);
    expect(r.body).toEqual({ id: 4, nombre: 'Camila Pérez', email: 'camila@pnk.test' });
    const guardada = ctx.usuarios.find((u) => u.email === 'camila@pnk.test')!;
    expect(guardada.passwordHash).toMatch(/^\$2[aby]\$12\$/);
    expect(guardada.passwordHash).not.toContain(nueva.password);
    const cookie = ([] as string[]).concat(r.headers['set-cookie'] ?? [])[0]!;
    expect(cookie).toMatch(/HttpOnly/i);
    expect(cookie).toMatch(/SameSite=Strict/i);
    const yo = await request(app).get('/api/auth/yo').set('Cookie', cookie.split(';')[0]!);
    expect(yo.body).toMatchObject({ id: 4, nombre: 'Camila Pérez' });
  });
  it('la cuenta nueva puede iniciar sesión y comentar', async () => {
    await request(app).post('/api/auth/registro').send(nueva);
    const login = await request(app).post('/api/auth/login').send({ email: 'camila@pnk.test', password: nueva.password });
    expect(login.status).toBe(200);
    const cookie = ([] as string[]).concat(login.headers['set-cookie'] ?? [])[0]!.split(';')[0]!;
    const c = await request(app).post('/api/restaurantes/1/comentarios').set('Cookie', cookie).send({ texto: 'Primera visita' });
    expect(c.status).toBe(201);
    expect(c.body.autor).toBe('Camila Pérez');
  });
  it('un correo ya registrado responde 409 y no crea otra cuenta', async () => {
    const r = await request(app).post('/api/auth/registro').send({ ...nueva, email: 'alondra@pnk.test' });
    expect(r.status).toBe(409);
    expect(r.headers['set-cookie']).toBeUndefined();
    expect(ctx.usuarios.filter((u) => u.email === 'alondra@pnk.test')).toHaveLength(1);
  });
  it.each([
    ['contraseña corta', { password: 'corta-1' }],
    ['contraseña de más de 72 bytes', { password: 'ñ'.repeat(37) }],
    ['contraseña con el correo', { email: 'camila@pnk.test', password: 'camila-2026-segura' }],
    ['nombre con HTML', { nombre: '<script>alert(1)</script>' }],
    ['nombre de una letra', { nombre: 'C' }],
    ['correo inválido', { email: 'camila' }],
    ['campo extra para activarse o ser admin', { admin: true }],
  ])('rechaza %s (400) y no crea la cuenta', async (_n, cambio) => {
    const antes = ctx.usuarios.length;
    const r = await request(app).post('/api/auth/registro').send({ ...nueva, ...cambio });
    expect(r.status).toBe(400);
    expect(ctx.usuarios.length).toBe(antes);
  });
  it('limita los registros por IP (429)', async () => {
    const limitada = crearApp(ctx.repo, { ...OPCIONES, maxRegistrosPorVentana: 2 });
    for (let i = 0; i < 2; i++) {
      const r = await request(limitada).post('/api/auth/registro').send({ ...nueva, email: `c${i}@pnk.test` });
      expect(r.status).toBe(201);
    }
    const r = await request(limitada).post('/api/auth/registro').send({ ...nueva, email: 'c9@pnk.test' });
    expect(r.status).toBe(429);
    expect(ctx.usuarios.some((u) => u.email === 'c9@pnk.test')).toBe(false);
  });
  it('los datos inválidos (400) no consumen intentos del límite', async () => {
    const limitada = crearApp(ctx.repo, { ...OPCIONES, maxRegistrosPorVentana: 1 });
    for (let i = 0; i < 3; i++) {
      expect((await request(limitada).post('/api/auth/registro').send({ ...nueva, password: 'corta' })).status).toBe(400);
    }
    expect((await request(limitada).post('/api/auth/registro').send(nueva)).status).toBe(201);
  });
  it('rechaza el registro enviado como formulario (415)', async () => {
    const r = await request(app).post('/api/auth/registro').type('form').send('nombre=x&email=x@x.cl&password=1234567890');
    expect(r.status).toBe(415);
  });
});
