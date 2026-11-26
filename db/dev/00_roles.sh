#!/bin/bash
# Solo para el ambiente de desarrollo (Docker Compose): crea las dos cuentas de PostgreSQL.
#  - pnk_owner: dueña del esquema; la usa únicamente el comando de migraciones.
#  - pnk_app:   la cuenta de la API; recibe los permisos en db/migraciones/001_esquema_inicial.sql.
# En AWS se crean igual con deploy/u3/ (contraseñas generadas en el servidor, fuera del repo).
set -euo pipefail
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
CREATE ROLE pnk_owner LOGIN PASSWORD '${PNK_OWNER_PASSWORD}';
CREATE ROLE pnk_app LOGIN PASSWORD '${PNK_APP_PASSWORD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE DATABASE pnk OWNER pnk_owner;
REVOKE ALL ON DATABASE pnk FROM PUBLIC;
GRANT CONNECT ON DATABASE pnk TO pnk_app;
SQL
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname pnk <<SQL
ALTER SCHEMA public OWNER TO pnk_owner;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
SQL
