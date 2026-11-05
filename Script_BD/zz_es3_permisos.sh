# shellcheck shell=bash
# ES3: privilegios mínimos en MySQL. Lo ejecuta (con source) el entrypoint de la imagen mysql
# al crear la base, después de pnk_security.sql y zz_es3_intentos_login.sql.
#
# La imagen le da ALL PRIVILEGES sobre la base a MYSQL_USER. Aquí se le quitan y se le deja
# solo lo que el código usa (ver las consultas de public/ y app/):
#   SELECT en todas las tablas de la base       (carta, restaurante, comentarios, login)
#   INSERT en comentarios                       (grcomentarios.php)
#   UPDATE solo de la columna usuarios.password (rehash y migrar_claves.php)
#   INSERT y DELETE en intentos_login           (límite de intentos de login)
# Sin DROP, ALTER, CREATE, FILE ni GRANT: si alguien lograra una inyección SQL no podría
# borrar tablas, cambiar el nombre de un usuario ni leer archivos del servidor.
#
# phpMyAdmin usa una cuenta aparte (PNK_ADMIN_USER) con solo DML sobre la base, y root solo
# puede entrar desde dentro del contenedor (MYSQL_ROOT_HOST=localhost en compose.yaml).
# Se carga con source (sin bit de ejecución) para usar docker_process_sql y mysql_note.
APP="${MYSQL_USER:?}"; BD="${MYSQL_DATABASE:?}"
mysql_note "ES3: privilegios mínimos para '${APP}' y cuenta de administración '${PNK_ADMIN_USER:-}'"
docker_process_sql --database=mysql <<EOSQL
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '${APP}'@'%';
GRANT SELECT ON \`${BD}\`.* TO '${APP}'@'%';
GRANT INSERT ON \`${BD}\`.\`comentarios\` TO '${APP}'@'%';
GRANT UPDATE (\`password\`) ON \`${BD}\`.\`usuarios\` TO '${APP}'@'%';
GRANT INSERT, DELETE ON \`${BD}\`.\`intentos_login\` TO '${APP}'@'%';
EOSQL
if [ -n "${PNK_ADMIN_USER:-}" ] && [ -n "${PNK_ADMIN_PASSWORD:-}" ]; then
  docker_process_sql --database=mysql <<EOSQL
CREATE USER IF NOT EXISTS '${PNK_ADMIN_USER}'@'%' IDENTIFIED BY '${PNK_ADMIN_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`${BD}\`.* TO '${PNK_ADMIN_USER}'@'%';
EOSQL
fi
docker_process_sql --database=mysql <<<"FLUSH PRIVILEGES;"
