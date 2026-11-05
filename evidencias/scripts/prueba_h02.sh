#!/usr/bin/env bash
# H-02: casos válidos, inválidos y límite para el comentario (grcomentarios.php).
# Uso: prueba_h02.sh <baseURL> <dirSalida>   (requiere el contenedor pnksecurity-db-1)
B=$1; OUT=$2; mkdir -p "$OUT"
J=$(mktemp)
filas() { docker exec pnksecurity-db-1 mysql -N --default-character-set=utf8mb4 -upnk_app -p"${DB_PASSWORD:?}" pnk_security -e "SELECT COUNT(*) FROM comentarios" 2>/dev/null; }
ultimo() { docker exec pnksecurity-db-1 mysql -N --default-character-set=utf8mb4 -upnk_app -p"${DB_PASSWORD:?}" pnk_security -e "SELECT CONCAT(usuario,' | ',LEFT(REPLACE(comentario,'\n','\\\\n'),60),' | ',CHAR_LENGTH(comentario)) FROM comentarios ORDER BY Id DESC LIMIT 1" 2>/dev/null; }
printf '%-26s %-5s %-44s %-6s %s\n' "Caso" "HTTP" "Location" "Filas" "Último registro (usuario | texto | largo)"
caso() { # nombre esperado datos... (usa --data-urlencode)
  local n=$1 esp=$2; shift 2
  local antes; antes=$(filas)
  local f="$OUT/$n.txt"
  { echo "\$ curl -s -i -b sesion -X POST $(printf -- "--data-urlencode '%s' " "$@")'$B/grcomentarios.php'"
    curl -s -i -b "$J" -c "$J" -X POST "${@/#/--data-urlencode=}" "$B/grcomentarios.php" | sed 's/\r$//'; } > "$f"
  local code loc desp; code=$(grep -m1 '^HTTP/' "$f" | awk '{print $2}'); loc=$(grep -m1 '^Location:' "$f" | cut -d' ' -f2-); desp=$(filas)
  printf '%-26s %-5s %-44s %s->%-3s %s  [esperado: %s]\n' "$n" "$code" "${loc:--}" "$antes" "$desp" "$([ "$desp" != "$antes" ] && ultimo || echo 'sin cambios')" "$esp"
}
echo "== $(date '+%d/%m/%Y %H:%M') · filas iniciales: $(filas) =="
caso I01_sin_sesion     "403, no inserta" "comentario=Hola sin sesión"
# Inicio de sesión con la cuenta de prueba del script SQL (dato ficticio de laboratorio)
curl -s -o /dev/null -b "$J" -c "$J" -X POST --data-urlencode 'frmusuario=alondra@gmail.com' --data-urlencode "frmpassword=${PNK_CLAVE_PRUEBA:?defina la clave de la cuenta de prueba}" "$B/setup/procesalogin.php"
curl -s -o /dev/null -b "$J" -c "$J" "$B/?id=1"
{ echo "\$ curl -s -i -b sesion '$B/grcomentarios.php'"; curl -s -i -b "$J" -c "$J" "$B/grcomentarios.php" | sed 's/\r$//'; } > "$OUT/I02_get_con_sesion.txt"
printf '%-26s %-5s %-44s %s->%-3s %s  [esperado: %s]\n' I02_get_con_sesion "$(grep -m1 '^HTTP/' "$OUT/I02_get_con_sesion.txt" | awk '{print $2}')" - "$(filas)" "$(filas)" "sin cambios" "403 (GET), no inserta"
caso V01_texto_normal   "303 e inserta" "comentario=Muy buena atención, volveré."
caso V02_con_saltos     "303 e inserta con \\n" "comentario=Primera línea
Segunda línea"
caso V03_limite_500     "303 e inserta 500" "comentario=$(printf 'a%.0s' $(seq 1 500))"
caso V04_html_como_texto "303 e inserta literal" "comentario=<b>negrita</b><script>alert(1)</script>"
caso V05_usuario_falso  "303; usuario = sesión" "usuario=Administrador" "comentario=Intento de cambiar el nombre"
caso I03_vacio          "303 invalido, no inserta" "comentario="
caso I04_solo_espacios  "303 invalido, no inserta" "comentario=     "
caso I05_501_caracteres "303 invalido, no inserta" "comentario=$(printf 'a%.0s' $(seq 1 501))"
caso I06_control_char   "303 invalido, no inserta" "comentario=$(printf 'hola\x07mundo')"
caso I07_utf8_invalido  "303 invalido, no inserta" "comentario=$(printf 'mal\xff\xfe')"
caso I08_sin_campo      "303 invalido, no inserta" "otro=1"
echo "-- cómo se muestra V04 en la carta (codificación de salida) --"
curl -s -b "$J" "$B/?id=1" | grep -o '&lt;b&gt;[^<]*' | head -1
rm -f "$J"
