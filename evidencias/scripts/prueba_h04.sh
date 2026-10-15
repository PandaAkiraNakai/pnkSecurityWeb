#!/usr/bin/env bash
# H-04: casos válidos e inválidos del formulario de acceso (setup/procesalogin.php).
# Uso: prueba_h04.sh <baseURL> <dirSalida>
B=$1; OUT=$2; mkdir -p "$OUT"
caso() { # nombre esperado datos
  local n=$1 esp=$2 d=$3 f="$OUT/$1.txt" J; J=$(mktemp)
  { echo "\$ curl -s -i -X POST --data-urlencode '...' '$B/setup/procesalogin.php'"
    curl -s -i -c "$J" -X POST --data-urlencode "frmusuario=${d%%|*}" --data-urlencode "frmpassword=${d#*|}" "$B/setup/procesalogin.php" | sed 's/\r$//'; } > "$f"
  local code loc ses; code=$(grep -m1 '^HTTP/' "$f" | awk '{print $2}'); loc=$(grep -m1 '^Location:' "$f" | cut -d' ' -f2-)
  ses=$(curl -s -b "$J" "$B/?id=1" | grep -o 'Bienvenido: [^<]*' | head -1)
  printf '%-22s HTTP %-4s %-38s sesión: %-22s [esperado %s]\n' "$n" "$code" "${loc:--}" "${ses:-sin sesión}" "$esp"; rm -f "$J"
}
echo "== $(date '+%d/%m/%Y %H:%M') =="
caso V01_cuenta_prueba  "302, sesión Alondra"    "alondra@gmail.com|${PNK_CLAVE_PRUEBA:?defina la clave de la cuenta de prueba}"
caso I01_clave_erronea  "303 invalido, sin sesión" "alondra@gmail.com|otra-clave"
caso I02_usuario_no_email "303 invalido, sin sesión" "alondra|${PNK_CLAVE_PRUEBA:?defina la clave de la cuenta de prueba}"
caso I03_usuario_vacio  "303 invalido, sin sesión" "|${PNK_CLAVE_PRUEBA:?defina la clave de la cuenta de prueba}"
caso I04_clave_vacia    "303 invalido, sin sesión" "alondra@gmail.com|"
caso I05_usuario_con_espacios "303 invalido, sin sesión" "usuario con espacios|x"
caso I06_usuario_largo  "303 invalido, sin sesión" "$(printf 'a%.0s' $(seq 1 250))@correo.cl|x"
echo "Trazas/avisos en las respuestas: $(cat "$OUT"/*.txt | grep -cE 'Fatal error|Warning</b>|/var/www|Stack trace')"
