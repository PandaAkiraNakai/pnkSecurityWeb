#!/usr/bin/env bash
# ES3: elimina los recursos creados por crear_infra.sh (instancia, IP elástica, grupo de
# seguridad y par de claves). Pide confirmación porque borra la base de datos de la EC2.
set -euo pipefail
AWS="${AWS:-aws}"
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/estado.env"
export AWS_DEFAULT_REGION
read -r -p "Se eliminará $PNK_INSTANCIA ($PNK_IP) y todos sus datos. Escriba ELIMINAR para seguir: " r
[ "$r" = "ELIMINAR" ] || { echo "Cancelado."; exit 1; }
"$AWS" ec2 disassociate-address --public-ip "$PNK_IP" || true
"$AWS" ec2 terminate-instances --instance-ids "$PNK_INSTANCIA" >/dev/null
"$AWS" ec2 wait instance-terminated --instance-ids "$PNK_INSTANCIA"
"$AWS" ec2 release-address --allocation-id "$PNK_EIP_ALLOC"
"$AWS" ec2 delete-security-group --group-id "$PNK_SG"
"$AWS" ec2 delete-key-pair --key-name pnk-es3
mv "$DIR/estado.env" "$DIR/estado.env.eliminado"
echo "Recursos eliminados."
