# Evidencias — Evaluación Sumativa 2 (CI3064)

Evidencias E-01 a E-25 del informe de la Sumativa 2: capturas PNG y salidas de terminal en `.txt`,
agrupadas por carpeta. Cada `.txt` empieza con el comando que lo generó.

| Carpeta | Contiene | Evidencias |
| --- | --- | --- |
| `antes/` | Capturas y respuestas con el código recibido (PHP 8.3): errores con traza, 70 Deprecated por carga, comentario HTML renderizado, phpinfo | E-01 a E-07 |
| `despues/` | Las mismas peticiones sobre `main`: 400/404/403 controlados, carta sin avisos, HTML como texto | E-14, E-16, E-25 |
| `h01/` … `h04/` | Salida de cada batería de validación (`_resumen.txt`) y la respuesta completa de cada caso | E-13, E-15, E-17, E-18 |
| `p01/` | Cabeceras, `info.php` 404, prueba con la base detenida y el log del servidor | E-20, E-21, E-22 |
| `entorno/` | `docker compose ps`, importación del SQL, 7 tablas, phpMyAdmin pidiendo login, `setup.php` sin secretos, `.env` no versionado | E-09 a E-12 |
| `git/` | `git log --graph`, ramas, commits con hora, `git show` de cada rama y diffs por archivo | E-19, E-23, E-24 |
| `scripts/` | Scripts que generan las evidencias: línea base (`antes.sh` + `linea-base-docker/`), baterías `prueba_h0*.sh`, capturas (`shots.js`) y `despues.sh` | — |

Sanitización: la clave de la cuenta de prueba aparece como `***`. Los scripts la leen de la
variable `PNK_CLAVE_PRUEBA` y la clave de la base de `DB_PASSWORD` (ver `.env.example`).

## Reproducir

```bash
docker compose up -d                                   # entorno de la raíz del repositorio (:8080)
export DB_PASSWORD=... PNK_CLAVE_PRUEBA=...
bash evidencias/scripts/prueba_h01.sh http://127.0.0.1:8080 /tmp/h01   # una batería
```

La línea base "antes" corre el código recibido sin modificar en `:8090`
(`PNK_CODIGO_RECIBIDO=<ruta> docker compose -f evidencias/scripts/linea-base-docker/compose.yaml up -d`).
