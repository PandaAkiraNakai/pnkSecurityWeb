// API de PNKSecurity. Controles: validación de entradas en el servidor (zod), sesión firmada en
// cookie HttpOnly + SameSite=Strict, cambios solo con JSON (bloquea formularios de otro sitio),
// autorización por dueño del recurso, bloqueo por intentos de login, cabeceras con helmet y
// errores sin detalles internos.
import express, { type NextFunction, type Request, type Response } from 'express';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { randomBytes } from 'node:crypto';
import type { Comentario, Repo } from './repo.js';

export interface Opciones {
  jwtSecret: string;
  cookieSecure: boolean;
  trustProxy?: number;
  version?: string;
  ahora?: () => Date;
}

export const COOKIE = 'pnk_sesion';
export const MAX_INTENTOS = 5;
export const MINUTOS_BLOQUEO = 15;
const DURACION_SESION_S = 2 * 60 * 60;
// Hash de relleno: si el correo no existe se compara igual, para no revelar qué cuentas existen por el tiempo de respuesta
const HASH_RELLENO = bcrypt.hashSync(randomBytes(16).toString('hex'), 12);

interface Sesion { id: number; nombre: string }
type Req = Request & { usuario?: Sesion };

class ErrorHttp extends Error {
  constructor(readonly status: number, mensaje: string, readonly detalles?: unknown) { super(mensaje); }
}

// Esquemas de validación -----------------------------------------------------------------
const esquemaId = z.string().regex(/^[1-9]\d{0,8}$/, 'Identificador inválido').transform(Number);
const esquemaLogin = z.object({
  email: z.string().trim().toLowerCase().max(254).pipe(z.email('Correo inválido')),
  password: z.string().min(1, 'Escribe tu contraseña').max(72, 'Contraseña demasiado larga'),
}).strict();
const esquemaComentario = z.object({
  texto: z.string('Escribe un comentario').trim().min(1, 'Escribe un comentario').max(500, 'Máximo 500 caracteres'),
}).strict();

function validar<T>(esquema: z.ZodType<T>, datos: unknown): T {
  const r = esquema.safeParse(datos);
  if (!r.success) {
    const detalles = r.error.issues.map((i) => ({ campo: i.path.join('.') || null, mensaje: i.message }));
    throw new ErrorHttp(400, detalles[0]?.mensaje ?? 'Datos inválidos', detalles);
  }
  return r.data;
}

const publico = (c: Comentario, usuario?: Sesion) => ({
  id: c.id, autor: c.autor, texto: c.texto, creado: c.creado.toISOString(), propio: usuario?.id === c.usuarioId,
});

export function crearApp(repo: Repo, op: Opciones) {
  const ahora = op.ahora ?? (() => new Date());
  const app = express();
  app.disable('x-powered-by');
  if (op.trustProxy) app.set('trust proxy', op.trustProxy);

  app.use(helmet({
    contentSecurityPolicy: { directives: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] } },
    crossOriginResourcePolicy: { policy: 'same-origin' },
  }));
  app.use((_req, res, next) => { res.setHeader('Cache-Control', 'no-store'); next(); });

  // Registro de cada petición (método, ruta, estado, duración e IP); nunca cuerpos ni cookies
  app.use((req, res, next) => {
    const t = process.hrtime.bigint();
    res.on('finish', () => {
      if (process.env.NODE_ENV === 'test') return;
      const ms = Number(process.hrtime.bigint() - t) / 1e6;
      console.log(`${new Date().toISOString()} ${req.ip} ${req.method} ${req.originalUrl.split('?')[0]} ${res.statusCode} ${ms.toFixed(1)}ms`);
    });
    next();
  });

  // Los cambios exigen Content-Type JSON: un formulario de otro sitio no puede enviarlo sin CORS
  app.use((req, _res, next) => {
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method) && !(req.headers['content-type'] ?? '').startsWith('application/json')) {
      return next(new ErrorHttp(415, 'La API solo acepta JSON'));
    }
    next();
  });
  app.use(express.json({ limit: '10kb' }));
  app.use(cookieParser());

  // Sesión: lee la cookie firmada si existe (no obliga)
  app.use((req: Req, _res, next) => {
    const token = req.cookies?.[COOKIE];
    if (token) {
      try {
        const p = jwt.verify(token, op.jwtSecret, { algorithms: ['HS256'] }) as jwt.JwtPayload;
        req.usuario = { id: Number(p.sub), nombre: String(p.nombre) };
      } catch { /* cookie vencida o alterada: se trata como sin sesión */ }
    }
    next();
  });

  const requiereSesion = (req: Req, _res: Response, next: NextFunction) => {
    if (!req.usuario) return next(new ErrorHttp(401, 'Debes iniciar sesión'));
    next();
  };

  const opcionesCookie = { httpOnly: true, secure: op.cookieSecure, sameSite: 'strict' as const, path: '/' };

  const r = express.Router();

  r.get('/health', async (_req, res) => {
    await repo.comprobar();
    res.json({ estado: 'ok', version: op.version ?? 'desarrollo' });
  });

  // Autenticación ---------------------------------------------------------------------------
  r.post('/auth/login', async (req, res) => {
    const { email, password } = validar(esquemaLogin, req.body);
    const u = await repo.buscarUsuarioPorEmail(email);
    if (u?.bloqueadoHasta && u.bloqueadoHasta > ahora()) {
      throw new ErrorHttp(429, `Cuenta bloqueada temporalmente por intentos fallidos. Intenta de nuevo en ${MINUTOS_BLOQUEO} minutos.`);
    }
    const ok = await bcrypt.compare(password, u?.passwordHash ?? HASH_RELLENO);
    if (!u || !u.activo || !ok) {
      if (u) {
        const intentos = u.intentosFallidos + 1;
        const bloquear = intentos >= MAX_INTENTOS;
        await repo.registrarIntentoFallido(u.id, bloquear ? 0 : intentos, bloquear ? new Date(ahora().getTime() + MINUTOS_BLOQUEO * 60_000) : null);
      }
      throw new ErrorHttp(401, 'Correo o contraseña incorrectos');
    }
    await repo.limpiarIntentos(u.id);
    const token = jwt.sign({ nombre: u.nombre }, op.jwtSecret, { algorithm: 'HS256', subject: String(u.id), expiresIn: DURACION_SESION_S });
    res.cookie(COOKIE, token, { ...opcionesCookie, maxAge: DURACION_SESION_S * 1000 });
    res.json({ id: u.id, nombre: u.nombre, email: u.email });
  });

  r.post('/auth/logout', (_req, res) => {
    res.clearCookie(COOKIE, opcionesCookie);
    res.status(204).end();
  });

  r.get('/auth/yo', requiereSesion, (req: Req, res) => {
    res.json({ id: req.usuario!.id, nombre: req.usuario!.nombre });
  });

  // Carta -------------------------------------------------------------------------------------
  r.get('/restaurantes/:id', async (req, res) => {
    const id = validar(esquemaId, req.params.id);
    const rest = await repo.obtenerRestaurante(id);
    if (!rest) throw new ErrorHttp(404, 'Restaurante no encontrado');
    res.json(rest);
  });

  // Comentarios ------------------------------------------------------------------------------
  r.get('/restaurantes/:id/comentarios', async (req: Req, res) => {
    const id = validar(esquemaId, req.params.id);
    if (!(await repo.existeRestaurante(id))) throw new ErrorHttp(404, 'Restaurante no encontrado');
    res.json((await repo.listarComentarios(id)).map((c) => publico(c, req.usuario)));
  });

  r.post('/restaurantes/:id/comentarios', requiereSesion, async (req: Req, res) => {
    const id = validar(esquemaId, req.params.id);
    const { texto } = validar(esquemaComentario, req.body);
    if (!(await repo.existeRestaurante(id))) throw new ErrorHttp(404, 'Restaurante no encontrado');
    const c = await repo.crearComentario(id, req.usuario!.id, texto);
    res.status(201).json(publico(c, req.usuario));
  });

  // El dueño se comprueba dos veces: aquí (para responder 403) y en el WHERE del SQL
  const comentarioPropio = async (req: Req) => {
    const id = validar(esquemaId, req.params.id);
    const c = await repo.obtenerComentario(id);
    if (!c) throw new ErrorHttp(404, 'Comentario no encontrado');
    if (c.usuarioId !== req.usuario!.id) throw new ErrorHttp(403, 'No puedes modificar comentarios de otra persona');
    return id;
  };

  r.put('/comentarios/:id', requiereSesion, async (req: Req, res) => {
    const id = await comentarioPropio(req);
    const { texto } = validar(esquemaComentario, req.body);
    const c = await repo.actualizarComentario(id, req.usuario!.id, texto);
    if (!c) throw new ErrorHttp(403, 'No puedes modificar comentarios de otra persona');
    res.json(publico(c, req.usuario));
  });

  r.delete('/comentarios/:id', requiereSesion, async (req: Req, res) => {
    const id = await comentarioPropio(req);
    if (!(await repo.eliminarComentario(id, req.usuario!.id))) throw new ErrorHttp(403, 'No puedes modificar comentarios de otra persona');
    res.status(204).end();
  });

  app.use('/api', r);
  app.use('/api', (_req, _res, next) => next(new ErrorHttp(404, 'Ruta no encontrada')));

  // Errores: al cliente solo un mensaje genérico; el detalle queda en el registro del servidor
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof ErrorHttp) {
      return res.status(err.status).json(err.detalles ? { error: err.message, detalles: err.detalles } : { error: err.message });
    }
    const e = err as { type?: string; status?: number; message?: string };
    if (e?.type === 'entity.parse.failed') return res.status(400).json({ error: 'JSON mal formado' });
    if (e?.type === 'entity.too.large') return res.status(413).json({ error: 'Petición demasiado grande' });
    console.error('[error]', e?.message ?? err);
    res.status(500).json({ error: 'Error interno del servidor' });
  });

  return app;
}
