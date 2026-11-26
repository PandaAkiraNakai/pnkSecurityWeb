// Repositorio en memoria para las pruebas: mismo contrato que RepoPg, sin base de datos.
import bcrypt from 'bcryptjs';
import type { Comentario, Repo, Restaurante, UsuarioLogin } from '../src/repo.js';

export const CLAVE_PRUEBA = 'Clave-de-prueba-1';

export async function crearRepoMemoria() {
  const hash = await bcrypt.hash(CLAVE_PRUEBA, 4);
  const usuarios: UsuarioLogin[] = [
    { id: 1, nombre: 'Alondra', email: 'alondra@pnk.test', passwordHash: hash, activo: true, intentosFallidos: 0, bloqueadoHasta: null },
    { id: 2, nombre: 'Bruno', email: 'bruno@pnk.test', passwordHash: hash, activo: true, intentosFallidos: 0, bloqueadoHasta: null },
    { id: 3, nombre: 'Inactiva', email: 'inactiva@pnk.test', passwordHash: hash, activo: false, intentosFallidos: 0, bloqueadoHasta: null },
  ];
  const restaurante: Restaurante = {
    id: 1, nombre: 'Afríca Restobar', fono: '22334455', email: 'mail@correo.cl', foto: 'resto1.jpg', direccion: 'Avenida Argentina 951, La Serena',
    cartas: [{ id: 4, nombre: 'Principales', foto: null, categorias: [{ id: 3, nombre: 'Carnes', items: [
      { id: 5, nombre: 'Lomo a lo pobre', descripcion: 'Lomo con papas fritas', tiempo: '30 minutos', observaciones: null, precio: 12500, foto: 'item5.jpg', destacado: true, puntuacion: 5 },
    ] }] }],
  };
  const comentarios: Comentario[] = [
    { id: 1, restauranteId: 1, usuarioId: 2, autor: 'Bruno', texto: 'Comentario de Bruno', creado: new Date('2026-11-20T12:00:00Z') },
  ];
  let sig = 2;

  const repo: Repo = {
    async comprobar() {},
    async existeRestaurante(id) { return id === 1; },
    async obtenerRestaurante(id) { return id === 1 ? restaurante : null; },
    async buscarUsuarioPorEmail(email) { const u = usuarios.find((x) => x.email === email); return u ? { ...u } : null; },
    async registrarIntentoFallido(id, intentos, hasta) { const u = usuarios.find((x) => x.id === id)!; u.intentosFallidos = intentos; u.bloqueadoHasta = hasta; },
    async limpiarIntentos(id) { const u = usuarios.find((x) => x.id === id)!; u.intentosFallidos = 0; u.bloqueadoHasta = null; },
    async listarComentarios(rid) { return comentarios.filter((c) => c.restauranteId === rid).sort((a, b) => b.creado.getTime() - a.creado.getTime()); },
    async obtenerComentario(id) { return comentarios.find((c) => c.id === id) ?? null; },
    async crearComentario(rid, uid, texto) {
      const c = { id: sig++, restauranteId: rid, usuarioId: uid, autor: usuarios.find((u) => u.id === uid)!.nombre, texto, creado: new Date() };
      comentarios.push(c); return c;
    },
    async actualizarComentario(id, uid, texto) { const c = comentarios.find((x) => x.id === id && x.usuarioId === uid); if (!c) return null; c.texto = texto; return c; },
    async eliminarComentario(id, uid) { const i = comentarios.findIndex((x) => x.id === id && x.usuarioId === uid); if (i < 0) return false; comentarios.splice(i, 1); return true; },
  };
  return { repo, usuarios, comentarios };
}
