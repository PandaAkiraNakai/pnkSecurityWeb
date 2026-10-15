#!/usr/bin/env bash
# H-01: casos válidos, inválidos y límite para el parámetro id (index.php y mostrar_carrito.php).
# Uso: prueba_h01.sh <baseURL> <dirSalida>
B=$1; OUT=$2; mkdir -p "$OUT"
printf '%-34s %-6s %-9s %s\n' "Petición" "HTTP" "Traza/aviso" "Resultado observado"
caso() { # nombre url esperado
  local n=$1 u=$2 esp=$3 f="$OUT/$1.txt"
  { echo "\$ curl -s -i '$B$u'"; curl -s -i "$B$u" | sed 's/\r$//'; } > "$f"
  local code; code=$(grep -m1 '^HTTP/' "$f" | awk '{print $2}')
  local fuga; fuga=$(grep -cE 'Fatal error|Warning</b>|/var/www|Stack trace|mysqli_sql_exception' "$f")
  local res
  if   grep -q 'Error 400' "$f"; then res="página controlada 400"
  elif grep -q 'Error 404' "$f"; then res="página controlada 404"
  else res="carta: $(grep -oE '<title>[^<]*</title>' "$f" | sed 's/<[^>]*>//g' | head -1)"; fi
  printf '%-34s %-6s %-9s %s  [esperado %s]\n' "$u" "$code" "$fuga" "$res" "$esp"
}
caso V01_id_1            '/?id=1'                  200
caso V02_id_7            '/?id=7'                  200
caso V03_carrito_id_2    '/mostrar_carrito.php?id=2' 200
caso I01_sin_id          '/'                       400
caso I02_id_vacio        '/?id='                   400
caso I03_id_abc          '/?id=abc'                400
caso I04_id_0            '/?id=0'                  400
caso I05_id_negativo     '/?id=-1'                 400
caso I06_id_decimal      '/?id=1.5'                400
caso I07_id_con_texto    '/?id=1%20or%201%3D1'     400
caso I08_id_desbordado   '/?id=99999999999'        400
caso I09_id_inexistente  '/?id=999'                404
caso I10_carrito_id_abc  '/mostrar_carrito.php?id=abc' 400
caso I11_carrito_sin_id  '/mostrar_carrito.php'    400
echo "Columna Traza/aviso: cantidad de líneas con 'Fatal error', 'Warning', '/var/www', 'Stack trace' o 'mysqli_sql_exception' en la respuesta."
