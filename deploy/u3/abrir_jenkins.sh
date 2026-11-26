#!/bin/bash
# Abre Jenkins en http://localhost:8080 por un túnel SSH (el puerto 8080 no está abierto en AWS).
# Uso: deploy/u3/abrir_jenkins.sh      (Ctrl+C cierra el túnel)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/estado.env"
K="$HOME/.ssh/pnk-u3.pem"
ADMIN="$HOME/.ssh/pnk-u3-jenkins-admin.txt"
echo "Jenkins:  http://localhost:8080   (usuario admin · contraseña en $ADMIN)"
echo "Frontend: http://$FRONT_IP/   (solo desde la IP autorizada: $ADMIN_IP)"
echo "Túnel abierto hacia $JENKINS_IP. Ctrl+C para cerrarlo."
exec ssh -i "$K" -o UserKnownHostsFile="$HOME/.ssh/known_hosts_pnk_u3" -o StrictHostKeyChecking=yes \
  -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -N -L 8080:127.0.0.1:8080 "ubuntu@$JENKINS_IP"
