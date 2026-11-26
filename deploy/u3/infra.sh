#!/bin/bash
# PNKSecurity · infraestructura en AWS (Learner Lab, us-east-1). Se puede correr varias veces:
# busca cada recurso por su etiqueta Name y solo crea lo que falta.
#
#   deploy/u3/infra.sh            crea o completa la red, los grupos de seguridad y las EC2
#   ADMIN_IP=1.2.3.4 deploy/u3/infra.sh   fija la IP de administración (por defecto, la IP pública actual)
#
# Red (VPC propia 10.30.0.0/16):
#   pnk-publica-a 10.30.1.0/24 (us-east-1a) y pnk-publica-b 10.30.2.0/24 (us-east-1b): con salida a Internet.
#   pnk-privada-a 10.30.11.0/24 y pnk-privada-b 10.30.12.0/24: sin ruta a Internet (para PostgreSQL).
# EC2 (Ubuntu Server 26.04 LTS, IMDSv2 obligatorio, disco cifrado, IP privada fija):
#   pnk-jenkins  10.30.1.10  t3.small, 20 GiB, IP elástica. Solo SSH desde ADMIN_IP; Jenkins por túnel.
#   pnk-frontend 10.30.1.20  t3.micro, 10 GiB. SSH y HTTP solo desde ADMIN_IP y desde Jenkins.
# El estado (ids) queda en deploy/u3/estado.env, que no se versiona.
set -euo pipefail
export AWS_PROFILE="${AWS_PROFILE:-academy}" AWS_REGION="${AWS_REGION:-us-east-1}" AWS_PAGER=""
DIR="$(cd "$(dirname "$0")" && pwd)"
ESTADO="$DIR/estado.env"
CLAVE_NOMBRE="pnk-u3"
CLAVE_PEM="$HOME/.ssh/pnk-u3.pem"
PROYECTO="pnk-u3"
AMI_PARAM="/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
ADMIN_IP="${ADMIN_IP:-$(curl -fsS --max-time 10 https://checkip.amazonaws.com)}"

log() { printf '\033[1m==>\033[0m %s\n' "$*" >&2; }
etiquetas() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Proyecto,Value=$PROYECTO}]"; }
guardar() { # guardar CLAVE VALOR
  touch "$ESTADO"; chmod 600 "$ESTADO"
  grep -v "^$1=" "$ESTADO" > "$ESTADO.tmp" || true
  echo "$1=$2" >> "$ESTADO.tmp"; mv "$ESTADO.tmp" "$ESTADO"
}
por_nombre() { # por_nombre describe-xxx RAIZ.ID NOMBRE [filtros extra]
  local cmd=$1 campo=$2 nombre=$3; shift 3
  aws ec2 "$cmd" --filters "Name=tag:Name,Values=$nombre" "$@" --query "$campo" --output text | grep -v '^None$' | head -n1 || true
}

log "IP de administración: $ADMIN_IP/32"

# Par de claves ------------------------------------------------------------------------------
if ! aws ec2 describe-key-pairs --key-names "$CLAVE_NOMBRE" >/dev/null 2>&1; then
  log "Creando el par de claves $CLAVE_NOMBRE → $CLAVE_PEM"
  [ -e "$CLAVE_PEM" ] && { echo "Ya existe $CLAVE_PEM pero no la clave en AWS; revisa antes de seguir" >&2; exit 1; }
  ( umask 077; aws ec2 create-key-pair --key-name "$CLAVE_NOMBRE" --key-type ed25519 \
      --tag-specifications "$(etiquetas key-pair $CLAVE_NOMBRE)" --query KeyMaterial --output text > "$CLAVE_PEM" )
fi

# VPC, Internet Gateway y tablas de rutas ----------------------------------------------------
VPC=$(por_nombre describe-vpcs 'Vpcs[0].VpcId' pnk-vpc)
if [ -z "$VPC" ]; then
  log "Creando la VPC 10.30.0.0/16"
  VPC=$(aws ec2 create-vpc --cidr-block 10.30.0.0/16 --tag-specifications "$(etiquetas vpc pnk-vpc)" --query Vpc.VpcId --output text)
  aws ec2 wait vpc-available --vpc-ids "$VPC"
  aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-hostnames
fi
guardar VPC "$VPC"

IGW=$(por_nombre describe-internet-gateways 'InternetGateways[0].InternetGatewayId' pnk-igw)
if [ -z "$IGW" ]; then
  log "Creando el Internet Gateway"
  IGW=$(aws ec2 create-internet-gateway --tag-specifications "$(etiquetas internet-gateway pnk-igw)" --query InternetGateway.InternetGatewayId --output text)
  aws ec2 attach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"
fi
guardar IGW "$IGW"

RT_PUB=$(por_nombre describe-route-tables 'RouteTables[0].RouteTableId' pnk-rutas-publicas)
if [ -z "$RT_PUB" ]; then
  log "Creando la tabla de rutas pública (0.0.0.0/0 → IGW)"
  RT_PUB=$(aws ec2 create-route-table --vpc-id "$VPC" --tag-specifications "$(etiquetas route-table pnk-rutas-publicas)" --query RouteTable.RouteTableId --output text)
  aws ec2 create-route --route-table-id "$RT_PUB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW" >/dev/null
fi
RT_PRIV=$(por_nombre describe-route-tables 'RouteTables[0].RouteTableId' pnk-rutas-privadas)
if [ -z "$RT_PRIV" ]; then
  log "Creando la tabla de rutas privada (solo tráfico interno de la VPC)"
  RT_PRIV=$(aws ec2 create-route-table --vpc-id "$VPC" --tag-specifications "$(etiquetas route-table pnk-rutas-privadas)" --query RouteTable.RouteTableId --output text)
fi

subred() { # subred NOMBRE CIDR ZONA TABLA publica|privada
  local id
  id=$(por_nombre describe-subnets 'Subnets[0].SubnetId' "$1")
  if [ -z "$id" ]; then
    log "Creando la subred $1 ($2, $3)"
    id=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block "$2" --availability-zone "$3" \
          --tag-specifications "$(etiquetas subnet "$1")" --query Subnet.SubnetId --output text)
    aws ec2 associate-route-table --route-table-id "$4" --subnet-id "$id" >/dev/null
    [ "$5" = publica ] && aws ec2 modify-subnet-attribute --subnet-id "$id" --map-public-ip-on-launch
  fi
  echo "$id"
}
SUB_PUB_A=$(subred pnk-publica-a 10.30.1.0/24 us-east-1a "$RT_PUB" publica)
SUB_PUB_B=$(subred pnk-publica-b 10.30.2.0/24 us-east-1b "$RT_PUB" publica)
SUB_PRIV_A=$(subred pnk-privada-a 10.30.11.0/24 us-east-1a "$RT_PRIV" privada)
SUB_PRIV_B=$(subred pnk-privada-b 10.30.12.0/24 us-east-1b "$RT_PRIV" privada)
guardar SUB_PUB_A "$SUB_PUB_A"; guardar SUB_PUB_B "$SUB_PUB_B"
guardar SUB_PRIV_A "$SUB_PRIV_A"; guardar SUB_PRIV_B "$SUB_PRIV_B"

# Grupos de seguridad -------------------------------------------------------------------------
grupo() { # grupo NOMBRE DESCRIPCION
  local id
  id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" "Name=group-name,Values=$1" \
        --query 'SecurityGroups[0].GroupId' --output text | grep -v '^None$' || true)
  if [ -z "$id" ]; then
    log "Creando el grupo de seguridad $1"
    id=$(aws ec2 create-security-group --vpc-id "$VPC" --group-name "$1" --description "$2" \
          --tag-specifications "$(etiquetas security-group "$1")" --query GroupId --output text)
  fi
  echo "$id"
}
permitir() { # permitir GRUPO PUERTO ORIGEN(cidr|sg-) DESCRIPCION — ignora si la regla ya existe
  local origen
  if [[ $3 == sg-* ]]; then origen="UserIdGroupPairs=[{GroupId=$3,Description='$4'}]"; else origen="IpRanges=[{CidrIp=$3,Description='$4'}]"; fi
  aws ec2 authorize-security-group-ingress --group-id "$1" \
    --ip-permissions "IpProtocol=tcp,FromPort=$2,ToPort=$2,$origen" >/dev/null 2>&1 || true
}
SG_JENKINS=$(grupo pnk-jenkins "Jenkins: SSH solo desde la IP de administracion")
SG_FRONT=$(grupo pnk-frontend "Frontend Nginx: HTTP y SSH desde administracion y Jenkins")
guardar SG_JENKINS "$SG_JENKINS"; guardar SG_FRONT "$SG_FRONT"
permitir "$SG_JENKINS" 22 "$ADMIN_IP/32" "SSH administracion"
permitir "$SG_FRONT" 22 "$ADMIN_IP/32" "SSH administracion"
permitir "$SG_FRONT" 22 "$SG_JENKINS" "Despliegue desde Jenkins"
permitir "$SG_FRONT" 80 "$ADMIN_IP/32" "HTTP administracion"
permitir "$SG_FRONT" 80 "$SG_JENKINS" "Comprobacion desde Jenkins"
guardar ADMIN_IP "$ADMIN_IP"

# Balanceador, backend y base de datos: cada capa solo acepta a la anterior
SG_ALB=$(grupo pnk-alb "Balanceador: HTTPS y HTTP (redirige a HTTPS) desde Internet")
SG_BACK=$(grupo pnk-backend "API Express: 3000 solo desde el balanceador; SSH desde administracion y Jenkins")
SG_BD=$(grupo pnk-bd "PostgreSQL: 5432 solo desde el backend")
guardar SG_ALB "$SG_ALB"; guardar SG_BACK "$SG_BACK"; guardar SG_BD "$SG_BD"
permitir "$SG_ALB" 443 "0.0.0.0/0" "HTTPS publico"
permitir "$SG_ALB" 80 "0.0.0.0/0" "HTTP publico (redirige a HTTPS)"
permitir "$SG_FRONT" 80 "$SG_ALB" "Trafico del balanceador"
permitir "$SG_BACK" 3000 "$SG_ALB" "Trafico del balanceador (/api)"
permitir "$SG_BACK" 22 "$ADMIN_IP/32" "SSH administracion"
permitir "$SG_BACK" 22 "$SG_JENKINS" "Despliegue desde Jenkins"
permitir "$SG_BD" 5432 "$SG_BACK" "Conexiones de la API"

# Instancias ----------------------------------------------------------------------------------
AMI=$(aws ssm get-parameter --name "$AMI_PARAM" --query Parameter.Value --output text)
instancia() { # instancia NOMBRE TIPO DISCO_GB IP_PRIVADA SG
  local id
  id=$(por_nombre describe-instances 'Reservations[0].Instances[0].InstanceId' "$1" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped")
  if [ -z "$id" ]; then
    log "Creando la EC2 $1 ($2, $3 GiB, $4)"
    id=$(aws ec2 run-instances --image-id "$AMI" --instance-type "$2" --key-name "$CLAVE_NOMBRE" \
          --subnet-id "$SUB_PUB_A" --private-ip-address "$4" --security-group-ids "$5" \
          --iam-instance-profile Name=LabInstanceProfile \
          --metadata-options "HttpTokens=required,HttpPutResponseHopLimit=1,HttpEndpoint=enabled" \
          --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$3,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}" \
          --tag-specifications "$(etiquetas instance "$1")" "$(etiquetas volume "$1")" \
          --query 'Instances[0].InstanceId' --output text)
  fi
  echo "$id"
}
JENKINS=$(instancia pnk-jenkins t3.small 20 10.30.1.10 "$SG_JENKINS")
FRONT=$(instancia pnk-frontend t3.micro 10 10.30.1.20 "$SG_FRONT")
BACK=$(instancia pnk-backend t3.micro 10 10.30.1.30 "$SG_BACK")
guardar JENKINS "$JENKINS"; guardar FRONT "$FRONT"; guardar BACK "$BACK"
log "Esperando que las EC2 estén en ejecución"
aws ec2 wait instance-running --instance-ids "$JENKINS" "$FRONT" "$BACK"

# IP elástica para Jenkins (la IP pública del laboratorio cambia al detenerlo)
EIP_ALLOC=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=pnk-jenkins" --query 'Addresses[0].AllocationId' --output text | grep -v '^None$' || true)
if [ -z "$EIP_ALLOC" ]; then
  log "Asignando una IP elástica a Jenkins"
  EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --tag-specifications "$(etiquetas elastic-ip pnk-jenkins)" --query AllocationId --output text)
fi
aws ec2 associate-address --allocation-id "$EIP_ALLOC" --instance-id "$JENKINS" >/dev/null
JENKINS_IP=$(aws ec2 describe-addresses --allocation-ids "$EIP_ALLOC" --query 'Addresses[0].PublicIp' --output text)
FRONT_IP=$(aws ec2 describe-instances --instance-ids "$FRONT" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
BACK_IP=$(aws ec2 describe-instances --instance-ids "$BACK" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
guardar JENKINS_IP "$JENKINS_IP"; guardar FRONT_IP "$FRONT_IP"; guardar BACK_IP "$BACK_IP"

# PostgreSQL en RDS: subredes privadas, sin acceso público, cifrado, respaldo diario ---------------
BD_ID=pnk-bd
BD_MAESTRA="$HOME/.ssh/pnk-u3-bd-maestra.txt"
if ! aws rds describe-db-subnet-groups --db-subnet-group-name pnk-bd-subredes >/dev/null 2>&1; then
  log "Creando el grupo de subredes privadas de la base"
  aws rds create-db-subnet-group --db-subnet-group-name pnk-bd-subredes \
    --db-subnet-group-description "Subredes privadas de PNKSecurity (sin ruta a Internet)" \
    --subnet-ids "$SUB_PRIV_A" "$SUB_PRIV_B" --tags Key=Proyecto,Value=$PROYECTO >/dev/null
fi
if ! aws rds describe-db-instances --db-instance-identifier "$BD_ID" >/dev/null 2>&1; then
  log "Creando PostgreSQL 18 en RDS ($BD_ID, db.t3.micro); tarda unos 10 minutos"
  [ -s "$BD_MAESTRA" ] || ( umask 077; openssl rand -base64 30 | tr -d '/+=@"' | cut -c1-28 > "$BD_MAESTRA" )
  aws rds create-db-instance --db-instance-identifier "$BD_ID" --engine postgres --engine-version 18.7 \
    --db-instance-class db.t3.micro --allocated-storage 20 --storage-type gp3 --storage-encrypted \
    --master-username pnk_maestro --master-user-password "$(cat "$BD_MAESTRA")" \
    --db-subnet-group-name pnk-bd-subredes --vpc-security-group-ids "$SG_BD" --no-publicly-accessible \
    --backup-retention-period 1 --no-multi-az --no-auto-minor-version-upgrade \
    --enable-cloudwatch-logs-exports postgresql \
    --tags Key=Name,Value=$BD_ID Key=Proyecto,Value=$PROYECTO >/dev/null
fi

log "Listo"
cat <<EOF
  Jenkins  $JENKINS  pública $JENKINS_IP (elástica)  privada 10.30.1.10
  Frontend $FRONT  pública $FRONT_IP  privada 10.30.1.20
  Backend  $BACK  pública $BACK_IP  privada 10.30.1.30
  Base     $BD_ID (RDS, privada; ver estado con: aws rds describe-db-instances --db-instance-identifier $BD_ID)
  SSH:     ssh -i $CLAVE_PEM ubuntu@$JENKINS_IP
  Túnel:   ssh -i $CLAVE_PEM -N -L 8080:127.0.0.1:8080 ubuntu@$JENKINS_IP   → http://localhost:8080
EOF
