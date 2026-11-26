#!/bin/bash
# Balanceador de aplicaciones (ALB) con HTTPS. Se puede correr varias veces.
#   deploy/u3/balanceador.sh
# - Grupos de destino: pnk-tg-frontend (Nginx :80, estado en /healthz) y pnk-tg-backend
#   (API :3000, estado en /api/health).
# - HTTPS :443 con política TLS 1.2/1.3 y certificado autofirmado importado en ACM (el Learner Lab
#   no tiene un dominio propio para validar uno público). /api/* va al backend; el resto al frontend.
# - HTTP :80 solo redirige a HTTPS (301). Se descartan cabeceras HTTP inválidas.
set -euo pipefail
export AWS_PROFILE="${AWS_PROFILE:-academy}" AWS_REGION="${AWS_REGION:-us-east-1}" AWS_PAGER=""
DIR="$(cd "$(dirname "$0")" && pwd)"
ESTADO="$DIR/estado.env"
# shellcheck disable=SC1090
source "$ESTADO"
CERT_DIR="$HOME/.ssh/pnk-u3-alb"
log() { printf '\033[1m==>\033[0m %s\n' "$*" >&2; }
guardar() { grep -v "^$1=" "$ESTADO" > "$ESTADO.tmp" || true; echo "$1=$2" >> "$ESTADO.tmp"; mv "$ESTADO.tmp" "$ESTADO"; chmod 600 "$ESTADO"; }

grupo_destino() { # grupo_destino NOMBRE PUERTO RUTA_ESTADO INSTANCIA
  local arn
  arn=$(aws elbv2 describe-target-groups --names "$1" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)
  if [ -z "$arn" ] || [ "$arn" = None ]; then
    log "Creando el grupo de destino $1 (:$2, estado en $3)"
    arn=$(aws elbv2 create-target-group --name "$1" --protocol HTTP --port "$2" --vpc-id "$VPC" --target-type instance \
          --health-check-protocol HTTP --health-check-path "$3" --health-check-interval-seconds 15 \
          --healthy-threshold-count 2 --unhealthy-threshold-count 3 --matcher HttpCode=200 \
          --tags Key=Proyecto,Value=pnk-u3 --query 'TargetGroups[0].TargetGroupArn' --output text)
  fi
  aws elbv2 register-targets --target-group-arn "$arn" --targets "Id=$4" >/dev/null
  echo "$arn"
}
TG_FRONT=$(grupo_destino pnk-tg-frontend 80 /healthz "$FRONT")
TG_BACK=$(grupo_destino pnk-tg-backend 3000 /api/health "$BACK")
guardar TG_FRONT "$TG_FRONT"; guardar TG_BACK "$TG_BACK"

ALB=$(aws elbv2 describe-load-balancers --names pnk-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)
if [ -z "$ALB" ] || [ "$ALB" = None ]; then
  log "Creando el balanceador pnk-alb (público, us-east-1a y us-east-1b)"
  ALB=$(aws elbv2 create-load-balancer --name pnk-alb --type application --scheme internet-facing \
        --subnets "$SUB_PUB_A" "$SUB_PUB_B" --security-groups "$SG_ALB" --ip-address-type ipv4 \
        --tags Key=Name,Value=pnk-alb Key=Proyecto,Value=pnk-u3 --query 'LoadBalancers[0].LoadBalancerArn' --output text)
fi
aws elbv2 modify-load-balancer-attributes --load-balancer-arn "$ALB" \
  --attributes Key=routing.http.drop_invalid_header_fields.enabled,Value=true >/dev/null
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB" --query 'LoadBalancers[0].DNSName' --output text)
guardar ALB "$ALB"; guardar ALB_DNS "$ALB_DNS"

# Certificado autofirmado para el nombre DNS del balanceador, importado en ACM
if [ -z "${CERT_ARN:-}" ]; then
  log "Generando el certificado autofirmado para $ALB_DNS e importándolo en ACM"
  install -d -m 700 "$CERT_DIR"
  ( umask 077
    openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
      -keyout "$CERT_DIR/privada.key" -out "$CERT_DIR/certificado.pem" \
      -subj "/CN=$ALB_DNS/O=PNKSecurity" -addext "subjectAltName=DNS:$ALB_DNS" \
      -addext "keyUsage=digitalSignature,keyEncipherment" -addext "extendedKeyUsage=serverAuth" 2>/dev/null )
  CERT_ARN=$(aws acm import-certificate --certificate "fileb://$CERT_DIR/certificado.pem" \
              --private-key "fileb://$CERT_DIR/privada.key" --tags Key=Proyecto,Value=pnk-u3 \
              --query CertificateArn --output text)
  guardar CERT_ARN "$CERT_ARN"
fi

oyente() { # oyente PUERTO → ARN o vacío
  aws elbv2 describe-listeners --load-balancer-arn "$ALB" --query "Listeners[?Port==\`$1\`].ListenerArn | [0]" --output text | grep -v '^None$' || true
}
L443=$(oyente 443)
if [ -z "$L443" ]; then
  log "Creando el oyente HTTPS :443 (TLS 1.2/1.3) → frontend"
  L443=$(aws elbv2 create-listener --load-balancer-arn "$ALB" --protocol HTTPS --port 443 \
          --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 --certificates "CertificateArn=$CERT_ARN" \
          --default-actions "Type=forward,TargetGroupArn=$TG_FRONT" --query 'Listeners[0].ListenerArn' --output text)
  log "Regla: /api/* → backend"
  aws elbv2 create-rule --listener-arn "$L443" --priority 10 \
    --conditions '[{"Field":"path-pattern","PathPatternConfig":{"Values":["/api/*"]}}]' \
    --actions "Type=forward,TargetGroupArn=$TG_BACK" >/dev/null
fi
if [ -z "$(oyente 80)" ]; then
  log "Creando el oyente HTTP :80 (solo redirige a HTTPS)"
  aws elbv2 create-listener --load-balancer-arn "$ALB" --protocol HTTP --port 80 \
    --default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,StatusCode=HTTP_301}' >/dev/null
fi
guardar L443 "$L443"

log "Listo: https://$ALB_DNS/"
for tg in "$TG_FRONT" "$TG_BACK"; do
  aws elbv2 describe-target-health --target-group-arn "$tg" \
    --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output text | sed "s|^|  ${tg##*targetgroup/} |"
done
