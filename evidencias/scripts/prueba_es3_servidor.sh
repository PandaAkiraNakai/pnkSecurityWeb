#!/usr/bin/env bash
# ES3: comprobaciones del lado del servidor (local o EC2). Se corre en la máquina donde está
# el stack, desde la raíz del repositorio. Respeta COMPOSE_FILE si se usa el compose de AWS.
# No imprime contraseñas: de cada clave guardada muestra solo su formato.
# Uso: [PNK_ENTORNO=local|AWS] prueba_es3_servidor.sh <dirSalida>
set -u
O="${1:?dirSalida}"; mkdir -p "$O"
DC=(docker compose)
root_sql() { "${DC[@]}" exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -t -e "$0"' "$1" 2>&1 | grep -v 'Using a password'; }
seccion() { echo; echo "## $1"; }
{
echo "== $(date '+%d/%m/%Y %H:%M:%S %Z') · entorno: ${PNK_ENTORNO:-local} =="

seccion "S01 Formato de las contraseñas guardadas (usuarios.password)"
root_sql "SELECT email, CASE WHEN password LIKE '\$2y\$%' OR password LIKE '\$argon2%' THEN CONCAT(LEFT(password,7),'… (hash, ',LENGTH(password),' caracteres)') ELSE CONCAT('TEXTO PLANO (',LENGTH(password),' caracteres)') END AS formato FROM pnk_security.usuarios"

seccion "S02 Privilegios del usuario de la aplicación"
APP="$("${DC[@]}" exec -T db sh -c 'echo "$MYSQL_USER"' | tr -d '\r')"
root_sql "SHOW GRANTS FOR '$APP'@'%'"

seccion "S03 Cuentas de MySQL y desde dónde pueden entrar"
root_sql "SELECT user, host FROM mysql.user WHERE user NOT LIKE 'mysql.%' ORDER BY user"

seccion "S04 Contenedores y puertos publicados"
"${DC[@]}" ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

seccion "S05 Puertos del proyecto en escucha en el host (22, 80, 443, 3306, 8080, 8081, 33060)"
ss -tlnH 2>/dev/null | awk '{print $4}' | grep -E ':(22|80|443|3306|8080|8081|33060)$' | sed -E 's/^100\.[0-9.]+|^\[fd7a[^]]*\]/[IP-VPN]/' | sort -u

seccion "S06 Versiones de los componentes"
echo "PHP:        $("${DC[@]}" exec -T web php -r 'echo PHP_VERSION;')"
echo "Apache:     $("${DC[@]}" exec -T web apache2 -v 2>/dev/null | head -1 | sed 's/Server version: //')"
echo "MySQL:      $("${DC[@]}" exec -T db mysqld --version | sed 's/.*Ver //')"
echo "phpMyAdmin: $("${DC[@]}" exec -T phpmyadmin sh -c 'grep -o "VERSION = .[0-9.]*" /var/www/html/libraries/classes/Version.php 2>/dev/null || echo "$VERSION"' | tr -d "'\r" | sed 's/VERSION = //')"
if "${DC[@]}" ps --services 2>/dev/null | grep -qx caddy; then
  echo "Caddy:      $("${DC[@]}" exec -T caddy caddy version | cut -d' ' -f1)"
fi
echo "Bibliotecas JS/CSS de public/vendors:"
"${DC[@]}" exec -T web sh -c 'ls /var/www/public/vendors'

seccion "S07 Permisos de los archivos de la aplicación (dentro del contenedor web)"
"${DC[@]}" exec -T web sh -c 'stat -c "%A %U:%G %n" /var/www/app /var/www/app/* /var/www/public /var/www/public/*.php /var/www/public/setup/*.php; echo "Archivos escribibles por www-data: $(find /var/www/app /var/www/public -writable -user www-data 2>/dev/null | wc -l); con permisos 777: $(find /var/www/app /var/www/public -perm -0002 | wc -l)"'

seccion "S08 Permisos del archivo de secretos en el host"
echo "$(stat -c '%A %n' .env) · dueño: $([ "$(stat -c %u .env)" = 0 ] && echo root || echo 'usuario sin privilegios (no root)')"

seccion "S09 Intentos fallidos de login registrados (si la tabla existe)"
root_sql "SELECT email, COUNT(*) AS intentos, MAX(momento) AS ultimo FROM pnk_security.intentos_login GROUP BY email" 2>&1 | head -10
} | tee "$O/servidor.txt"
