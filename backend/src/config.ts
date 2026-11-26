// Configuración desde variables de entorno. Si falta algo crítico, la API no arranca.
import { readFileSync } from 'node:fs';

function requerida(nombre: string): string {
  const v = process.env[nombre];
  if (!v) throw new Error(`Falta la variable de entorno ${nombre}`);
  return v;
}

export function leerConfig() {
  const jwtSecret = requerida('JWT_SECRET');
  if (jwtSecret.length < 32) throw new Error('JWT_SECRET debe tener al menos 32 caracteres');
  let version = process.env.APP_VERSION;
  if (!version) {
    try { version = readFileSync(new URL('../version.txt', import.meta.url), 'utf8').trim(); } catch { version = 'desarrollo'; }
  }
  return {
    port: Number(process.env.PORT ?? 3000),
    host: process.env.HOST ?? '0.0.0.0',
    databaseUrl: requerida('DATABASE_URL'),
    jwtSecret,
    cookieSecure: process.env.COOKIE_SECURE !== 'false',
    trustProxy: Number(process.env.TRUST_PROXY ?? 0),
    version,
  };
}
