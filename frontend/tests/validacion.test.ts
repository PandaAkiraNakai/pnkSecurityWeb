import { describe, expect, it } from 'vitest';
import { formatearPrecio, validarComentario, validarRegistro } from '../src/validacion';

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


describe('validarRegistro', () => {
  const base = { nombre: 'Camila Pérez', email: 'camila@pnk.test', password: 'Una-clave-larga-1', repetir: 'Una-clave-larga-1' };
  it('acepta datos válidos (con tildes y ñ en el nombre)', () => {
    expect(validarRegistro(base)).toBeNull();
    expect(validarRegistro({ ...base, nombre: 'Íñigo O’Higgins-Muñoz' })).toBeNull();
  });
  it('rechaza nombre corto o con símbolos', () => {
    expect(validarRegistro({ ...base, nombre: 'C' })).toMatch(/al menos 2/);
    expect(validarRegistro({ ...base, nombre: '<b>Hola</b>' })).toMatch(/solo puede tener letras/);
  });
  it('rechaza correo inválido', () => {
    expect(validarRegistro({ ...base, email: 'camila' })).toBe('Correo inválido');
  });
  it('rechaza contraseña corta, larga en bytes, con el correo o que no coincide', () => {
    expect(validarRegistro({ ...base, password: 'corta', repetir: 'corta' })).toMatch(/al menos 10/);
    expect(validarRegistro({ ...base, password: 'ñ'.repeat(37), repetir: 'ñ'.repeat(37) })).toMatch(/72 bytes/);
    expect(validarRegistro({ ...base, password: 'camila-2026-x', repetir: 'camila-2026-x' })).toMatch(/correo/);
    expect(validarRegistro({ ...base, repetir: 'otra-cosa-123' })).toBe('Las contraseñas no coinciden');
  });
});
