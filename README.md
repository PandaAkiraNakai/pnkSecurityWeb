# PNKSecurity

## CI3064 — Desarrollo Seguro

PNKSecurity es una aplicación web utilizada como **caso de estudio práctico** en la asignatura **Desarrollo Seguro (CI3064)**.

Durante la Unidad 1, el sistema fue analizado desde una perspectiva DevSecOps, identificando posibles riesgos, vulnerabilidades y oportunidades de mejora.

En la **Unidad 2 — Desarrollo y Pruebas de Software Seguro**, los equipos trabajarán directamente con el código fuente de la aplicación.

---

## Objetivo del trabajo

El propósito de esta etapa es analizar una aplicación existente y aplicar progresivamente principios y buenas prácticas de desarrollo seguro.

A partir de este repositorio, cada equipo deberá comprender el funcionamiento del sistema, preparar un ambiente de ejecución controlado y posteriormente implementar y verificar mejoras de seguridad.

Durante la unidad se abordarán temas relacionados con:

* ética y conciencia de seguridad;
* ciclo de vida de desarrollo seguro;
* ISO/IEC 27034;
* validación de entradas;
* protección de datos sensibles;
* gestión de sesiones y cookies;
* amenazas y vulnerabilidades.

---

## Estado del repositorio

El repositorio contiene el código fuente base de PNKSecurity.

El ambiente de ejecución **no se entrega completamente configurado**.

Como parte del trabajo de la unidad, cada equipo deberá investigar y determinar los requerimientos necesarios para ejecutar correctamente la aplicación en un ambiente local controlado.

Esto puede implicar analizar aspectos relacionados con:

* tecnologías utilizadas;
* dependencias;
* servicios requeridos;
* base de datos;
* contenedores;
* configuración del ambiente;
* variables de entorno.

La solución adoptada deberá ser comprendida y documentada por el equipo.

---

## Forma de trabajo

Antes de realizar modificaciones importantes al código, el equipo deberá comprender el funcionamiento general de la aplicación y establecer una línea base de su estado inicial.

Durante la unidad se trabajará siguiendo el principio:

**Analizar → identificar el problema → proponer una mejora → implementar → probar → documentar evidencia.**

Las modificaciones realizadas deberán quedar registradas en el repositorio y permitir comprender la evolución del proyecto.

---

## Seguridad del repositorio

El repositorio utilizado durante el curso no debe contener información sensible.

No deben incorporarse:

* contraseñas reales;
* credenciales institucionales;
* tokens;
* claves API;
* datos personales reales;
* secretos utilizados por servicios externos.

Los equipos deberán aplicar buenas prácticas para administrar la configuración y los secretos necesarios para ejecutar el proyecto.

---

## Uso de Inteligencia Artificial

Durante el desarrollo del proyecto se permite utilizar herramientas de Inteligencia Artificial como apoyo para:

* investigar tecnologías;
* comprender código;
* interpretar errores;
* comparar alternativas;
* proponer soluciones;
* revisar documentación.

El uso de IA no reemplaza la comprensión del equipo.

Cada estudiante debe ser capaz de **explicar, justificar y demostrar técnicamente las decisiones implementadas en el proyecto**.

---

## Importante

PNKSecurity es un entorno académico utilizado exclusivamente para actividades autorizadas dentro de la asignatura.

Las pruebas de seguridad deberán realizarse únicamente sobre los ambientes indicados por el docente y respetando las condiciones establecidas durante el curso.

---

## CI3064 — Desarrollo Seguro

**Caso de estudio: PNKSecurity**

> La meta no es solamente hacer que el software funcione, sino comprender cómo desarrollarlo, probarlo y mejorarlo de forma segura.

---

## Ejecución local (entorno del equipo, Unidad 2)

Requisitos: Docker y Docker Compose. No hace falta instalar PHP ni MySQL en la máquina.

```bash
cp .env.example .env        # y reemplazar las claves de ejemplo
docker compose up -d --build
```

| Servicio | URL | Nota |
| --- | --- | --- |
| Aplicación | http://127.0.0.1:8080/?id=1 | PHP 8.5 + Apache (`Dockerfile`) |
| Base de datos | `db:3306` (solo red interna) | MySQL 8.4 LTS; importa `Script_BD/` al primer arranque |
| phpMyAdmin | http://127.0.0.1:8081 | Solo local; se entra con `DB_ADMIN_USER` (root no puede entrar por red) |

La aplicación lee la conexión a la base desde las variables `DB_HOST`, `DB_NAME`, `DB_USER` y
`DB_PASSWORD` que define `compose.yaml` a partir de `.env`. Para reiniciar la base desde cero:
`docker compose down -v`.

## Evidencias de la Sumativa 2

Las evidencias E-01 a E-25 del informe (capturas, salidas de terminal, trazabilidad Git) y los
scripts que las generan están en [`evidencias/`](evidencias/README.md).

## Sumativa 3: protección y despliegue en AWS

| Mejora | Dónde |
| --- | --- |
| Solo `public/` es la raíz web; código, secretos y volcados fuera de ella | `public/`, `app/`, `Dockerfile`, `docker/apache-pnksecurity.conf` |
| Contraseñas con `password_hash`/`password_verify` y límite de 5 intentos en 15 min | `public/setup/procesalogin.php`, `app/setup.php`, `app/migrar_claves.php` |
| Token CSRF en todos los formularios y en el carrito; cierre de sesión solo por POST | `app/setup.php`, `public/*.php`, `public/js/controladorajax.js` |
| Cabeceras de seguridad (CSP, HSTS, nosniff, X-Frame-Options…) y cookie `Secure` | `docker/apache-pnksecurity.conf`, `docker/Caddyfile`, `docker/php.ini` |
| Usuario de BD con privilegios mínimos; root solo local; cuenta aparte para phpMyAdmin | `Script_BD/zz_es3_permisos.sh`, `compose.yaml` |
| PHP 8.5, MySQL 8.4 LTS, phpMyAdmin 5.2.3, Bootstrap 5.3.8; sin jQuery ni CDN | `Dockerfile`, `compose.yaml`, `public/vendors/` |
| Despliegue en EC2 con TLS (Caddy + Let's Encrypt) y hardening | `compose.aws.yaml`, `deploy/aws/` |

Una base creada antes de la ES3 se migra con
`docker compose exec web php /var/www/app/migrar_claves.php` y
`Script_BD/zz_es3_intentos_login.sql` (ver los comentarios de cada archivo).

**Pruebas** (las mismas en local y en AWS; las claves de prueba van por variable de entorno):

```bash
PNK_CLAVE_PRUEBA=... PNK_CLAVE_ADMIN=... evidencias/scripts/prueba_es3.sh https://<dominio> salida/
evidencias/scripts/prueba_es3_servidor.sh salida/   # en el servidor, desde la raíz del repo
evidencias/scripts/prueba_es3_aws.sh salida/        # desde afuera: TLS, puertos, SSH, phpMyAdmin
```

**AWS**: `deploy/aws/crear_infra.sh` (grupo de seguridad, EC2 con hardening, IP elástica) y luego
`deploy/aws/desplegar.sh [rama]`. phpMyAdmin no tiene puerto público: se entra por túnel SSH
(`ssh -N -L 8081:127.0.0.1:8081 ubuntu@<ip>` y luego http://127.0.0.1:8081).

---

## Unidad 3: React + Express + PostgreSQL

La versión nueva convive con la de PHP en el mismo repositorio, en carpetas separadas:

| Carpeta | Qué es |
| --- | --- |
| `frontend/` | Interfaz en React con TypeScript (Vite): carta, inicio de sesión y comentarios |
| `backend/` | API en Express con TypeScript sobre Node.js 22: validación con zod, sesión en cookie HttpOnly, autorización por dueño |
| `db/migraciones/` | Esquema PostgreSQL versionado (`001_…`, `002_…`); se aplican en orden con `npm run migrar` |
| `db/dev/` | Creación de las cuentas `pnk_owner` (dueña del esquema) y `pnk_app` (la API, permisos mínimos) |
| `compose.u3.yaml` | PostgreSQL 18 para desarrollo, publicado solo en `127.0.0.1:55432` |
| `scripts/u3/` | Pruebas de punta a punta con `curl` |
| `evidencias/u3/` | Salidas y capturas de cada avance |

### Levantar en desarrollo

```bash
docker compose -f compose.u3.yaml up -d          # PostgreSQL con las dos cuentas
cd backend && cp .env.example .env               # cambia JWT_SECRET: openssl rand -base64 48
npm ci && npm run migrar:dev && npm run dev      # API en http://127.0.0.1:3000
cd ../frontend && npm ci && npm run dev          # React en http://127.0.0.1:5173 (proxy de /api)
```

Pruebas: `npm test` en `backend/` (24 pruebas de validación, sesión y autorización, sin base de datos) y en
`frontend/`. De punta a punta contra la base real: `scripts/u3/avance1.sh`.

### Cuentas de prueba

Ficticias, solo para desarrollo y la demostración: `alondra@pnk.test` y `bruno@pnk.test`, ambas con la
contraseña `Pnk-Prueba-2026`. En la base solo se guarda su hash bcrypt.

### API

| Método y ruta | Sesión | Respuesta |
| --- | --- | --- |
| `GET /api/health` | No | Estado y versión desplegada |
| `POST /api/auth/login` | No | 200 y cookie de sesión · 400 · 401 · 429 tras 5 intentos fallidos (15 min) |
| `POST /api/auth/logout` · `GET /api/auth/yo` | Sí | 204 · datos de la sesión o 401 |
| `GET /api/restaurantes/:id` | No | Restaurante con su carta (solo lo visible) |
| `GET /api/restaurantes/:id/comentarios` | No | Comentarios, sin correos ni ids de usuario |
| `POST /api/restaurantes/:id/comentarios` | Sí | 201 · 400 si el texto está vacío o pasa de 500 caracteres · 401 |
| `PUT` · `DELETE /api/comentarios/:id` | Sí | Solo el autor: 200/204 · 403 para otra persona · 404 |

Los cambios solo se aceptan como `application/json` (415 en otro caso), lo que junto con la cookie
`SameSite=Strict` impide enviarlos desde un formulario de otro sitio.
