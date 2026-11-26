// Cliente de la API de PNKSecurity. La sesión viaja en una cookie HttpOnly que el
// navegador envía solo (credentials: 'same-origin'); React nunca lee el token.

export interface Usuario {
  id: number;
  nombre: string;
  email: string;
}

export interface Item {
  id: number;
  nombre: string;
  descripcion: string | null;
  tiempo: string | null;
  observaciones: string | null;
  precio: number | null;
  foto: string | null;
  destacado: boolean;
  puntuacion: number | null;
}

export interface Categoria {
  id: number;
  nombre: string;
  items: Item[];
}

export interface Carta {
  id: number;
  nombre: string;
  foto: string | null;
  categorias: Categoria[];
}

export interface Restaurante {
  id: number;
  nombre: string;
  fono: string | null;
  email: string | null;
  foto: string | null;
  direccion: string | null;
  cartas: Carta[];
}

export interface Comentario {
  id: number;
  autor: string;
  texto: string;
  creado: string;
  propio: boolean;
}

export class ErrorApi extends Error {
  readonly status: number;
  readonly detalles?: unknown;

  constructor(mensaje: string, status: number, detalles?: unknown) {
    super(mensaje);
    this.name = 'ErrorApi';
    this.status = status;
    this.detalles = detalles;
  }
}

const MENSAJES_POR_ESTADO: Record<number, string> = {
  400: 'Los datos enviados no son válidos',
  401: 'Debes iniciar sesión',
  403: 'No tienes permiso para hacer esto',
  404: 'No se encontró lo que buscas',
  415: 'Formato de la petición no permitido',
  429: 'Demasiados intentos; espera un momento',
  500: 'Error del servidor; inténtalo más tarde',
};

async function pedir<T>(metodo: string, ruta: string, cuerpo?: unknown): Promise<T> {
  const opciones: RequestInit = {
    method: metodo,
    credentials: 'same-origin',
    headers: { Accept: 'application/json' },
  };
  if (metodo !== 'GET') {
    // El servidor rechaza con 415 los cambios que no son JSON (defensa contra CSRF con formularios)
    opciones.headers = { ...opciones.headers, 'Content-Type': 'application/json' };
    opciones.body = JSON.stringify(cuerpo ?? {});
  }

  let respuesta: Response;
  try {
    respuesta = await fetch(`/api${ruta}`, opciones);
  } catch {
    throw new ErrorApi('No se pudo conectar con el servidor', 0);
  }

  if (respuesta.status === 204) return undefined as T;

  let datos: unknown = null;
  const tipo = respuesta.headers.get('content-type') ?? '';
  if (tipo.includes('application/json')) {
    datos = await respuesta.json().catch(() => null);
  }

  if (!respuesta.ok) {
    const cuerpoError = (datos ?? {}) as { error?: unknown; detalles?: unknown };
    const mensaje =
      typeof cuerpoError.error === 'string' && cuerpoError.error
        ? cuerpoError.error
        : (MENSAJES_POR_ESTADO[respuesta.status] ?? `Error ${respuesta.status}`);
    throw new ErrorApi(mensaje, respuesta.status, cuerpoError.detalles);
  }
  return datos as T;
}

export const api = {
  yo: () => pedir<Usuario>('GET', '/auth/yo'),
  login: (email: string, password: string) => pedir<Usuario>('POST', '/auth/login', { email, password }),
  logout: () => pedir<void>('POST', '/auth/logout'),
  restaurante: (id: number) => pedir<Restaurante>('GET', `/restaurantes/${id}`),
  comentarios: (idRestaurante: number) => pedir<Comentario[]>('GET', `/restaurantes/${idRestaurante}/comentarios`),
  comentar: (idRestaurante: number, texto: string) =>
    pedir<Comentario>('POST', `/restaurantes/${idRestaurante}/comentarios`, { texto }),
  editarComentario: (id: number, texto: string) => pedir<Comentario>('PUT', `/comentarios/${id}`, { texto }),
  borrarComentario: (id: number) => pedir<void>('DELETE', `/comentarios/${id}`),
};

export function mensajeDeError(e: unknown): string {
  if (e instanceof ErrorApi) return e.message;
  if (e instanceof Error) return e.message;
  return 'Ocurrió un error inesperado';
}
