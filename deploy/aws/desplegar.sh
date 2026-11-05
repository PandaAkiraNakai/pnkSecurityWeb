#!/usr/bin/env bash
# ES3: despliega pnkSecurity en la EC2 creada por crear_infra.sh.
# Clona el repositorio del equipo en /opt/pnksecurity, genera los secretos en el servidor,
# ajusta los permisos y levanta el stack con el compose de AWS (Caddy + TLS).
# Uso: desplegar.sh [rama-o-commit]   (por defecto main)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/estado.env"
REF="${1:-main}"
REPO="${PNK_REPO:-https://github.com/PandaAkiraNakai/pnkSecurityWeb.git}"
SSH=(ssh -i "$PNK_CLAVE" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "ubuntu@$PNK_IP")
echo "Esperando a que termine el primer arranque de $PNK_IP…"
until "${SSH[@]}" test -f /var/lib/pnk-listo 2>/dev/null; do sleep 15; done
"${SSH[@]}" sudo bash -s -- "$REPO" "$REF" "$PNK_DOMINIO" < "$DIR/en_servidor.sh"
echo "Aplicación: https://$PNK_DOMINIO/?id=1"
echo "phpMyAdmin: ssh -i $PNK_CLAVE -N -L 8081:127.0.0.1:8081 ubuntu@$PNK_IP  →  http://127.0.0.1:8081"
