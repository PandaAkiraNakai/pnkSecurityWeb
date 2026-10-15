#!/usr/bin/env bash
# Evidencia final sobre main: mismas peticiones que la línea base, baterías H-01/H-02/H-03,
# capturas, entorno y trazabilidad Git.
set -u
S=$(cd "$(dirname "$0")" && pwd)   # carpeta de los scripts
R=$(cd "$S/../.." && pwd)          # raíz del repositorio
E=$R/evidencias
B=http://127.0.0.1:8080
cd "$R"
docker exec pnksecurity-db-1 mysql -upnk_app -p"${DB_PASSWORD:?}" pnk_security -e "DELETE FROM comentarios" 2>/dev/null

echo "### Baterías de validación"
bash "$S/prueba_h01.sh" "$B" "$E/h01" > "$E/h01/_resumen.txt" 2>&1; cat "$E/h01/_resumen.txt"
bash "$S/prueba_h02.sh" "$B" "$E/h02" > "$E/h02/_resumen.txt" 2>&1; cut -c1-140 "$E/h02/_resumen.txt"
bash "$S/prueba_h03.sh" "$B" "$E/h03" > "$E/h03/_resumen.txt" 2>&1; cat "$E/h03/_resumen.txt"

echo "### Mismas peticiones que la línea base (antes → después)"
P=$(mktemp)
sed "s#http://127.0.0.1:8090#$B#" "$S/antes.sh" > "$P"
bash "$P" "$E/despues" 2>&1 | sed -n '1,16p'

echo "### Capturas"
CHROME=${CHROME:?ruta a chrome-headless-shell} \
NODE_PATH=${NODE_PATH:?node_modules con playwright} node "$S/shots.js" "$B" "$E/despues" despues login 2>&1 | grep -c png

echo "### Entorno"
mkdir -p "$E/entorno" "$E/git"
{ echo "\$ docker compose ps"; docker compose ps; } > "$E/entorno/compose_ps.txt"
{ echo "\$ docker compose exec db mysql -u\$DB_USER -p... pnk_security -e 'SHOW TABLES'"; docker exec pnksecurity-db-1 mysql -upnk_app -p"${DB_PASSWORD:?}" pnk_security -e "SHOW TABLES" 2>/dev/null; } > "$E/entorno/show_tables.txt"
{ echo "\$ docker compose logs db | grep pnk_security.sql"; docker compose logs db 2>&1 | grep -E 'pnk_security.sql|ERROR' ; } > "$E/entorno/import_sql.txt"
{ echo "\$ curl -s -i http://127.0.0.1:8081/ | grep -E 'HTTP|pma_username|pma_password'"; curl -s -i http://127.0.0.1:8081/ | sed 's/\r$//' | grep -oE 'HTTP/1.1 [0-9]+ [A-Za-z ]+|<input[^>]*name="pma_(username|password)"[^>]*>' | sort -u; } > "$E/entorno/phpmyadmin_login.txt"
{ echo "\$ grep -nE 'root|localhost|password' setup/setup.php"; grep -nE 'root|localhost|password' setup/setup.php; echo "\$ cat .gitignore"; cat .gitignore; echo "\$ git ls-files | grep -c '^.env$'   # 0 = .env no versionado"; git ls-files | grep -c '^.env$'; } > "$E/entorno/sin_secretos.txt"
cat "$E/entorno/compose_ps.txt" "$E/entorno/phpmyadmin_login.txt" "$E/entorno/sin_secretos.txt"

echo "### Git"
{ echo "\$ git log --graph --oneline --decorate --date-order"; git log --graph --oneline --decorate --date-order; } > "$E/git/log_graph.txt"
{ echo "\$ git branch -v"; git branch -v; } > "$E/git/branches.txt"
{ echo "\$ git log --format='%h %ad %s' --date=format:'%d/%m/%Y %H:%M' --no-merges --reverse"; git log --format='%h %ad %s' --date=format:'%d/%m/%Y %H:%M' --no-merges --reverse; } > "$E/git/commits.txt"
for b in chore/entorno-local fix/configuracion-db fix/carrito-php8 fix/enlace-carrito security/h-01-validacion-id security/h-02-validacion-comentario security/h-03-validacion-carrito security/p-01-config-errores chore/higiene-repositorio; do
  n=$(echo "$b" | tr '/' '_'); { echo "\$ git show --stat $b"; git show --stat "$b" | sed 's/^/    /'; } > "$E/git/show_$n.txt"
done
cat "$E/git/commits.txt"
echo "### Diffs clave"
git diff b94a01c..main -- setup/setup.php > "$E/git/diff_setup.txt"
git diff cc3bd2f..main -- grcomentarios.php > "$E/git/diff_grcomentarios.txt"
git diff cc3bd2f..main -- carrito.php > "$E/git/diff_carrito.txt"
git diff cc3bd2f..main -- index.php | head -80 > "$E/git/diff_index_inicio.txt"
git diff cc3bd2f..main -- Script_BD/pnk_security.sql > "$E/git/diff_sql.txt"
wc -l "$E"/git/diff_*.txt | tail -1
