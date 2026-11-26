// Aplica en orden los archivos de db/migraciones que todavía no se aplicaron, cada uno en su
// propia transacción, y los registra en schema_migraciones. Usa la cuenta dueña del esquema
// (DATABASE_URL_MIGRACION); la API nunca tiene permisos para cambiar el esquema.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const dir = process.env.MIGRACIONES_DIR ?? fileURLToPath(new URL('../../db/migraciones', import.meta.url));
const url = process.env.DATABASE_URL_MIGRACION;
if (!url) { console.error('Falta DATABASE_URL_MIGRACION'); process.exit(1); }

const cliente = new pg.Client({ connectionString: url });
await cliente.connect();
try {
  await cliente.query(`CREATE TABLE IF NOT EXISTS schema_migraciones (
    version varchar(100) PRIMARY KEY, aplicada timestamptz NOT NULL DEFAULT now())`);
  const hechas = new Set((await cliente.query('SELECT version FROM schema_migraciones')).rows.map((f) => f.version));
  const archivos = readdirSync(dir).filter((f) => /^\d{3}_.+\.sql$/.test(f)).sort();
  let n = 0;
  for (const archivo of archivos) {
    if (hechas.has(archivo)) continue;
    const sql = readFileSync(join(dir, archivo), 'utf8');
    await cliente.query('BEGIN');
    try {
      await cliente.query(sql);
      await cliente.query('INSERT INTO schema_migraciones (version) VALUES ($1)', [archivo]);
      await cliente.query('COMMIT');
      console.log(`aplicada ${archivo}`);
      n++;
    } catch (e) {
      await cliente.query('ROLLBACK');
      throw new Error(`Falló ${archivo}: ${(e as Error).message}`);
    }
  }
  console.log(n ? `${n} migración(es) aplicada(s)` : 'La base ya estaba al día');
} finally {
  await cliente.end();
}
