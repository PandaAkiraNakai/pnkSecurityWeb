#!/bin/bash
# Prepara la EC2 del frontend (se ejecuta EN el servidor como ubuntu, con sudo):
#   ssh -i ~/.ssh/pnk-u3.pem ubuntu@IP 'sudo bash -s' < deploy/u3/servidor_frontend.sh
# - Nginx sirve la versión publicada en /var/www/pnk/current (enlace simbólico a releases/<commit>),
#   así publicar es un cambio atómico del enlace y volver a una versión anterior es otro.
# - Usuario deploy sin sudo ni contraseña, dueño solo de /var/www/pnk; Jenkins entra con su clave.
# - Cabeceras de seguridad, sin versión de Nginx, /healthz para el balanceador.
# - Actualizaciones de seguridad automáticas.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "== Paquetes"
apt-get update -q
apt-get install -y -q nginx rsync unattended-upgrades >/dev/null
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true

echo "== Usuario deploy (sin sudo, sin contraseña)"
id deploy >/dev/null 2>&1 || adduser --disabled-password --gecos "" deploy >/dev/null
install -d -o deploy -g deploy -m 0700 /home/deploy/.ssh
touch /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys && chmod 600 /home/deploy/.ssh/authorized_keys
install -d -o deploy -g deploy -m 0755 /var/www/pnk /var/www/pnk/releases

# Página provisional hasta el primer despliegue de Jenkins
if [ ! -e /var/www/pnk/current ]; then
  install -d -o deploy -g deploy -m 0755 /var/www/pnk/releases/inicial
  echo '<!doctype html><meta charset="utf-8"><title>PNKSecurity</title><p>Esperando el primer despliegue de Jenkins.</p>' \
    > /var/www/pnk/releases/inicial/index.html
  echo "inicial" > /var/www/pnk/releases/inicial/version.txt
  chown -R deploy:deploy /var/www/pnk/releases/inicial
  ln -sfn /var/www/pnk/releases/inicial /var/www/pnk/current
  chown -h deploy:deploy /var/www/pnk/current
fi

echo "== Nginx"
cat > /etc/nginx/snippets/pnk-cabeceras.conf <<'EOF'
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
add_header Content-Security-Policy "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'self'; font-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'" always;
EOF
cat > /etc/nginx/sites-available/pnk <<'EOF'
# PNKSecurity · frontend React (archivos de Vite construidos por Jenkins)
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    server_tokens off;
    root /var/www/pnk/current;
    index index.html;
    include snippets/pnk-cabeceras.conf;

    # Comprobación de estado para el balanceador
    location = /healthz {
        access_log off;
        default_type text/plain;
        return 200 "ok\n";
    }

    # Commit publicado: siempre fresco
    location = /version.txt {
        include snippets/pnk-cabeceras.conf;
        add_header Cache-Control "no-store" always;
    }

    # Archivos con hash en el nombre: se pueden guardar en caché
    location /assets/ {
        include snippets/pnk-cabeceras.conf;
        add_header Cache-Control "public, max-age=604800, immutable" always;
        try_files $uri =404;
    }

    # La API la atiende el backend detrás del balanceador; si la petición llega aquí, no hay API
    location /api/ {
        default_type application/json;
        return 503 '{"error":"La API no está disponible en este ambiente"}';
    }

    # Rutas de la SPA (/restaurante/1, /cuenta...): todas cargan index.html
    location / {
        include snippets/pnk-cabeceras.conf;
        add_header Cache-Control "no-cache" always;
        try_files $uri $uri/ /index.html;
    }
}
EOF
rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/pnk /etc/nginx/sites-enabled/pnk
nginx -t
systemctl enable --now nginx >/dev/null
systemctl reload nginx

echo "== Huella SSH del servidor (para verificar desde Jenkins)"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
echo "== Listo: $(nginx -v 2>&1), rsync $(rsync --version | head -1 | awk '{print $3}')"
