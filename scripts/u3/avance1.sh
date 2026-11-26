#!/bin/bash
# Avance 1 · prueba de punta a punta contra la API real (PostgreSQL), sin pasar por React.
# Uso: scripts/u3/avance1.sh [URL_BASE]   (por defecto http://127.0.0.1:3000)
# Muestra cada petición con su código HTTP. La cookie de sesión no se imprime.
set -uo pipefail
BASE="${1:-http://127.0.0.1:3000}"
CLAVE="${PNK_CLAVE_PRUEBA:-Pnk-Prueba-2026}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
A="$TMP/alondra"; B="$TMP/bruno"
J='Content-Type: application/json'

paso() { echo; echo "## $1"; }
pedir() { # pedir ETIQUETA curl-args...
  local etiqueta="$1"; shift
  local cuerpo codigo
  cuerpo=$(curl -s -o "$TMP/r" -w '%{http_code}' "$@"); codigo=$cuerpo
  printf '%-58s → HTTP %s  %s\n' "$etiqueta" "$codigo" "$(head -c 220 "$TMP/r")"
}

echo "# Avance 1 · $(date '+%d/%m/%Y %H:%M:%S %z') · $BASE"
paso "A01 Estado de la API"
pedir "GET /api/health" "$BASE/api/health"

paso "A02 Carta del restaurante 1 desde PostgreSQL"
curl -s "$BASE/api/restaurantes/1" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);console.log(r.nombre+" · "+r.direccion);for(const c of r.cartas)for(const g of c.categorias)for(const i of g.items)console.log(`  ${c.nombre} / ${g.nombre} / ${i.nombre} $${i.precio}`)})'

paso "A03 Sin sesión no se puede comentar"
pedir "POST comentario sin sesión" -X POST -H "$J" -d '{"texto":"sin sesión"}' "$BASE/api/restaurantes/1/comentarios"

paso "A04 Login"
pedir "POST /api/auth/login clave incorrecta" -X POST -H "$J" -d '{"email":"alondra@pnk.test","password":"incorrecta"}' "$BASE/api/auth/login"
pedir "POST /api/auth/login correo inexistente" -X POST -H "$J" -d '{"email":"nadie@pnk.test","password":"x"}' "$BASE/api/auth/login"
pedir "POST /api/auth/login Alondra (correcto)" -c "$A" -X POST -H "$J" -d "{\"email\":\"alondra@pnk.test\",\"password\":\"$CLAVE\"}" "$BASE/api/auth/login"
pedir "POST /api/auth/login Bruno (correcto)" -c "$B" -X POST -H "$J" -d "{\"email\":\"bruno@pnk.test\",\"password\":\"$CLAVE\"}" "$BASE/api/auth/login"
echo "Atributos de la cookie: $(curl -s -D - -o /dev/null -X POST -H "$J" -d "{\"email\":\"alondra@pnk.test\",\"password\":\"$CLAVE\"}" "$BASE/api/auth/login" | grep -i '^set-cookie' | sed -E 's/(pnk_sesion=)[^;]+/\1[oculta]/')"

paso "A05 Validación en el servidor (entrada inválida no se guarda)"
pedir "POST comentario vacío" -b "$A" -X POST -H "$J" -d '{"texto":"   "}' "$BASE/api/restaurantes/1/comentarios"
pedir "POST comentario de 501 caracteres" -b "$A" -X POST -H "$J" -d "{\"texto\":\"$(printf 'a%.0s' $(seq 501))\"}" "$BASE/api/restaurantes/1/comentarios"
pedir "POST comentario como formulario (no JSON)" -b "$A" -X POST -d 'texto=hola' "$BASE/api/restaurantes/1/comentarios"
pedir "GET id con SQL (1 OR 1=1)" "$BASE/api/restaurantes/1%20OR%201=1/comentarios"

paso "A06 Crear un comentario y volver a consultarlo (persistencia)"
TEXTO="Comentario del avance 1 · $(date +%H:%M:%S)"
pedir "POST comentario válido (Alondra)" -b "$A" -X POST -H "$J" -d "{\"texto\":\"$TEXTO\"}" "$BASE/api/restaurantes/1/comentarios"
ID=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).id)' "$TMP/r")
pedir "GET comentarios del restaurante 1" -b "$A" "$BASE/api/restaurantes/1/comentarios"

paso "A07 Autorización: Bruno intenta modificar el comentario de Alondra"
pedir "PUT /api/comentarios/$ID como Bruno" -b "$B" -X PUT -H "$J" -d '{"texto":"cambiado por Bruno"}' "$BASE/api/comentarios/$ID"
pedir "DELETE /api/comentarios/$ID como Bruno" -b "$B" -X DELETE -H "$J" "$BASE/api/comentarios/$ID"
pedir "PUT /api/comentarios/$ID como Alondra (dueña)" -b "$A" -X PUT -H "$J" -d "{\"texto\":\"$TEXTO (editado)\"}" "$BASE/api/comentarios/$ID"
