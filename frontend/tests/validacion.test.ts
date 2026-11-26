import { describe, expect, it } from 'vitest';
import { formatearPrecio, validarComentario } from '../src/validacion';

describe('validarComentario', () => {
  it('rechaza un comentario vacío', () => {
    expect(validarComentario('')).toBe('Escribe un comentario');
  });

  it('rechaza un comentario con solo espacios', () => {
    expect(validarComentario('   \n\t ')).toBe('Escribe un comentario');
  });

  it('acepta exactamente 500 caracteres', () => {
    expect(validarComentario('a'.repeat(500))).toBeNull();
  });

  it('rechaza 501 caracteres', () => {
    expect(validarComentario('a'.repeat(501))).toBe('Máximo 500 caracteres');
  });

  it('cuenta el largo después de quitar los espacios de los extremos', () => {
    expect(validarComentario(`  ${'a'.repeat(500)}  `)).toBeNull();
  });

  it('acepta un texto normal', () => {
    expect(validarComentario('Muy rico el lomo a lo pobre')).toBeNull();
  });
});

describe('formatearPrecio', () => {
  it('usa separador de miles chileno', () => {
    expect(formatearPrecio(12500)).toContain('12.500');
  });

  it('no muestra decimales', () => {
    expect(formatearPrecio(3500)).not.toMatch(/,\d/);
  });
});
