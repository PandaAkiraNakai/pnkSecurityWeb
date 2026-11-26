#!/bin/bash
# Configura Jenkins y las conexiones de despliegue al frontend y al backend. Se ejecuta DESDE el
# equipo de administración, después de servidor_jenkins.sh, servidor_frontend.sh y servidor_backend.sh:
#   deploy/u3/configurar_jenkins.sh
#
# 1. Una clave SSH exclusiva por servidor (ed25519), generada en Jenkins; su parte pública se
#    autoriza para el usuario deploy con "restrict" (sin túneles, agente ni terminal).
# 2. Identidad de cada servidor: la huella que entrega ssh-keyscan desde Jenkins se compara con la
#    que se lee en el servidor por el canal de administración. Si no coincide, se detiene.
# 3. Jenkins sin asistente: administrador con contraseña aleatoria, sin registro de usuarios, sin
#    acceso anónimo, un ejecutor, sin puerto de agentes.
# 4. Plugins Git, Pipeline, SSH Agent y vista de etapas; credenciales pnk-frontend-ssh y
#    pnk-backend-ssh (la clave privada solo queda en Jenkins); certificado público del ALB para
#    verificar HTTPS en la comprobación; trabajo pnk-u3.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/estado.env"
K="$HOME/.ssh/pnk-u3.pem"
KH="$HOME/.ssh/known_hosts_pnk_u3"
SSH_OPC=(-i "$K" -o UserKnownHostsFile="$KH" -o StrictHostKeyChecking=yes -o BatchMode=yes)
REPO_URL="${REPO_URL:-https://github.com/PandaAkiraNakai/pnkSecurityWeb.git}"
RAMA="${RAMA:-*/u3/avance-2}"
ADMIN_LOCAL="$HOME/.ssh/pnk-u3-jenkins-admin.txt"
ALB_CERT="$HOME/.ssh/pnk-u3-alb/certificado.pem"
jenkins() { ssh "${SSH_OPC[@]}" "ubuntu@$JENKINS_IP" "$@"; }
en() { local ip=$1; shift; ssh "${SSH_OPC[@]}" "ubuntu@$ip" "$@"; }
log() { printf '\033[1m==>\033[0m %s\n' "$*" >&2; }

# Servidores de destino: nombre · IP pública (administración) · IP privada · carpeta de releases
SERVIDORES=("frontend $FRONT_IP 10.30.1.20 /var/www/pnk/releases")
# El backend se incluye cuando ya está preparado (existe su usuario deploy)
if [ -n "${BACK_IP:-}" ] && en "$BACK_IP" 'id deploy' >/dev/null 2>&1; then
  SERVIDORES+=("backend $BACK_IP 10.30.1.30 /opt/pnk/releases")
fi

jenkins 'sudo install -d -o jenkins -g jenkins -m 0700 /var/lib/jenkins/.ssh; sudo touch /var/lib/jenkins/.ssh/known_hosts; sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/known_hosts; sudo chmod 600 /var/lib/jenkins/.ssh/known_hosts'
for s in "${SERVIDORES[@]}"; do
  read -r NOMBRE PUB_IP PRIV_IP RELEASES <<< "$s"
  log "1-2. Despliegue a $NOMBRE ($PRIV_IP)"
  if ! jenkins "sudo grep -q '^$PRIV_IP ' /var/lib/jenkins/.ssh/known_hosts"; then
    HUELLA_SRV=$(en "$PUB_IP" 'ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub' | awk '{print $2}')
    HUELLA_SCAN=$(jenkins "ssh-keyscan -t ed25519 $PRIV_IP 2>/dev/null > /tmp/kh_$NOMBRE; ssh-keygen -lf /tmp/kh_$NOMBRE" | awk '{print $2}')
    echo "   huella leída en el servidor: $HUELLA_SRV"
    echo "   huella vista desde Jenkins:  $HUELLA_SCAN"
    [ -n "$HUELLA_SRV" ] && [ "$HUELLA_SRV" = "$HUELLA_SCAN" ] || { echo "Las huellas NO coinciden: se detiene" >&2; exit 1; }
    jenkins "sudo sh -c 'cat /tmp/kh_$NOMBRE >> /var/lib/jenkins/.ssh/known_hosts'; rm /tmp/kh_$NOMBRE"
  fi
  # La clave se genera solo si la credencial todavía no existe en Jenkins (la privada se borra al guardarla)
  if ! jenkins "test -f ~/.pnk_cred_$NOMBRE"; then
    PUB=$(jenkins "test -f ~/.ssh/pnk_deploy_$NOMBRE || ssh-keygen -q -t ed25519 -N '' -C 'jenkins-despliegue-$NOMBRE' -f ~/.ssh/pnk_deploy_$NOMBRE; cat ~/.ssh/pnk_deploy_$NOMBRE.pub")
    en "$PUB_IP" "sudo grep -qxF 'restrict $PUB' /home/deploy/.ssh/authorized_keys || echo 'restrict $PUB' | sudo tee -a /home/deploy/.ssh/authorized_keys >/dev/null"
    jenkins "sudo cp /var/lib/jenkins/.ssh/known_hosts /tmp/kh_prueba && sudo chown ubuntu /tmp/kh_prueba && ssh -i ~/.ssh/pnk_deploy_$NOMBRE -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/kh_prueba deploy@$PRIV_IP 'test -w $RELEASES && echo \"   prueba SSH como deploy: OK\"'; rm -f /tmp/kh_prueba"
  fi
done

log "3. Jenkins: seguridad inicial (init.groovy.d)"
jenkins 'sudo bash -s' <<'REMOTO'
set -euo pipefail
install -d -o jenkins -g jenkins -m 0700 /var/lib/jenkins/init.groovy.d
if [ ! -s /var/lib/jenkins/.pnk_admin ]; then
  ( umask 077; openssl rand -base64 24 | tr -d '/+=' | cut -c1-24 > /var/lib/jenkins/.pnk_admin )
  chown jenkins:jenkins /var/lib/jenkins/.pnk_admin
fi
cat > /var/lib/jenkins/init.groovy.d/01-seguridad.groovy <<'EOF'
// Seguridad inicial de Jenkins (se aplica en cada arranque; no guarda secretos en el script)
import jenkins.model.*
import hudson.security.*
import hudson.model.Node
def j = Jenkins.get()
def clave = new File('/var/lib/jenkins/.pnk_admin').text.trim()
def realm = (j.securityRealm instanceof HudsonPrivateSecurityRealm) ? j.securityRealm : new HudsonPrivateSecurityRealm(false)
def admin = realm.getUser('admin')
if (admin == null) { realm.createAccount('admin', clave) }
else { admin.addProperty(HudsonPrivateSecurityRealm.Details.fromPlainPassword(clave)); admin.save() }
j.securityRealm = realm
def estrategia = new FullControlOnceLoggedInAuthorizationStrategy()
estrategia.allowAnonymousRead = false
j.authorizationStrategy = estrategia
j.numExecutors = 1
j.mode = Node.Mode.NORMAL
j.slaveAgentPort = -1
JenkinsLocationConfiguration.get().url = 'http://localhost:8080/'
j.save()
EOF
chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/01-seguridad.groovy
# Instalación marcada como completa: el asistente no vuelve a crear su propio administrador
V=$(dpkg-query -W -f='${Version}' jenkins)
for f in jenkins.install.InstallUtil.lastExecVersion jenkins.install.UpgradeWizard.state; do
  [ -s "/var/lib/jenkins/$f" ] || { echo "$V" > "/var/lib/jenkins/$f"; chown jenkins:jenkins "/var/lib/jenkins/$f"; }
done
rm -f /var/lib/jenkins/secrets/initialAdminPassword
if ! curl -fsS -o /dev/null -u "admin:$(cat /var/lib/jenkins/.pnk_admin)" http://127.0.0.1:8080/whoAmI/api/json; then
  systemctl restart jenkins
  for i in $(seq 1 90); do curl -fsS -o /dev/null http://127.0.0.1:8080/login && break; sleep 2; done
fi
curl -fsS -o /dev/null -u "admin:$(cat /var/lib/jenkins/.pnk_admin)" http://127.0.0.1:8080/whoAmI/api/json && echo "   administrador OK"
REMOTO
jenkins "sudo cat /var/lib/jenkins/.pnk_admin" | ( umask 077; sed 's/^/admin:/' > "$ADMIN_LOCAL" )

if [ -s "$ALB_CERT" ]; then
  log "Certificado público del ALB para la comprobación HTTPS"
  scp -q -i "$K" -o UserKnownHostsFile="$KH" -o StrictHostKeyChecking=yes "$ALB_CERT" "ubuntu@$JENKINS_IP:/tmp/pnk-alb.pem"
  jenkins 'sudo install -o jenkins -g jenkins -m 0644 /tmp/pnk-alb.pem /var/lib/jenkins/pnk-alb.pem && rm /tmp/pnk-alb.pem'
fi

log "4. Plugins, credenciales y trabajo (jenkins-cli)"
NOMBRES=$(for s in "${SERVIDORES[@]}"; do echo "$s" | awk '{print $1}'; done | tr '\n' ' ')
# El script remoto va a un archivo: la CLI de Jenkins (Java) leería el resto del script desde la entrada estándar
jenkins "cat > /tmp/pnk_cfg.sh && REPO_URL='$REPO_URL' RAMA='$RAMA' NOMBRES='$NOMBRES' bash /tmp/pnk_cfg.sh; r=\$?; rm -f /tmp/pnk_cfg.sh; exit \$r" <<'REMOTO'
set -euo pipefail
cd ~
curl -fsS -o jenkins-cli.jar http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar
( umask 077; sudo cat /var/lib/jenkins/.pnk_admin | sed 's/^/admin:/' > ~/.jenkins_auth )
CLI() { java -jar ~/jenkins-cli.jar -s http://127.0.0.1:8080/ -http -auth @"$HOME/.jenkins_auth" "$@"; }
CLI0() { CLI "$@" < /dev/null; }
esperar() { for i in $(seq 1 60); do CLI0 who-am-i >/dev/null 2>&1 && return 0; sleep 3; done; return 1; }
esperar || { echo "   la CLI no autentica" >&2; exit 1; }
FALTAN=""
for p in git workflow-aggregator ssh-agent pipeline-graph-view; do
  CLI0 list-plugins "$p" 2>/dev/null | grep -q "^$p " || FALTAN="$FALTAN $p"
done
if [ -n "$FALTAN" ]; then
  echo "   instalando:$FALTAN"
  CLI0 install-plugin $FALTAN >/dev/null
  CLI0 safe-restart || true
  sleep 15; esperar
fi
CLI0 list-plugins | grep -E '^(git|workflow-aggregator|ssh-agent|pipeline-graph-view|credentials) ' | awk '{printf "   plugin %s %s\n", $1, $NF}'

for NOMBRE in $NOMBRES; do
  ID="pnk-$NOMBRE-ssh"
  if [ -f ~/.ssh/pnk_deploy_$NOMBRE ]; then
    {
      echo '<com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials">'
      echo "  <scope>GLOBAL</scope><id>$ID</id>"
      echo "  <description>Despliegue al $NOMBRE (usuario deploy)</description>"
      echo '  <username>deploy</username>'
      echo '  <privateKeySource class="com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey$DirectEntryPrivateKeySource">'
      printf '    <privateKey>%s</privateKey>\n' "$(cat ~/.ssh/pnk_deploy_$NOMBRE)"
      echo '  </privateKeySource>'
      echo '</com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>'
    } > ~/.cred.xml
    if CLI0 get-credentials-as-xml system::system::jenkins _ "$ID" >/dev/null 2>&1; then
      CLI update-credentials-by-xml system::system::jenkins _ "$ID" < ~/.cred.xml
    else
      CLI create-credentials-by-xml system::system::jenkins _ < ~/.cred.xml
    fi
    shred -u ~/.cred.xml ~/.ssh/pnk_deploy_$NOMBRE; rm -f ~/.ssh/pnk_deploy_$NOMBRE.pub
    touch ~/.pnk_cred_$NOMBRE
    echo "   credencial $ID guardada; la clave privada se borró de la cuenta ubuntu"
  fi
done

cat > ~/.trabajo.xml <<EOF
<flow-definition plugin="workflow-job">
  <description>PNKSecurity: prueba backend y frontend, los construye y los publica en AWS (detrás del ALB).</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs><hudson.plugins.git.UserRemoteConfig><url>${REPO_URL}</url></hudson.plugins.git.UserRemoteConfig></userRemoteConfigs>
      <branches><hudson.plugins.git.BranchSpec><name>${RAMA}</name></hudson.plugins.git.BranchSpec></branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
if CLI0 get-job pnk-u3 >/dev/null 2>&1; then CLI update-job pnk-u3 < ~/.trabajo.xml; else CLI create-job pnk-u3 < ~/.trabajo.xml; fi
rm -f ~/.trabajo.xml
echo "   trabajo pnk-u3 → $REPO_URL ($RAMA, Jenkinsfile)"
REMOTO

log "Listo"
cat <<EOF
  Abrir:   deploy/u3/abrir_jenkins.sh   → http://localhost:8080
  Usuario y contraseña en $ADMIN_LOCAL
EOF
