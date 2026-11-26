// Acceso a PostgreSQL. Todas las consultas van parametrizadas ($1, $2...): ningún dato del
// usuario se concatena al SQL. La conexión usa la cuenta pnk_app (permisos mínimos).
import pg from 'pg';
import type { Carta, Comentario, Repo, Restaurante, UsuarioLogin } from './repo.js';

const SQL_COMENTARIO = `
  SELECT c.id, c.restaurante_id, c.usuario_id, u.nombre AS autor, c.texto, c.creado
  FROM comentarios c JOIN usuarios u ON u.id = c.usuario_id`;

type FilaComentario = { id: number; restaurante_id: number; usuario_id: number; autor: string; texto: string; creado: Date };
const aComentario = (f: FilaComentario): Comentario => ({
  id: f.id, restauranteId: f.restaurante_id, usuarioId: f.usuario_id, autor: f.autor, texto: f.texto, creado: f.creado,
});

export class RepoPg implements Repo {
  constructor(private readonly pool: pg.Pool) {}

  static desdeUrl(url: string): RepoPg {
    const pool = new pg.Pool({ connectionString: url, max: 10, idleTimeoutMillis: 30_000, connectionTimeoutMillis: 5_000 });
    pool.on('error', (e) => console.error('[bd] error en una conexión inactiva:', e.message));
    return new RepoPg(pool);
  }

  async comprobar(): Promise<void> {
    await this.pool.query('SELECT 1');
  }

  async existeRestaurante(id: number): Promise<boolean> {
    const r = await this.pool.query('SELECT 1 FROM restaurantes WHERE id = $1 AND eliminado IS NULL', [id]);
    return (r.rowCount ?? 0) > 0;
  }

  async obtenerRestaurante(id: number): Promise<Restaurante | null> {
    const r = await this.pool.query(
      `SELECT r.id, r.nombre, r.fono, r.email, r.foto,
              d.calle || ' ' || d.numero || ', ' || d.comuna AS direccion
       FROM restaurantes r JOIN direcciones d ON d.id = r.direccion_id
       WHERE r.id = $1 AND r.eliminado IS NULL`, [id]);
    const fila = r.rows[0];
    if (!fila) return null;

    const filas = await this.pool.query(
      `SELECT ca.id AS carta_id, ca.nombre AS carta, ca.foto AS carta_foto,
              cg.id AS categoria_id, cg.nombre AS categoria,
              i.id, i.nombre, i.descripcion, i.tiempo, i.observaciones, i.precio, i.foto, i.destacado, i.puntuacion
       FROM cartas ca
       JOIN categorias cg ON cg.carta_id = ca.id AND cg.visible AND cg.eliminado IS NULL
       JOIN items i ON i.categoria_id = cg.id AND i.visible AND i.eliminado IS NULL
       WHERE ca.restaurante_id = $1 AND ca.visible AND ca.eliminado IS NULL
       ORDER BY ca.orden NULLS LAST, ca.id, cg.orden NULLS LAST, cg.id, i.orden NULLS LAST, i.id`, [id]);

    const cartas: Carta[] = [];
    for (const f of filas.rows) {
      let carta = cartas.find((c) => c.id === f.carta_id);
      if (!carta) { carta = { id: f.carta_id, nombre: f.carta, foto: f.carta_foto, categorias: [] }; cartas.push(carta); }
      let cat = carta.categorias.find((c) => c.id === f.categoria_id);
      if (!cat) { cat = { id: f.categoria_id, nombre: f.categoria, items: [] }; carta.categorias.push(cat); }
      cat.items.push({
        id: f.id, nombre: f.nombre, descripcion: f.descripcion, tiempo: f.tiempo, observaciones: f.observaciones,
        precio: f.precio, foto: f.foto, destacado: f.destacado, puntuacion: f.puntuacion,
      });
    }
    return { id: fila.id, nombre: fila.nombre, fono: fila.fono, email: fila.email, foto: fila.foto, direccion: fila.direccion, cartas };
  }

  async buscarUsuarioPorEmail(email: string): Promise<UsuarioLogin | null> {
    const r = await this.pool.query(
      `SELECT id, nombre, email, password_hash, activo, intentos_fallidos, bloqueado_hasta
       FROM usuarios WHERE email = $1`, [email]);
    const f = r.rows[0];
    if (!f) return null;
    return {
      id: f.id, nombre: f.nombre, email: f.email, passwordHash: f.password_hash, activo: f.activo,
      intentosFallidos: f.intentos_fallidos, bloqueadoHasta: f.bloqueado_hasta,
    };
  }

  async registrarIntentoFallido(usuarioId: number, intentos: number, bloqueadoHasta: Date | null): Promise<void> {
    await this.pool.query('UPDATE usuarios SET intentos_fallidos = $2, bloqueado_hasta = $3 WHERE id = $1', [usuarioId, intentos, bloqueadoHasta]);
  }

  async limpiarIntentos(usuarioId: number): Promise<void> {
    await this.pool.query('UPDATE usuarios SET intentos_fallidos = 0, bloqueado_hasta = NULL WHERE id = $1', [usuarioId]);
  }

  async crearUsuario(nombre: string, email: string, passwordHash: string) {
    // ON CONFLICT: dos registros simultáneos con el mismo correo no fallan con error 500
    const r = await this.pool.query(
      `INSERT INTO usuarios (nombre, email, password_hash) VALUES ($1, $2, $3)
       ON CONFLICT (email) DO NOTHING RETURNING id, nombre, email`, [nombre, email, passwordHash]);
    return r.rows[0] ?? null;
  }

  async listarComentarios(restauranteId: number): Promise<Comentario[]> {
    const r = await this.pool.query(`${SQL_COMENTARIO} WHERE c.restaurante_id = $1 ORDER BY c.creado DESC, c.id DESC LIMIT 100`, [restauranteId]);
    return r.rows.map(aComentario);
  }

  async obtenerComentario(id: number): Promise<Comentario | null> {
    const r = await this.pool.query(`${SQL_COMENTARIO} WHERE c.id = $1`, [id]);
    return r.rows[0] ? aComentario(r.rows[0]) : null;
  }

  async crearComentario(restauranteId: number, usuarioId: number, texto: string): Promise<Comentario> {
    const r = await this.pool.query(
      'INSERT INTO comentarios (restaurante_id, usuario_id, texto) VALUES ($1, $2, $3) RETURNING id', [restauranteId, usuarioId, texto]);
    return (await this.obtenerComentario(r.rows[0].id))!;
  }

  async actualizarComentario(id: number, usuarioId: number, texto: string): Promise<Comentario | null> {
    const r = await this.pool.query(
      'UPDATE comentarios SET texto = $3, actualizado = now() WHERE id = $1 AND usuario_id = $2', [id, usuarioId, texto]);
    return (r.rowCount ?? 0) > 0 ? this.obtenerComentario(id) : null;
  }

  async eliminarComentario(id: number, usuarioId: number): Promise<boolean> {
    const r = await this.pool.query('DELETE FROM comentarios WHERE id = $1 AND usuario_id = $2', [id, usuarioId]);
    return (r.rowCount ?? 0) > 0;
  }
}
