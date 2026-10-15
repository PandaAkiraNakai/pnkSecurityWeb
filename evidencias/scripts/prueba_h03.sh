#!/usr/bin/env bash
# H-03: casos válidos e inválidos para op, iditems y pos en carrito.php.
# Uso: prueba_h03.sh <baseURL> <dirSalida>
B=$1; OUT=$2; mkdir -p "$OUT"
J=$(mktemp)
caso() { # nombre datos esperado
  local n=$1 d=$2 esp=$3 f="$OUT/$1.txt"
  { echo "\$ curl -s -i -b sesion -X POST --data '$d' '$B/carrito.php'"; curl -s -i -b "$J" -c "$J" -X POST --data "$d" "$B/carrito.php" | sed 's/\r$//'; } > "$f"
  local items; items=$(curl -s -b "$J" "$B/mostrar_carrito.php?id=1" | grep -c 'scope="row"')
  printf '%-20s %-20s HTTP %-4s carrito=%s  [esperado %s]\n' "$n" "$d" "$(grep -m1 '^HTTP/' "$f" | awk '{print $2}')" "$items" "$esp"
}
echo "== $(date '+%d/%m/%Y %H:%M') =="
caso V01_agregar_1    'op=1&iditems=1'   '200, carrito=1'
caso V02_agregar_2    'op=1&iditems=2'   '200, carrito=2'
caso I00_item_borrado 'op=1&iditems=3'   '404 (eliminado), carrito=2'
caso I01_iditems_abc  'op=1&iditems=abc' '400, carrito=2'
caso I02_iditems_0    'op=1&iditems=0'   '400, carrito=2'
caso I03_iditems_999  'op=1&iditems=999' '404, carrito=2'
caso I04_sin_iditems  'op=1'             '400, carrito=2'
caso I05_op_9         'op=9'             '400, carrito=2'
caso I06_sin_op       ''                 '400, carrito=2'
caso I07_pos_abc      'op=2&pos=abc'     '400, carrito=2'
caso V03_quitar_pos_1 'op=2&pos=1'       '200, carrito=1'
caso V04_vaciar       'op=3'             '200, carrito=0'
echo "Trazas/avisos en las respuestas: $(cat "$OUT"/*.txt | grep -cE 'Fatal error|Warning</b>|/var/www|Stack trace')"
rm -f "$J"
