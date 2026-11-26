#!/bin/bash
# Prepara la EC2 de Jenkins (se ejecuta EN el servidor como ubuntu, con sudo):
#   ssh -i ~/.ssh/pnk-u3.pem ubuntu@IP 'sudo bash -s' < deploy/u3/servidor_jenkins.sh
# Sigue la guía de laboratorio de la unidad: swap de 2 GiB, Java 21, Node.js 22 del repositorio de
# Ubuntu, Jenkins LTS del repositorio oficial con su clave, escuchando solo en 127.0.0.1 (se
# administra por túnel SSH) y con temporales en disco. Además: actualizaciones automáticas.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "== Swap de 2 GiB"
if ! swapon --show | grep -q /swapfile; then
  [ -e /swapfile ] || fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi
swapon --show

echo "== Java, Node.js y herramientas"
apt-get update -q
apt-get install -y -q fontconfig openjdk-21-jre-headless git curl wget nodejs npm rsync openssh-client unattended-upgrades >/dev/null
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
java -version 2>&1 | head -1
NODE=$(node --version); echo "node $NODE · npm $(npm --version)"
node -e 'const [a,b]=process.versions.node.split(".").map(Number); if (a<22||(a===22&&b<12)) { console.error("Se necesita Node 22.12 o superior"); process.exit(1) }'

echo "== Repositorio oficial de Jenkins (LTS)"
install -d -m 0755 /etc/apt/keyrings
wget -q -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list
apt-get update -q
apt-get install -y -q jenkins >/dev/null
systemctl stop jenkins

echo "== Ajustes para pocos recursos y acceso solo local"
mkdir -p /etc/systemd/system/jenkins.service.d
install -d -o jenkins -g jenkins -m 0700 /var/lib/jenkins/tmp
cat > /etc/systemd/system/jenkins.service.d/override.conf <<'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Xms128m -Xmx512m -Djava.io.tmpdir=/var/lib/jenkins/tmp -Djenkins.install.runSetupWizard=false"
Environment="JENKINS_OPTS=--httpListenAddress=127.0.0.1"
EOF
systemctl daemon-reload
systemctl enable jenkins >/dev/null

echo "== Herramientas para el usuario jenkins"
for c in "node --version" "npm --version" "git --version" "rsync --version" ; do
  printf '  %-16s %s\n' "$c" "$(sudo -u jenkins $c 2>&1 | head -1)"
done
echo "== Listo (Jenkins se inicia en el paso de configuración)"
