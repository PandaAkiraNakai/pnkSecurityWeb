// Validaciones del lado del navegador: solo mejoran la experiencia del usuario.
// La API valida lo mismo en el servidor y es la que decide.

export const MAX_COMENTARIO = 500;

export function validarComentario(texto: string): string | null {
  const limpio = texto.trim();
  if (limpio.length === 0) return 'Escribe un comentario';
  if (limpio.length > MAX_COMENTARIO) return `Máximo ${MAX_COMENTARIO} caracteres`;
  return null;
}

export interface DatosRegistro {
  nombre: string;
  email: string;
  password: string;
  repetir: string;
}

export const MIN_PASSWORD = 10;
const NOMBRE_VALIDO = /^\p{L}[\p{L}\p{M} '’-]*$/u;
const CORREO_VALIDO = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Devuelve el primer problema encontrado o null. Son las mismas reglas que aplica la API.
export function validarRegistro(d: DatosRegistro): string | null {
  const nombre = d.nombre.trim();
  const email = d.email.trim().toLowerCase();
  if (nombre.length < 2) return 'El nombre debe tener al menos 2 caracteres';
  if (nombre.length > 60) return 'El nombre puede tener hasta 60 caracteres';
  if (!NOMBRE_VALIDO.test(nombre)) return 'El nombre solo puede tener letras, espacios, apóstrofos y guiones';
  if (!CORREO_VALIDO.test(email) || email.length > 254) return 'Correo inválido';
  if (d.password.length < MIN_PASSWORD) return `La contraseña debe tener al menos ${MIN_PASSWORD} caracteres`;
  if (new TextEncoder().encode(d.password).length > 72) return 'La contraseña es demasiado larga (máximo 72 bytes)';
  if (!d.password.trim()) return 'La contraseña no puede ser solo espacios';
  const usuario = email.split('@')[0] ?? '';
  if (usuario.length >= 4 && d.password.toLowerCase().includes(usuario)) return 'La contraseña no puede contener tu correo';
  if (d.password !== d.repetir) return 'Las contraseñas no coinciden';
  return null;
}

const formatoCLP = new Intl.NumberFormat('es-CL', {
  style: 'currency',
  currency: 'CLP',
  maximumFractionDigits: 0,
});

export function formatearPrecio(n: number): string {
  return formatoCLP.format(n);
}

const formatoFecha = new Intl.DateTimeFormat('es-CL', {
  dateStyle: 'medium',
  timeStyle: 'short',
});

export function formatearFecha(iso: string): string {
  const fecha = new Date(iso);
  return Number.isNaN(fecha.getTime()) ? iso : formatoFecha.format(fecha);
}
