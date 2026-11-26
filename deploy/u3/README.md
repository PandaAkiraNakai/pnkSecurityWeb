# Despliegue en AWS y Jenkins

Scripts para levantar la infraestructura en el Learner Lab de AWS (us-east-1) y la entrega continua
del frontend con Jenkins. Todos se pueden volver a correr: solo crean o cambian lo que falta.

## Arquitectura

```
                  Administración (IP autorizada)
                     │ SSH 22          │ HTTP 80 (revisión)
                     ▼                 ▼
 ┌──────────── VPC pnk-vpc 10.30.0.0/16 ─────────────────────────────────┐
 │  Subred pública pnk-publica-a 10.30.1.0/24 (us-east-1a)                │
 │                                                                        │
 │  ┌──────────────────────┐   SSH 22 (rsync)   ┌──────────────────────┐  │
 │  │ pnk-jenkins          │ ─────────────────▶ │ pnk-frontend         │  │
 │  │ 10.30.1.10 · t3.small│   HTTP 80 (comprobar)│ 10.30.1.20 · t3.micro│  │
 │  │ Jenkins en 127.0.0.1 │ ─────────────────▶ │ Nginx + React (dist) │  │
 │  └──────────────────────┘                    └──────────────────────┘  │
 │  Subredes privadas 10.30.11.0/24 y 10.30.12.0/24: sin ruta a Internet  │
 │  (reservadas para PostgreSQL)                                          │
 └────────────────────────────────────────────────────────────────────────┘
       ▲ git (pollSCM cada 2 min)
   GitHub: PandaAkiraNakai/pnkSecurityWeb
```

| Grupo de seguridad | Entrada permitida |
| --- | --- |
| `pnk-jenkins` | 22 solo desde la IP de administración. El 8080 **no** está abierto: Jenkins escucha en 127.0.0.1 y se usa por túnel SSH |
| `pnk-frontend` | 22 y 80 desde la IP de administración y desde el grupo `pnk-jenkins` (despliegue y comprobación por la red privada) |

Todas las EC2 usan Ubuntu Server 26.04 LTS, IMDSv2 obligatorio, disco cifrado, perfil
`LabInstanceProfile` (permite Session Manager como respaldo) y actualizaciones de seguridad automáticas.

## Pasos

```bash
deploy/u3/infra.sh                 # VPC, subredes, grupos de seguridad, EC2, IP elástica de Jenkins
source deploy/u3/estado.env        # ids e IP (archivo local, no se versiona)
ssh -i ~/.ssh/pnk-u3.pem ubuntu@$FRONT_IP   'sudo bash -s' < deploy/u3/servidor_frontend.sh
ssh -i ~/.ssh/pnk-u3.pem ubuntu@$JENKINS_IP 'sudo bash -s' < deploy/u3/servidor_jenkins.sh
deploy/u3/configurar_jenkins.sh    # clave de despliegue, huella verificada, Jenkins, credencial y trabajo
```

Para entrar a Jenkins: `ssh -i ~/.ssh/pnk-u3.pem -N -L 8080:127.0.0.1:8080 ubuntu@$JENKINS_IP` y abrir
http://localhost:8080 (usuario `admin`; la contraseña queda en `~/.ssh/pnk-u3-jenkins-admin.txt`).

Si cambia la IP desde donde administras (otra red), vuelve a correr `ADMIN_IP=<nueva> deploy/u3/infra.sh`:
agrega las reglas para la IP nueva.

## Credenciales y secretos

| Qué | Dónde vive |
| --- | --- |
| Clave SSH de administración (`pnk-u3`) | Solo en el equipo de administración (`~/.ssh/pnk-u3.pem`, permisos 600) |
| Clave de despliegue (ed25519, exclusiva) | Privada: solo en Jenkins Credentials (`pnk-frontend-ssh`); se borra de la cuenta ubuntu al guardarla. Pública: en `authorized_keys` del usuario `deploy` con `restrict` |
| Identidad del frontend | `known_hosts` del usuario `jenkins`, con la huella comparada entre `ssh-keyscan` y la leída en el servidor |
| Contraseña del administrador de Jenkins | Aleatoria, en `/var/lib/jenkins/.pnk_admin` (600, usuario jenkins) y en el equipo de administración |

El usuario `deploy` no tiene sudo ni contraseña y solo es dueño de `/var/www/pnk`.

## Pipeline (`Jenkinsfile`)

Obtener código → Instalar (`npm ci` en backend y frontend) → Probar (typecheck y pruebas del backend;
lint y pruebas del frontend) → Construir (Vite y tsc; `dist/version.txt` con el commit) → Publicar
frontend (rsync a `releases/<commit>` y cambio atómico del enlace `current`) → Comprobar (`/healthz`,
la página y que `version.txt` sea el commit construido).

Si una prueba falla, las etapas siguientes se omiten: nada se copia y el sitio sigue con la versión
anterior.

### Ambientes

| Ambiente | Dónde | Qué se comprueba |
| --- | --- | --- |
| Desarrollo | Equipo de cada integrante (Vite, API local, PostgreSQL en Docker) | Pruebas antes de cada commit |
| QA | Espacio de trabajo de Jenkins, con el commit exacto | Instalación reproducible con `npm ci`, pruebas y compilación |
| Producción (evaluación) | EC2 `pnk-frontend` | Recibe el despliegue; comprobación posterior por HTTP y `version.txt` |

### Volver a una versión anterior

Las 5 últimas versiones quedan en `/var/www/pnk/releases/`. Para volver a una:

```bash
ssh deploy@10.30.1.20 'ls -1t /var/www/pnk/releases'          # desde Jenkins
ssh deploy@10.30.1.20 'ln -sfn /var/www/pnk/releases/<commit> /var/www/pnk/current'
```

O revertir el commit en Git y dejar que Jenkins publique de nuevo.
