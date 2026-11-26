#!/bin/bash
# Abre pgweb, una página web para revisar la base de desarrollo (equivale al phpMyAdmin de antes).
#  - Solo lectura (--readonly): se pueden ver tablas y hacer SELECT, no modificar.
#  - Solo desde este equipo: escucha en 127.0.0.1:8081.
# Requiere el binario de pgweb (https://github.com/sosedoff/pgweb) en ~/.local/share/pgweb/pgweb
# o en la variable PGWEB. Las credenciales son las de desarrollo de compose.u3.yaml.
set -euo pipefail
PGWEB="${PGWEB:-$HOME/.local/share/pgweb/pgweb}"
[ -x "$PGWEB" ] || { echo "No encuentro pgweb en $PGWEB" >&2; exit 1; }
echo "Base de datos en http://127.0.0.1:8081 (solo lectura). Ctrl+C para cerrar."
exec "$PGWEB" --bind 127.0.0.1 --listen 8081 --readonly --skip-open \
  --url "postgres://pnk_owner:dev-solo-local-owner@127.0.0.1:55432/pnk?sslmode=disable"
