#!/usr/bin/env bash
# ES3: lleva una base creada con la versión de la Sumativa 2 (claves en texto plano, pnk_app con
# ALL PRIVILEGES, root accesible por red) al estado de la ES3, sin perder datos. Una base nueva
# ya nace así (Script_BD/); esto es solo para instalaciones existentes. Es idempotente.
# Uso (desde la raíz del repo, con el stack levantado): deploy/migrar_base_existente.sh
set -euo pipefail
DC=(docker compose)
echo "== $(date '+%d/%m/%Y %H:%M:%S %Z') · migración de la base a la ES3 =="

# Antes de tocar nada se comprueba que estén las tablas que usan los privilegios; si falta
# alguna, se aborta sin cambios (un GRANT a medias dejaría la app sin acceso).
FALTAN="$("${DC[@]}" exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -e "SELECT t FROM (SELECT '"'"'comentarios'"'"' t UNION SELECT '"'"'usuarios'"'"') x WHERE t NOT IN (SELECT table_name FROM information_schema.tables WHERE table_schema=DATABASE())" "$MYSQL_DATABASE"' 2>/dev/null)"
[ -z "$FALTAN" ] || { echo "Faltan tablas en la base: $FALTAN. No se cambió nada."; exit 1; }

echo "1) Tabla intentos_login"
"${DC[@]}" exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot' < Script_BD/zz_es3_intentos_login.sql

echo "2) Privilegios mínimos de la app y cuenta de administración (mismo script que al crear la base)"
"${DC[@]}" exec -T db bash -c 'source /usr/local/bin/docker-entrypoint.sh && docker_setup_env mysqld && source /docker-entrypoint-initdb.d/zz_es3_permisos.sh'

echo "3) root solo desde dentro del contenedor (se elimina root@'%')"
"${DC[@]}" exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "DROP USER IF EXISTS '"'"'root'"'"'@'"'"'%'"'"'; FLUSH PRIVILEGES;"'

echo "4) Contraseñas en texto plano → hash bcrypt"
"${DC[@]}" exec -T web php /var/www/app/migrar_claves.php
echo "Migración terminada."
