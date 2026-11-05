#!/bin/bash
# ES3: preparación y hardening de la EC2 (Ubuntu Server 24.04 LTS). Se entrega como user-data
# al crear la instancia (crear_infra.sh), así que corre una sola vez, como root, en el primer
# arranque. Registro: /var/log/pnk-servidor-inicial.log · Al terminar crea /var/lib/pnk-listo
set -euxo pipefail
exec > >(tee -a /var/log/pnk-servidor-inicial.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

# 1. Sistema al día (parches de seguridad del sistema operativo).
apt-get update
apt-get -y -o Dpkg::Options::=--force-confold full-upgrade
apt-get install -y ca-certificates curl git fail2ban unattended-upgrades

# 2. Docker Engine y el plugin compose desde el repositorio oficial de Docker (firmado).
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
# El usuario ubuntu NO se agrega al grupo docker: pertenecer a ese grupo equivale a ser root.
# Docker se usa con sudo, que queda registrado en /var/log/auth.log.

# 3. SSH: solo con clave, sin root y solo reenvío local (lo justo para el túnel de phpMyAdmin).
# El archivo empieza con 00- para que sus valores ganen a los del resto de sshd_config.d/.
cat > /etc/ssh/sshd_config.d/00-pnk-hardening.conf <<'EOF'
# ES3: hardening de SSH para pnkSecurity
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding local
AllowUsers ubuntu
EOF
sshd -t
systemctl restart ssh

# 4. fail2ban: bloquea por una hora la IP que falla 5 veces el login SSH.
cat > /etc/fail2ban/jail.d/pnk-sshd.local <<'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
systemctl enable fail2ban
systemctl restart fail2ban

# 5. Actualizaciones de seguridad automáticas del sistema operativo.
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# 6. Directorio de la app: de root y sin permisos para otros usuarios.
install -d -m 0755 -o root -g root /opt/pnksecurity

touch /var/lib/pnk-listo
echo "Servidor listo: $(date -Is)"
