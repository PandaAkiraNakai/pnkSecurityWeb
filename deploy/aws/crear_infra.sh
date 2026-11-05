#!/usr/bin/env bash
# ES3: crea la infraestructura de pnkSecurity en AWS (Learner Lab de AWS Academy) con la AWS CLI.
#   - Par de claves SSH ed25519 (la privada queda en ~/.ssh/pnk-es3.pem, modo 600).
#   - Grupo de seguridad: 443 y 80 desde internet; 22 SOLO desde la IP pública de quien ejecuta
#     el script. Sin 3306 (MySQL), 8080 (app) ni 8081 (phpMyAdmin).
#   - EC2 t3.small con Ubuntu 24.04 LTS, disco gp3 cifrado, IMDSv2 obligatorio y user-data de
#     hardening (servidor_inicial.sh).
#   - IP elástica, para que el enlace no cambie si la instancia se reinicia.
# Uso: crear_infra.sh            (requiere credenciales de AWS válidas en el entorno o ~/.aws)
# El estado (ids de los recursos) queda en deploy/aws/estado.env, que no se versiona.
set -euo pipefail
AWS="${AWS:-aws}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
NOMBRE="pnk-es3"
DIR="$(cd "$(dirname "$0")" && pwd)"
ESTADO="$DIR/estado.env"
CLAVE="$HOME/.ssh/$NOMBRE.pem"
TIPO="${PNK_TIPO_INSTANCIA:-t3.small}"

echo "Cuenta: $("$AWS" sts get-caller-identity --query Account --output text) · región $AWS_DEFAULT_REGION"
MI_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')"
echo "IP autorizada para SSH: $MI_IP/32"

# Par de claves
if ! "$AWS" ec2 describe-key-pairs --key-names "$NOMBRE" >/dev/null 2>&1; then
  install -d -m 700 "$HOME/.ssh"
  ( umask 077; "$AWS" ec2 create-key-pair --key-name "$NOMBRE" --key-type ed25519 \
      --query KeyMaterial --output text > "$CLAVE" )
  echo "Clave privada guardada en $CLAVE"
fi

# Grupo de seguridad en la VPC por defecto
VPC="$("$AWS" ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)"
SG="$("$AWS" ec2 describe-security-groups --filters Name=group-name,Values="$NOMBRE-sg" Name=vpc-id,Values="$VPC" \
      --query 'SecurityGroups[0].GroupId' --output text)"
if [ "$SG" = "None" ]; then
  SG="$("$AWS" ec2 create-security-group --group-name "$NOMBRE-sg" --vpc-id "$VPC" \
        --description "pnkSecurity ES3: 443/80 publicos, 22 solo desde la IP del equipo" \
        --query GroupId --output text)"
  "$AWS" ec2 authorize-security-group-ingress --group-id "$SG" --ip-permissions \
    "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTPS}]" \
    "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description='HTTP solo para redirigir a HTTPS y validar el certificado'}]" \
    "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$MI_IP/32,Description='SSH solo desde la IP del equipo'}]" >/dev/null
fi

# Imagen oficial de Canonical (parámetro público de SSM, siempre la última de 24.04)
AMI="$("$AWS" ssm get-parameters --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
       --query 'Parameters[0].Value' --output text)"

ID="$("$AWS" ec2 describe-instances --filters Name=tag:Name,Values="$NOMBRE" Name=instance-state-name,Values=pending,running,stopped \
      --query 'Reservations[0].Instances[0].InstanceId' --output text)"
if [ "$ID" = "None" ]; then
  ID="$("$AWS" ec2 run-instances --image-id "$AMI" --instance-type "$TIPO" --key-name "$NOMBRE" \
        --security-group-ids "$SG" --user-data "file://$DIR/servidor_inicial.sh" \
        --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=20,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}' \
        --metadata-options 'HttpTokens=required,HttpEndpoint=enabled,HttpPutResponseHopLimit=1' \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NOMBRE}]" \
        --query 'Instances[0].InstanceId' --output text)"
fi
echo "Instancia $ID: esperando a que esté en ejecución…"
"$AWS" ec2 wait instance-running --instance-ids "$ID"

# IP elástica
EIP_ALLOC="$("$AWS" ec2 describe-addresses --filters Name=tag:Name,Values="$NOMBRE" --query 'Addresses[0].AllocationId' --output text)"
if [ "$EIP_ALLOC" = "None" ]; then
  EIP_ALLOC="$("$AWS" ec2 allocate-address --domain vpc \
               --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$NOMBRE}]" --query AllocationId --output text)"
fi
"$AWS" ec2 associate-address --instance-id "$ID" --allocation-id "$EIP_ALLOC" >/dev/null
IP="$("$AWS" ec2 describe-addresses --allocation-ids "$EIP_ALLOC" --query 'Addresses[0].PublicIp' --output text)"
DOMINIO="${IP//./-}.sslip.io"

cat > "$ESTADO" <<EOF
# Generado por crear_infra.sh el $(date '+%d/%m/%Y %H:%M') (no se versiona)
AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
PNK_INSTANCIA=$ID
PNK_SG=$SG
PNK_EIP_ALLOC=$EIP_ALLOC
PNK_IP=$IP
PNK_DOMINIO=$DOMINIO
PNK_CLAVE=$CLAVE
PNK_IP_SSH=$MI_IP/32
EOF
echo "Listo: $IP → https://$DOMINIO (estado en $ESTADO)"
echo "El primer arranque (actualizaciones + Docker + hardening) tarda unos minutos; luego: deploy/aws/desplegar.sh"
