// PNKSecurity · pipeline de integración y entrega (backend y frontend)
//
// Ambientes: desarrollo = equipo de cada integrante · QA = este espacio de trabajo de Jenkins
// (instalación reproducible, pruebas y compilación del commit) · producción = AWS detrás del ALB.
// Si una prueba falla, las etapas siguientes se omiten y el sitio sigue con la versión anterior.
//
// Publicar: rsync a releases/<commit> y cambio atómico del enlace "current" (frontend en
// /var/www/pnk, backend en /opt/pnk; el backend aplica las migraciones antes de cambiar de versión).
// Volver atrás: ssh deploy@HOST 'ln -sfn <releases>/<commit-anterior> <current>' (+ reiniciar pnk-api)
pipeline {
  agent any

  options {
    disableConcurrentBuilds()
    skipDefaultCheckout(true)
    buildDiscarder(logRotator(numToKeepStr: '15'))
    timeout(time: 25, unit: 'MINUTES')
  }

  // Jenkins no tiene el puerto 8080 abierto a Internet (no recibe webhooks): consulta el repositorio
  triggers { pollSCM('H/2 * * * *') }

  environment {
    FRONT_HOST   = '10.30.1.20'          // IP privada fija de la EC2 del frontend (misma VPC)
    BACK_HOST    = '10.30.1.30'          // IP privada fija de la EC2 del backend
    DEPLOY_USER  = 'deploy'              // sin contraseña; en el frontend sin sudo, en el backend solo reinicia pnk-api
    ALB_URL      = 'https://pnk-alb-1378545871.us-east-1.elb.amazonaws.com'
    ALB_CA       = '/var/lib/jenkins/pnk-alb.pem'   // certificado autofirmado del ALB (público, no es secreto)
    NODE_OPTIONS = '--max-old-space-size=768'
    CI           = 'true'
  }

  stages {
    stage('Obtener código') {
      steps {
        checkout scm
        script { env.COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim() }
        sh 'git log -1 --format="Commit %H%nAutor  %an%nFecha  %ad%nAsunto %s"'
      }
    }

    stage('Instalar') {
      steps {
        dir('backend')  { sh 'npm ci --no-audit --no-fund' }
        dir('frontend') { sh 'npm ci --no-audit --no-fund' }
      }
    }

    stage('Probar') {
      steps {
        dir('backend')  { sh 'npm run typecheck && npm test' }
        dir('frontend') { sh 'npm run lint && npm test' }
      }
    }

    stage('Construir') {
      steps {
        dir('frontend') {
          sh '''
            npm run build
            echo "$COMMIT" > dist/version.txt
          '''
        }
        dir('backend') { sh 'npm run build' }
      }
    }

    stage('Publicar backend') {
      steps {
        sshagent(credentials: ['pnk-backend-ssh']) {
          sh '''
            set -eu
            SSH="ssh -o StrictHostKeyChecking=yes -o BatchMode=yes"
            DESTINO="/opt/pnk/releases/$COMMIT"
            $SSH "$DEPLOY_USER@$BACK_HOST" "mkdir -p '$DESTINO/db'"
            rsync -r --delete --chmod=D755,F644 -e "$SSH" backend/dist backend/package.json backend/package-lock.json "$DEPLOY_USER@$BACK_HOST:$DESTINO/"
            rsync -r --delete --chmod=D755,F644 -e "$SSH" db/migraciones "$DEPLOY_USER@$BACK_HOST:$DESTINO/db/"
            # Dependencias de producción, migraciones (cuenta dueña del esquema) y cambio atómico de versión
            $SSH "$DEPLOY_USER@$BACK_HOST" "set -e
              cd '$DESTINO'
              echo '$COMMIT' > version.txt
              npm ci --omit=dev --no-audit --no-fund > /dev/null
              set -a; . /etc/pnk/migracion.env; set +a
              MIGRACIONES_DIR='$DESTINO/db/migraciones' node dist/migrar.js
              ln -sfn '$DESTINO' /opt/pnk/current.nuevo && mv -Tf /opt/pnk/current.nuevo /opt/pnk/current
              sudo /usr/bin/systemctl restart pnk-api
              sleep 3
              sudo /usr/bin/systemctl is-active pnk-api
              cd /opt/pnk/releases && ls -1t | tail -n +6 | xargs -r rm -rf --"
          '''
        }
      }
    }

    stage('Publicar frontend') {
      steps {
        sshagent(credentials: ['pnk-frontend-ssh']) {
          sh '''
            set -eu
            SSH="ssh -o StrictHostKeyChecking=yes -o BatchMode=yes"
            DESTINO="/var/www/pnk/releases/$COMMIT"
            $SSH "$DEPLOY_USER@$FRONT_HOST" "mkdir -p '$DESTINO'"
            rsync -r --delete --chmod=D755,F644 -e "$SSH" frontend/dist/ "$DEPLOY_USER@$FRONT_HOST:$DESTINO/"
            # Cambio atómico de versión; se conservan las 5 últimas para poder volver atrás
            $SSH "$DEPLOY_USER@$FRONT_HOST" "ln -sfn '$DESTINO' /var/www/pnk/current.nuevo && mv -Tf /var/www/pnk/current.nuevo /var/www/pnk/current && cd /var/www/pnk/releases && ls -1t | grep -v '^inicial$' | tail -n +6 | xargs -r rm -rf --"
          '''
        }
      }
    }

    stage('Comprobar') {
      steps {
        sh '''
          set -eu
          # Directo por la red privada
          curl -fsS "http://$FRONT_HOST/healthz" > /dev/null
          curl -fsS "http://$FRONT_HOST/" | grep -q '<div id="root">'
          # Por la entrada pública (ALB con HTTPS), verificando su certificado
          FRONT_PUB=$(curl -fsS --cacert "$ALB_CA" "$ALB_URL/version.txt")
          API_PUB=$(curl -fsS --cacert "$ALB_CA" "$ALB_URL/api/health" | sed -E 's/.*"version":"([^"]*)".*/\\1/')
          echo "Construido:         $COMMIT"
          echo "Frontend publicado: $FRONT_PUB"
          echo "API publicada:      $API_PUB"
          test "$FRONT_PUB" = "$COMMIT"
          test "$API_PUB" = "$COMMIT"
        '''
      }
    }
  }

  post {
    success { echo "Versión ${env.COMMIT} publicada en ${env.ALB_URL}/" }
    failure { echo 'La ejecución falló: no se publicó esta versión; el sitio conserva la anterior.' }
  }
}
