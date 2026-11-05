#!/bin/bash
# ES3: comprobaciones del hardening del sistema operativo de la EC2. Se corre EN el servidor,
# como root (sudo), desde /opt/pnksecurity. No imprime secretos.
# Uso: sudo bash evidencias/scripts/prueba_es3_host.sh <dirSalida>
set -u
O="${1:?dirSalida}"; mkdir -p "$O"
seccion() { echo; echo "## $1"; }
{
echo "== $(date '+%d/%m/%Y %H:%M:%S %Z') · entorno: AWS EC2 =="

seccion "H01 Sistema operativo y paquetes pendientes de actualizar"
. /etc/os-release; echo "$PRETTY_NAME · kernel $(uname -r)"
apt-get -s -o Debug::NoLocking=1 upgrade 2>/dev/null | grep -c '^Inst' | sed 's/^/Paquetes pendientes: /'
echo "Actualizaciones automáticas: $(apt-config dump | grep -E 'APT::Periodic::Unattended-Upgrade ' | tr -d '";')"

seccion "H02 Configuración efectiva de SSH (sshd -T)"
sshd -T 2>/dev/null | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin|pubkeyauthentication|authenticationmethods|maxauthtries|allowtcpforwarding|x11forwarding|allowusers) '

seccion "H03 fail2ban (cárcel sshd)"
fail2ban-client status sshd 2>&1 | sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IP]/g'

seccion "H04 Puertos en escucha en el host (todas las interfaces)"
ss -tlnpH | awk '{split($6,a,"\""); print $4, a[2]}' | sort -u

seccion "H05 Permisos de la app y de los secretos"
stat -c '%A %U:%G %n' /opt/pnksecurity /opt/pnksecurity/.env /opt/pnksecurity/compose.yaml /opt/pnksecurity/app/setup.php
echo "Archivos de /opt/pnksecurity con escritura para otros usuarios: $(find /opt/pnksecurity -path /opt/pnksecurity/.git -prune -o -perm -0002 -print | wc -l)"
echo "Variables definidas en .env (sin valores): $(cut -d= -f1 /opt/pnksecurity/.env | tr '\n' ' ')"
echo "Secretos en el historial de Git del servidor: $(git -C /opt/pnksecurity log --all -p 2>/dev/null | grep -c -E '^\+DB_(ROOT_|ADMIN_)?PASSWORD=[0-9a-f]{48}')"

seccion "H06 Quién puede usar Docker sin sudo (grupo docker)"
getent group docker | cut -d: -f4 | sed 's/^$/(nadie)/'

seccion "H07 Metadatos de la instancia (IMDS) desde un contenedor"
# Con IMDSv2 obligatorio y límite de 1 salto, un contenedor no puede pedir el token de IMDS
# (y por lo tanto tampoco las credenciales del rol), aunque la app fuera comprometida.
docker compose -f /opt/pnksecurity/compose.yaml exec -T web php -r '
$c = stream_context_create(["http" => ["method" => "PUT", "timeout" => 3, "header" => "X-aws-ec2-metadata-token-ttl-seconds: 60"]]);
$t = @file_get_contents("http://169.254.169.254/latest/api/token", false, $c);
echo $t === false ? "Token IMDSv2 desde el contenedor web: rechazado (sin respuesta)\n" : "Token IMDSv2 desde el contenedor: OBTENIDO (" . strlen($t) . " bytes)\n";
$v1 = @file_get_contents("http://169.254.169.254/latest/meta-data/", false, stream_context_create(["http" => ["timeout" => 3]]));
echo $v1 === false ? "IMDSv1 (sin token): rechazado\n" : "IMDSv1: RESPONDE\n";' 2>&1
TOKEN=$(curl -s -X PUT --max-time 3 -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' http://169.254.169.254/latest/api/token)
echo "Desde el propio host (control): token IMDSv2 $([ -n "$TOKEN" ] && echo obtenido || echo rechazado); IMDSv1 sin token: código $(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://169.254.169.254/latest/meta-data/)"

seccion "H08 Commit desplegado"
git -C /opt/pnksecurity log -1 --format='%h %s (%cd)' --date=format:'%d/%m/%Y %H:%M'
} | tee "$O/host.txt"
