// Contrato de acceso a datos. La API depende de esta interfaz, no de PostgreSQL:
// en producción se usa RepoPg (repo-pg.ts) y en las pruebas un repositorio en memoria.

export interface Item {
  id: number;
  nombre: string;
  descripcion: string | null;
  tiempo: string | null;
  observaciones: string | null;
  precio: number;
  foto: string | null;
  destacado: boolean;
  puntuacion: number;
}

export interface Categoria { id: number; nombre: string; items: Item[] }
export interface Carta { id: number; nombre: string; foto: string | null; categorias: Categoria[] }

export interface Restaurante {
  id: number;
  nombre: string;
  fono: string;
  email: string | null;
  foto: string | null;
  direccion: string;
  cartas: Carta[];
}

export interface UsuarioLogin {
  id: number;
  nombre: string;
  email: string;
  passwordHash: string;
  activo: boolean;
  intentosFallidos: number;
  bloqueadoHasta: Date | null;
}

export interface Comentario {
  id: number;
  restauranteId: number;
  usuarioId: number;
  autor: string;
  texto: string;
  creado: Date;
}

export interface Repo {
  obtenerRestaurante(id: number): Promise<Restaurante | null>;
  existeRestaurante(id: number): Promise<boolean>;
  buscarUsuarioPorEmail(email: string): Promise<UsuarioLogin | null>;
  registrarIntentoFallido(usuarioId: number, intentos: number, bloqueadoHasta: Date | null): Promise<void>;
  limpiarIntentos(usuarioId: number): Promise<void>;
  /** Crea la cuenta; devuelve null si el correo ya está registrado. */
  crearUsuario(nombre: string, email: string, passwordHash: string): Promise<{ id: number; nombre: string; email: string } | null>;
  listarComentarios(restauranteId: number): Promise<Comentario[]>;
  obtenerComentario(id: number): Promise<Comentario | null>;
  crearComentario(restauranteId: number, usuarioId: number, texto: string): Promise<Comentario>;
  /** Actualiza solo si el comentario pertenece al usuario; devuelve null si no. */
  actualizarComentario(id: number, usuarioId: number, texto: string): Promise<Comentario | null>;
  /** Borra solo si el comentario pertenece al usuario; devuelve false si no. */
  eliminarComentario(id: number, usuarioId: number): Promise<boolean>;
  comprobar(): Promise<void>;
}
