#!/usr/bin/env bash
# ES3, punto 1: la raíz web publica solo public/. Pide por HTTP archivos que NO deben
# servirse (secretos, volcado de la BD, repositorio, configuración) y recursos que SÍ.
# Uso: prueba_carpeta_publica.sh <baseURL> <dirSalida>
B="${1:?baseURL}"; O="${2:?dirSalida}"; mkdir -p "$O"
echo "== $(date '+%d/%m/%Y %H:%M') · $B =="
printf '%-34s %-6s %s\n' "Ruta" "HTTP" "Esperado"
caso() {
  local ruta="$1" esperado="$2" f="$O/$(echo "$1" | tr -c 'A-Za-z0-9._-' '_').txt"
  curl -s -k -i --path-as-is "$B/$ruta" | sed 's/\r$//' | head -c 2000 > "$f"
  printf '%-34s %-6s %s\n' "/$ruta" "$(head -1 "$f" | awk '{print $2}')" "$esperado"
}
# No deben servirse (antes de la ES3 respondían 200).
for r in .env .env.example .git/config .git/HEAD Script_BD/pnk_security.sql compose.yaml \
         Dockerfile docker/php.ini README.md evidencias/README.md setup/setup.php app/setup.php css/ vendors/; do
  caso "$r" "403/404"
done
# Sí deben servirse.
for r in "?id=1" "mostrar_carrito.php?id=1" css/style.css img/logo.png vendors/jquery/jquery-3.2.1.min.js; do
  caso "$r" "200"
done
echo "Respuestas completas (primeros 2 KB) en $O"
