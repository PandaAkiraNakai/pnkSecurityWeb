#!/bin/bash
# ES3: despliegue en la EC2. Lo ejecuta desplegar.sh por SSH con sudo; no se usa a mano.
# Uso: en_servidor.sh <url-repo> <rama-o-commit> <dominio>
set -euo pipefail
REPO="$1"; REF="$2"; DOMINIO="$3"
DIR=/opt/pnksecurity
test -f /var/lib/pnk-listo || { echo "El primer arranque (servidor_inicial.sh) aún no termina."; exit 1; }

if [ ! -d "$DIR/.git" ]; then git clone --quiet "$REPO" "$DIR"; fi
cd "$DIR"
git fetch --quiet --all --prune
git checkout --quiet --detach "origin/$REF" 2>/dev/null || git checkout --quiet --detach "$REF"

# Secretos: se generan aquí, en el servidor, una sola vez. Nunca salen de la EC2 ni van a Git.
if [ ! -f .env ]; then
  ( umask 077
    cat > .env <<EOT
DB_NAME=pnk_security
DB_USER=pnk_app
DB_PASSWORD=$(openssl rand -hex 24)
DB_ROOT_PASSWORD=$(openssl rand -hex 24)
DB_ADMIN_USER=pnk_admin
DB_ADMIN_PASSWORD=$(openssl rand -hex 24)
EOT
  )
fi
sed -i '/^COMPOSE_FILE=/d;/^PNK_DOMINIO=/d' .env
printf 'COMPOSE_FILE=compose.yaml:compose.aws.yaml\nPNK_DOMINIO=%s\n' "$DOMINIO" >> .env

# Permisos: todo de root; directorios 755, archivos 644 y el .env 600 (solo root lo lee).
chown -R root:root "$DIR"
find "$DIR" -path "$DIR/.git" -prune -o -type d -exec chmod 755 {} +
find "$DIR" -path "$DIR/.git" -prune -o -type f -exec chmod 644 {} +
chmod 600 .env

docker compose up -d --build --remove-orphans
docker compose ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
echo "Desplegado el commit $(git rev-parse --short HEAD) ($(git log -1 --format=%s))"
