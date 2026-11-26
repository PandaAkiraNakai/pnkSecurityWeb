# PNKSecurity

Carta digital para restaurantes: el cliente abre la carta de un local (por ejemplo con un código QR
en la mesa), revisa los platos por categoría y, si inicia sesión, deja comentarios. Es el caso de
estudio de la asignatura **Desarrollo Seguro (CI3064)**.

## Cambio de lenguaje

La aplicación se reescribió con otra tecnología:

| Capa | Antes | Ahora |
| --- | --- | --- |
| Interfaz | PHP con HTML y Bootstrap | **React con TypeScript** (Vite) |
| Lógica y API | PHP | **Express con TypeScript** sobre Node.js 22 LTS |
| Base de datos | MySQL | **PostgreSQL 18** con esquema versionado |

El código PHP anterior (`public/`, `app/`, `Script_BD/`) queda en el repositorio solo como referencia.

## Usuarios de prueba

| Usuario | Correo | Contraseña |
| --- | --- | --- |
| Alondra | `alondra@pnk.test` | `Pnk-Prueba-2026` |
| Bruno | `bruno@pnk.test` | `Pnk-Prueba-2026` |

Son cuentas ficticias, solo para desarrollo y demostración (en la base solo se guarda su hash bcrypt).
Con dos cuentas se prueba la autorización: Bruno no puede editar ni borrar los comentarios de Alondra.
También puedes crear tu propia cuenta con el botón **Crear cuenta** de la cabecera.

## Estructura

| Carpeta | Qué es |
| --- | --- |
| `frontend/` | Interfaz en React: carta del restaurante (`/?id=N`), inicio de sesión y comentarios |
| `backend/` | API REST en Express: validación, sesión, autorización y acceso a PostgreSQL |
| `db/migraciones/` | Esquema y datos versionados (`001_…`, `002_…`, `003_…`); se aplican en orden y una sola vez |
| `db/dev/` | Creación de las cuentas de PostgreSQL para desarrollo |
| `compose.u3.yaml` | PostgreSQL para desarrollo, publicado solo en `127.0.0.1:55432` |
| `scripts/u3/` | Pruebas de punta a punta de la API con `curl` |
| `evidencias/u3/` | Salidas de las pruebas y capturas de la interfaz |

## Levantar en desarrollo

Requisitos: Node.js 22.12 o superior y Docker (solo para PostgreSQL).

```bash
docker compose -f compose.u3.yaml up -d          # PostgreSQL con las cuentas pnk_owner y pnk_app

cd backend
cp .env.example .env                             # cambia JWT_SECRET: openssl rand -base64 48
npm ci
npm run migrar:dev                               # aplica db/migraciones con la cuenta dueña
npm run dev                                      # API en http://127.0.0.1:3000

cd ../frontend
npm ci
npm run dev                                      # http://127.0.0.1:5173 (envía /api a la API)
```

Para reiniciar la base desde cero: `docker compose -f compose.u3.yaml down -v`.

## Pruebas

| Comando | Qué prueba |
| --- | --- |
| `cd backend && npm test` | 37 pruebas de la API sin base de datos: validación, registro, login, bloqueo por intentos, cookie, autorización por dueño y datos que no se exponen |
| `cd frontend && npm test` | Validación del comentario y del registro, y formato de precios |
| `scripts/u3/avance1.sh [URL]` | Recorrido completo contra la API y PostgreSQL reales: rechazos 400, 401, 403 y 415, y persistencia de un comentario |

### Ver la base de datos

`scripts/u3/ver_bd.sh` abre [pgweb](https://github.com/sosedoff/pgweb) en http://127.0.0.1:8081: una página
para revisar tablas y hacer consultas, en **solo lectura** y accesible solo desde el mismo equipo
(necesita el binario de pgweb en `~/.local/share/pgweb/pgweb`).

## API

| Método y ruta | Sesión | Respuesta |
| --- | --- | --- |
| `GET /api/health` | No | Estado y versión desplegada |
| `POST /api/auth/registro` | No | 201 y sesión iniciada · 400 si los datos no cumplen las reglas · 409 si el correo ya existe · 429 tras 10 intentos por hora desde la misma IP |
| `POST /api/auth/login` | No | 200 y cookie de sesión · 400 · 401 · 429 tras 5 intentos fallidos (15 min) |
| `POST /api/auth/logout` · `GET /api/auth/yo` | Sí | 204 · datos de la sesión o 401 |
| `GET /api/restaurantes/:id` | No | Restaurante con su carta (solo lo visible) |
| `GET /api/restaurantes/:id/comentarios` | No | Comentarios, sin correos ni ids de usuario |
| `POST /api/restaurantes/:id/comentarios` | Sí | 201 · 400 si el texto está vacío o pasa de 500 caracteres · 401 |
| `PUT` · `DELETE /api/comentarios/:id` | Sí | Solo el autor: 200/204 · 403 para otra persona · 404 |

Los errores siempre llegan como `{"error": "mensaje"}`, sin detalles internos del servidor.

## Controles de seguridad

| Control | Dónde |
| --- | --- |
| Validación de toda entrada en el servidor (tipos, largos, formato de ids; campos extra rechazados) | `backend/src/app.ts` (zod) |
| Consultas SQL parametrizadas; ningún dato del usuario se concatena al SQL | `backend/src/repo-pg.ts` |
| Contraseñas con bcrypt (costo 12) y mismo mensaje y tiempo de respuesta si el correo no existe | `backend/src/app.ts` |
| Bloqueo de la cuenta 15 minutos tras 5 intentos fallidos | `backend/src/app.ts` |
| Registro: nombre solo con letras, contraseña de 10 caracteres a 72 bytes que no contenga el correo, campos extra rechazados (nadie puede crearse como administrador o activarse solo) y límite de intentos por IP | `backend/src/app.ts` |
| Sesión firmada (HS256, 2 h) en cookie `HttpOnly`, `SameSite=Strict` y `Secure` detrás de HTTPS | `backend/src/app.ts`, `.env` |
| Los cambios solo se aceptan como JSON (415): un formulario de otro sitio no puede enviarlos | `backend/src/app.ts` |
| Autorización por dueño: editar o borrar un comentario ajeno responde 403, comprobado también en el `WHERE` | `backend/src/app.ts`, `backend/src/repo-pg.ts` |
| Cabeceras de seguridad (CSP, nosniff, frame-ancestors) y `Cache-Control: no-store` | `backend/src/app.ts` (helmet) |
| Cuenta de aplicación con permisos mínimos: solo lectura de la carta y permisos por columna en usuarios (crear con nombre, correo y hash; nada más) y comentarios | `db/migraciones/001_esquema_inicial.sql`, `004_registro_de_usuarios.sql` |
| Migraciones con una cuenta aparte, dueña del esquema; la API no puede crear ni borrar tablas | `backend/src/migrar.ts` |
| Restricciones en la base: claves foráneas, `CHECK` de largos, precios y puntuación, correos en minúscula | `db/migraciones/001_esquema_inicial.sql` |
| React muestra los comentarios como texto (nunca HTML) y no guarda tokens: la sesión la maneja la cookie | `frontend/src/` |
| Sin secretos en el repositorio: configuración por variables de entorno (`.env.example` sin valores reales) | `backend/.env.example`, `.gitignore` |

## Créditos de las fotos

Dos fotos de la carta vienen de Wikimedia Commons y se atribuyen también en el pie de la página:
«Spinatsuppe mit Croutons» de eat.de ([CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/))
y «Restaurant on Stromboli» de kuhnmi ([CC BY 2.0](https://creativecommons.org/licenses/by/2.0/)).
Detalle y cambios realizados en [`frontend/public/imagenes/CREDITOS.md`](frontend/public/imagenes/CREDITOS.md).

## Seguridad del repositorio

El repositorio no debe contener contraseñas reales, credenciales, tokens, claves API, datos
personales reales ni secretos de servicios externos. Los valores de `compose.u3.yaml` y de
`.env.example` son solo para desarrollo local.

## Uso de Inteligencia Artificial

Se permite usar IA como apoyo para investigar, comprender código, interpretar errores y revisar
documentación. No reemplaza la comprensión del equipo: cada integrante debe poder explicar,
justificar y demostrar las decisiones implementadas.

## Importante

PNKSecurity es un entorno académico para actividades autorizadas dentro de la asignatura. Las
pruebas de seguridad se hacen solo sobre los ambientes indicados por el docente.
