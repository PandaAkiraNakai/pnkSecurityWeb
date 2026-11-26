#!/bin/bash
# Prepara la EC2 del backend (se ejecuta EN el servidor como ubuntu, con sudo). Necesita el
# endpoint de RDS y la contraseña maestra, que se pasan por variables y nunca se guardan en Git:
#   ssh ... ubuntu@IP "sudo BD_HOST=... BD_MAESTRA_ARCHIVO=/tmp/m bash -s" < deploy/u3/servidor_backend.sh
#
# - Node.js 22 (repositorio de Ubuntu), cliente de PostgreSQL, actualizaciones automáticas.
# - La API corre como servicio systemd "pnk-api" con el usuario sin privilegios pnk-api y
#   aislamiento de systemd (sin escritura en el sistema, sin /home, sin nuevos privilegios).
# - deploy: dueño de /opt/pnk/releases; solo puede reiniciar pnk-api (regla de sudo exacta).
# - Base: crea pnk_owner (migraciones) y pnk_app (API) con contraseñas aleatorias generadas aquí;
#   la conexión exige TLS y verifica el certificado de RDS (verify-full).
# - Secretos: /etc/pnk/api.env (root:pnk-api 640) y /etc/pnk/migracion.env (root:deploy 640).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
: "${BD_HOST:?Falta BD_HOST (endpoint de RDS)}"
: "${BD_MAESTRA_ARCHIVO:?Falta BD_MAESTRA_ARCHIVO}"

echo "== Paquetes"
apt-get update -q
apt-get install -y -q nodejs npm postgresql-client rsync curl unattended-upgrades >/dev/null
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
echo "node $(node --version) · npm $(npm --version) · $(psql --version)"

echo "== Usuarios y carpetas"
id pnk-api >/dev/null 2>&1 || adduser --system --group --no-create-home --home /nonexistent --shell /usr/sbin/nologin pnk-api >/dev/null
id deploy >/dev/null 2>&1 || adduser --disabled-password --gecos "" deploy >/dev/null
install -d -o deploy -g deploy -m 0700 /home/deploy/.ssh
touch /home/deploy/.ssh/authorized_keys && chown deploy:deploy /home/deploy/.ssh/authorized_keys && chmod 600 /home/deploy/.ssh/authorized_keys
install -d -o deploy -g deploy -m 0755 /opt/pnk /opt/pnk/releases
install -d -o root -g root -m 0755 /etc/pnk

echo "== Certificados de RDS (para verificar la identidad de la base)"
curl -fsS -o /etc/pnk/rds-ca.pem https://truststore.pki.rds.amazonaws.com/us-east-1/us-east-1-bundle.pem
chmod 644 /etc/pnk/rds-ca.pem

echo "== Cuentas de la base"
MAESTRA="$(cat "$BD_MAESTRA_ARCHIVO")"; shred -u "$BD_MAESTRA_ARCHIVO"
SSL="sslmode=verify-full&sslrootcert=/etc/pnk/rds-ca.pem"
generar() { openssl rand -base64 30 | tr -d '/+=@:"' | cut -c1-28; }
if [ -s /etc/pnk/api.env ]; then
  echo "   ya configuradas (se conservan las contraseñas actuales)"
else
  OWNER_PW=$(generar); APP_PW=$(generar); JWT=$(openssl rand -base64 48 | tr -d '\n')
  PGPASSWORD="$MAESTRA" psql "host=$BD_HOST port=5432 dbname=postgres user=pnk_maestro sslmode=verify-full sslrootcert=/etc/pnk/rds-ca.pem" \
    -v ON_ERROR_STOP=1 -v owner_pw="$OWNER_PW" -v app_pw="$APP_PW" <<'SQL'
SELECT format('CREATE ROLE pnk_owner LOGIN PASSWORD %L', :'owner_pw') \gexec
SELECT format('CREATE ROLE pnk_app LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE', :'app_pw') \gexec
GRANT pnk_owner TO pnk_maestro;
CREATE DATABASE pnk OWNER pnk_owner;
REVOKE ALL ON DATABASE pnk FROM PUBLIC;
GRANT CONNECT ON DATABASE pnk TO pnk_app;
SQL
  PGPASSWORD="$MAESTRA" psql "host=$BD_HOST port=5432 dbname=pnk user=pnk_maestro sslmode=verify-full sslrootcert=/etc/pnk/rds-ca.pem" \
    -v ON_ERROR_STOP=1 -c "ALTER SCHEMA public OWNER TO pnk_owner; REVOKE CREATE ON SCHEMA public FROM PUBLIC;"
  umask 027
  cat > /etc/pnk/api.env <<EOF
NODE_ENV=production
PORT=3000
HOST=0.0.0.0
DATABASE_URL=postgres://pnk_app:$APP_PW@$BD_HOST:5432/pnk?$SSL
JWT_SECRET=$JWT
COOKIE_SECURE=true
TRUST_PROXY=1
EOF
  cat > /etc/pnk/migracion.env <<EOF
DATABASE_URL_MIGRACION=postgres://pnk_owner:$OWNER_PW@$BD_HOST:5432/pnk?$SSL
EOF
  chown root:pnk-api /etc/pnk/api.env && chmod 640 /etc/pnk/api.env
  chown root:deploy /etc/pnk/migracion.env && chmod 640 /etc/pnk/migracion.env
  echo "   pnk_owner y pnk_app creadas; secretos en /etc/pnk (solo root y el usuario que los usa)"
fi

echo "== Servicio systemd pnk-api"
cat > /etc/systemd/system/pnk-api.service <<'EOF'
[Unit]
Description=PNKSecurity API (Express)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pnk-api
Group=pnk-api
WorkingDirectory=/opt/pnk/current
EnvironmentFile=/etc/pnk/api.env
ExecStart=/usr/bin/node /opt/pnk/current/dist/server.js
Restart=on-failure
RestartSec=3
# Aislamiento
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
CapabilityBoundingSet=
AmbientCapabilities=
UMask=0077

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable pnk-api >/dev/null 2>&1

echo "== Permiso exacto de deploy para reiniciar la API"
cat > /etc/sudoers.d/pnk-deploy <<'EOF'
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart pnk-api, /usr/bin/systemctl is-active pnk-api
EOF
chmod 440 /etc/sudoers.d/pnk-deploy
visudo -cf /etc/sudoers.d/pnk-deploy >/dev/null

echo "== Huella SSH del servidor"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
echo "== Listo (la API arranca con el primer despliegue de Jenkins)"
