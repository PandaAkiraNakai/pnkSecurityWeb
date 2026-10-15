#!/usr/bin/env bash
# Línea base "antes": peticiones reproducibles contra el código recibido, sin modificar.
set -u
B=http://127.0.0.1:8090
OUT="$1"; mkdir -p "$OUT"
J=$(mktemp)
req() { # nombre método url [datos]
  local n=$1 m=$2 u=$3 d=${4:-}
  {
    echo "\$ curl -s -i -X $m ${d:+--data '$d' }'$u'"
    if [ -n "$d" ]; then curl -s -i -b "$J" -c "$J" -X "$m" --data "$d" "$u"; else curl -s -i -b "$J" -c "$J" -X "$m" "$u"; fi
  } | sed -e 's/\r$//' > "$OUT/$n.txt"
  printf '%-28s %s\n' "$n" "$(grep -m1 '^HTTP/' "$OUT/$n.txt")"
}
echo "== $(date '+%d/%m/%Y %H:%M') (UTC-3) =="
req A01_get_sin_id        GET  "$B/"
req A02_get_id_1          GET  "$B/?id=1"
req A03_get_id_999        GET  "$B/?id=999"
req A04_get_id_abc        GET  "$B/?id=abc"
req A05_get_id_1_or       GET  "$B/?id=1%20or%201=1"
req A06_info_php          GET  "$B/info.php"
req A07_carrito_op1       POST "$B/carrito.php" "op=1&iditems=1"
req A08_mostrar_carrito   GET  "$B/mostrar_carrito.php?keyid=1"
req A09_coment_sin_sesion POST "$B/grcomentarios.php" "usuario=anon&comentario=hola"
# Inicio de sesión con la cuenta de prueba del script SQL (dato ficticio de laboratorio)
req A10_login             POST "$B/setup/procesalogin.php" "frmusuario=alondra@gmail.com&frmpassword=${PNK_CLAVE_PRUEBA:?defina la clave de la cuenta de prueba}"
req A11_get_id_1_sesion   GET  "$B/?id=1"
req A12_coment_html       POST "$B/grcomentarios.php" "usuario=<b>otro</b>&comentario=<i>prueba</i>%20<script>alert(1)</script>"
req A13_coment_vacio      POST "$B/grcomentarios.php" "usuario=Alondra&comentario="
req A14_get_id_1_coment   GET  "$B/?id=1"
rm -f "$J"
echo "-- resúmenes --"
echo "Encabezados /?id=1:"; sed -n '1,12p' "$OUT/A02_get_id_1.txt" | grep -E '^(HTTP|Server|X-Powered|Set-Cookie|Content-Type)'
echo "Avisos en /?id=1:"; grep -oE '<b>(Warning|Deprecated|Notice|Fatal error)</b>:[^<]*' "$OUT/A02_get_id_1.txt" | sort | uniq -c | sort -rn | head -5
echo "Título /?id=1:"; grep -o '<title>[^<]*</title>' "$OUT/A02_get_id_1.txt"
echo "GET / :"; grep -oE '(Fatal error|Uncaught)[^<]{0,160}' "$OUT/A01_get_sin_id.txt" | head -2
echo "id=abc:"; grep -oE '(Fatal error|Uncaught)[^<]{0,160}' "$OUT/A04_get_id_abc.txt" | head -2
echo "id=1 or 1=1 título:"; grep -o '<title>[^<]*</title>' "$OUT/A05_get_id_1_or.txt"
echo "carrito:"; grep -oE '(Fatal error|Uncaught)[^<]{0,200}' "$OUT/A07_carrito_op1.txt" | head -2
echo "mostrar_carrito:"; grep -oE '(Warning|Fatal error|Uncaught)[^<]{0,160}' "$OUT/A08_mostrar_carrito.txt" | head -3
echo "coment sin sesión:"; grep -oE '(Warning|Fatal error|Uncaught)[^<]{0,160}' "$OUT/A09_coment_sin_sesion.txt" | head -3
echo "login:"; grep -E '^(HTTP|Location|Set-Cookie)' "$OUT/A10_login.txt"
echo "Bienvenido:"; grep -o 'Bienvenido[^<]*' "$OUT/A11_get_id_1_sesion.txt" | head -1
echo "comentarios renderizados:"; grep -A3 'card-body' "$OUT/A14_get_id_1_coment.txt" | grep -vE 'card-body|^--|<br>|^\s*$' | sed 's/^ *//' | tail -6
