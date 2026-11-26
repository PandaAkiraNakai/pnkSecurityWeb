// Validaciones del lado del navegador: solo mejoran la experiencia del usuario.
// La API valida lo mismo en el servidor y es la que decide.

export const MAX_COMENTARIO = 500;

export function validarComentario(texto: string): string | null {
  const limpio = texto.trim();
  if (limpio.length === 0) return 'Escribe un comentario';
  if (limpio.length > MAX_COMENTARIO) return `Máximo ${MAX_COMENTARIO} caracteres`;
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
