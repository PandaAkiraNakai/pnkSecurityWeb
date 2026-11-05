#!/usr/bin/env bash
# ES3: cambia la regla SSH (22/tcp) del grupo de seguridad a la IP pública desde donde se
# ejecuta (por ejemplo, la red de la sede el día de la presentación). Quita la IP anterior:
# en todo momento hay una sola IP autorizada para SSH.
# Uso: autorizar_mi_ip.sh
set -euo pipefail
AWS="${AWS:-aws}"
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/estado.env"
export AWS_DEFAULT_REGION
NUEVA="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')/32"
[ "$NUEVA" = "$PNK_IP_SSH" ] && { echo "La regla SSH ya es para $NUEVA."; exit 0; }
"$AWS" ec2 revoke-security-group-ingress --group-id "$PNK_SG" --protocol tcp --port 22 --cidr "$PNK_IP_SSH" >/dev/null || true
"$AWS" ec2 authorize-security-group-ingress --group-id "$PNK_SG" --ip-permissions \
  "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$NUEVA,Description='SSH solo desde la IP del equipo'}]" >/dev/null
sed -i "s#^PNK_IP_SSH=.*#PNK_IP_SSH=$NUEVA#" "$DIR/estado.env"
echo "SSH autorizado solo desde $NUEVA (antes: $PNK_IP_SSH)."
