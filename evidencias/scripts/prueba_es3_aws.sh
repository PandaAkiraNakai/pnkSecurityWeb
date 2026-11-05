#!/usr/bin/env bash
# ES3: pruebas del despliegue en AWS hechas DESDE AFUERA (el equipo del integrante), como las
# vería un cliente o un atacante: canal cifrado, puertos expuestos, SSH y acceso a phpMyAdmin.
# Uso: prueba_es3_aws.sh <dirSalida>     (lee deploy/aws/estado.env: IP, dominio y clave SSH)
set -u
O="${1:?dirSalida}"; mkdir -p "$O"
# shellcheck source=/dev/null
. "$(dirname "$0")/../../deploy/aws/estado.env"
D="$PNK_DOMINIO"; IP="$PNK_IP"; K="$PNK_CLAVE"
fila() { printf '%-4s %-52s %s\n' "$1" "$2" "$3"; }
{
echo "== $(date '+%d/%m/%Y %H:%M:%S %Z') · https://$D ($IP) · desde el equipo de pruebas =="

# A01 HTTP se redirige a HTTPS.
curl -sI --max-time 10 "http://$D/?id=1" | sed 's/\r$//' > "$O/A01_http.txt"
fila A01 "http:// redirige a https://" "$(head -1 "$O/A01_http.txt" | cut -d' ' -f2) → $(grep -i '^location:' "$O/A01_http.txt" | cut -d' ' -f2)"

# A02 Certificado válido (curl sin -k) y versión de TLS.
curl -sS -o /dev/null --max-time 10 -w '%{http_code} %{ssl_verify_result}\n' "https://$D/?id=1" > "$O/A02_tls_curl.txt" 2>&1
echo | openssl s_client -connect "$IP:443" -servername "$D" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates > "$O/A02_certificado.txt"
echo | openssl s_client -connect "$IP:443" -servername "$D" 2>/dev/null | grep -E 'Protocol|Cipher is' | sort -u >> "$O/A02_certificado.txt"
fila A02 "Certificado aceptado por curl (verificación 0)" "$(cat "$O/A02_tls_curl.txt") · $(grep -m1 issuer "$O/A02_certificado.txt" | sed -E 's/.*O ?= ?//;s/,.*//')"
for v in tls1 tls1_1; do
  if echo | openssl s_client -"$v" -connect "$IP:443" -servername "$D" >/dev/null 2>&1; then r="ACEPTADO"; else r="rechazado"; fi
  echo "$v: $r" >> "$O/A02_certificado.txt"
done
fila A02b "TLS 1.0 y 1.1 (obsoletos)" "$(grep -E '^tls1' "$O/A02_certificado.txt" | tr '\n' ' ')"

# A03 HSTS y cookie de sesión con Secure.
curl -sI --max-time 10 "https://$D/?id=1" | sed 's/\r$//' | sed -E 's/(PHPSESSID=)[^;]+/\1[oculta]/' > "$O/A03_cabeceras_https.txt"
fila A03 "HSTS" "$(grep -i '^strict-transport-security' "$O/A03_cabeceras_https.txt" | cut -d' ' -f2-)"
fila A03b "Cookie de sesión" "$(grep -i '^set-cookie' "$O/A03_cabeceras_https.txt" | cut -d' ' -f2- | sed 's/PHPSESSID=\[oculta\]; //')"

# A04 Puertos accesibles desde internet.
: > "$O/A04_puertos.txt"
for p in 22 80 443 3306 8080 8081 33060; do
  if timeout 4 bash -c "</dev/tcp/$IP/$p" 2>/dev/null; then e="abierto"; else e="cerrado/filtrado"; fi
  echo "$p/tcp $e" >> "$O/A04_puertos.txt"
done
fila A04 "Puertos desde internet" "$(tr '\n' ';' < "$O/A04_puertos.txt" | sed 's/;$//;s/;/ · /g')"

# A05 SSH sin contraseña ni root.
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=no \
    -o PreferredAuthentications=password,keyboard-interactive -o ConnectTimeout=8 "ubuntu@$IP" true > "$O/A05_ssh_clave.txt" 2>&1
fila A05 "SSH con contraseña" "$(tail -1 "$O/A05_ssh_clave.txt")"
ssh -i "$K" -o BatchMode=yes -o ConnectTimeout=8 "root@$IP" true > "$O/A05_ssh_root.txt" 2>&1
fila A05b "SSH como root con la clave válida" "$(tail -1 "$O/A05_ssh_root.txt")"
ssh -i "$K" -o BatchMode=yes -o ConnectTimeout=8 "ubuntu@$IP" 'echo "acceso con clave: $(whoami)@$(hostname)"' > "$O/A05_ssh_ok.txt" 2>&1
fila A05c "SSH como ubuntu con la clave (permitido)" "$(tail -1 "$O/A05_ssh_ok.txt")"

# A06 phpMyAdmin: directo desde internet no responde; por túnel SSH muestra el login.
curl -s -o /dev/null --max-time 6 -w '%{http_code}' "http://$IP:8081/" > "$O/A06_pma_directo.txt" 2>&1
fila A06 "phpMyAdmin directo (http://IP:8081)" "código $(cat "$O/A06_pma_directo.txt") (000 = sin conexión)"
ssh -i "$K" -o BatchMode=yes -o ExitOnForwardFailure=yes -f -N -L 18081:127.0.0.1:8081 "ubuntu@$IP" && sleep 2
curl -s --max-time 8 http://127.0.0.1:18081/ | grep -o -E '<title>[^<]*|name="pma_username"|name="pma_password"' > "$O/A06_pma_tunel.txt"
pkill -f -- "-L 18081:127.0.0.1:8081" 2>/dev/null
fila A06b "phpMyAdmin por túnel SSH" "$(tr '\n' ' ' < "$O/A06_pma_tunel.txt")"
} | tee "$O/aws_externo.txt"
