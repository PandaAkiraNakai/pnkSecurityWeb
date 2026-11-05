#!/usr/bin/env bash
# ES3: batería de pruebas por HTTP de las mejoras de la Sumativa III (contraseñas, CSRF,
# sesión, cabeceras, recursos externos). Sirve para el "antes" y el "después", en local o en AWS.
# Uso: PNK_CLAVE_PRUEBA=... PNK_CLAVE_ADMIN=... prueba_es3.sh <baseURL> <dirSalida>
# La cuenta de prueba es alondra@gmail.com (ficticia). La clave se pasa por entorno y no se guarda.
set -u
B="${1:?baseURL}"; O="${2:?dirSalida}"; mkdir -p "$O"
U="alondra@gmail.com"; C="${PNK_CLAVE_PRUEBA:?definir PNK_CLAVE_PRUEBA}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
CURL=(curl -s -k --max-time 20)
exec > >(tee "$O/_resumen.txt")   # la tabla queda también en _resumen.txt
echo "== $(date '+%d/%m/%Y %H:%M:%S %Z') · $B =="

# Guarda la respuesta (encabezados + primeros 3 KB del cuerpo) sin la cookie de sesión.
guardar() { sed 's/\r$//' | sed -E 's/(PHPSESSID=)[^;]+/\1[oculta]/' | head -c 3000 > "$O/$1.txt"; }
codigo() { head -1 "$O/$1.txt" | awk '{print $2}'; }
ubicacion() { grep -i '^location:' "$O/$1.txt" | head -1 | sed 's/^[Ll]ocation: //'; }
fila() { printf '%-4s %-46s %-24s %s\n' "$1" "$2" "$3" "$4"; }
# Token CSRF de la página (vacío si la versión no tiene CSRF).
token() { grep -o -E 'name="csrf"[^>]*value="[^"]+"|name="csrf-token" content="[^"]+"' "$1" | head -1 | sed -E 's/.*(value|content)="([^"]+)"/\2/'; }
pagina() { "${CURL[@]}" -b "$1" -c "$1" "$B/?id=1" > "$2"; }
login() { # $1 jar, $2 clave, $3 archivo, $4 usuario (opcional); usa el token si existe
  pagina "$1" "$TMP/p.html"; local t; t="$(token "$TMP/p.html")"
  "${CURL[@]}" -i -b "$1" -c "$1" --data-urlencode "frmusuario=${4:-$U}" --data-urlencode "frmpassword=$2" \
    ${t:+--data-urlencode "csrf=$t"} "$B/setup/procesalogin.php" | guardar "$3"
}
sesion_activa() { pagina "$1" "$TMP/s.html"; grep -q 'Bienvenido' "$TMP/s.html" && echo "con sesión" || echo "sin sesión"; }

fila "#" "Prueba" "Resultado" "Detalle"

# T01 funcional: login con la cuenta de prueba.
J1="$TMP/j1"; login "$J1" "$C" T01_login_valido
fila T01 "Login con la clave correcta" "$(codigo T01_login_valido) $(sesion_activa "$J1")" "$(ubicacion T01_login_valido)"

# T02 rechazo: clave incorrecta → aviso genérico y sin sesión.
J2="$TMP/j2"; login "$J2" "clave-incorrecta" T02_login_clave_erronea
fila T02 "Login con clave incorrecta" "$(codigo T02_login_clave_erronea) $(sesion_activa "$J2")" "$(ubicacion T02_login_clave_erronea)"

# T03 rechazo CSRF: login enviado sin token (otra página lo podría enviar en nombre del usuario).
J3="$TMP/j3"; pagina "$J3" "$TMP/p3.html"
"${CURL[@]}" -i -b "$J3" -c "$J3" --data-urlencode "frmusuario=$U" --data-urlencode "frmpassword=$C" \
  "$B/setup/procesalogin.php" | guardar T03_login_sin_token
fila T03 "Login sin token CSRF" "$(codigo T03_login_sin_token) $(sesion_activa "$J3")" "$(ubicacion T03_login_sin_token)"

# T04 rechazo CSRF: comentario con sesión válida pero sin token.
MARCA="prueba-es3-sin-token-$(date +%s)"
"${CURL[@]}" -i -b "$J1" -c "$J1" --data-urlencode "comentario=$MARCA" "$B/grcomentarios.php" | guardar T04_comentario_sin_token
pagina "$J1" "$TMP/p4.html"; grep -q "$MARCA" "$TMP/p4.html" && G4="se guardó" || G4="no se guardó"
fila T04 "Comentario con sesión y SIN token CSRF" "$(codigo T04_comentario_sin_token) $G4" ""

# T05 funcional: comentario con sesión y con token.
MARCA5="prueba-es3-con-token-$(date +%s)"; T5="$(token "$TMP/p4.html")"
"${CURL[@]}" -i -b "$J1" -c "$J1" --data-urlencode "comentario=$MARCA5" ${T5:+--data-urlencode "csrf=$T5"} \
  "$B/grcomentarios.php" | guardar T05_comentario_con_token
pagina "$J1" "$TMP/p5.html"; grep -q "$MARCA5" "$TMP/p5.html" && G5="se guardó" || G5="no se guardó"
fila T05 "Comentario con sesión y token" "$(codigo T05_comentario_con_token) $G5" ""

# T06 rechazo CSRF: agregar al carrito sin token.
"${CURL[@]}" -i -b "$J1" -c "$J1" -d "op=1&iditems=1" "$B/carrito.php" | guardar T06_carrito_sin_token
fila T06 "Carrito op=1 SIN token CSRF" "$(codigo T06_carrito_sin_token)" ""

# T07 funcional: agregar al carrito con token (cabecera X-CSRF-Token, como lo hace la página).
T7="$(token "$TMP/p5.html")"
"${CURL[@]}" -i -b "$J1" -c "$J1" -d "op=1&iditems=1" ${T7:+-H "X-CSRF-Token: $T7"} "$B/carrito.php" | guardar T07_carrito_con_token
fila T07 "Carrito op=1 con token" "$(codigo T07_carrito_con_token)" ""

# T08 vaciar el carrito no debe cerrar la sesión del usuario.
"${CURL[@]}" -i -b "$J1" -c "$J1" -d "op=3" ${T7:+-H "X-CSRF-Token: $T7"} "$B/carrito.php" | guardar T08_vaciar_carrito
fila T08 "Vaciar carrito (op=3) con sesión iniciada" "$(codigo T08_vaciar_carrito) $(sesion_activa "$J1")" ""

# T09 rechazo: cerrar sesión con un simple enlace GET (sirve para forzar el cierre desde otra página).
"${CURL[@]}" -i -b "$J1" -c "$J1" "$B/setup/cerrar_sesion.php" | guardar T09_logout_get
fila T09 "Cerrar sesión por GET" "$(codigo T09_logout_get) $(sesion_activa "$J1")" ""

# T10 funcional: cerrar sesión por POST con token.
pagina "$J1" "$TMP/p10.html"; T10="$(token "$TMP/p10.html")"
"${CURL[@]}" -i -b "$J1" -c "$J1" -X POST ${T10:+--data-urlencode "csrf=$T10"} "$B/setup/cerrar_sesion.php" | guardar T10_logout_post
fila T10 "Cerrar sesión por POST con token" "$(codigo T10_logout_post) $(sesion_activa "$J1")" ""

# T11 cabeceras de seguridad de la respuesta principal.
"${CURL[@]}" -I "$B/?id=1" | guardar T11_cabeceras
CAB=""
for h in Strict-Transport-Security Content-Security-Policy X-Content-Type-Options X-Frame-Options Referrer-Policy Permissions-Policy; do
  grep -qi "^$h:" "$O/T11_cabeceras.txt" && CAB+="$h " ; done
fila T11 "Cabeceras de seguridad presentes" "$(echo $CAB | wc -w)/6" "${CAB:-ninguna}"

# T12 recursos de terceros: la página y el CSS no deben cargar nada desde otro origen.
"${CURL[@]}" "$B/?id=1" > "$TMP/p12.html"; "${CURL[@]}" "$B/css/style.css" > "$TMP/s12.css"
{ echo "# src/href absolutos en la página:"; grep -o -E '(src|href)="https?://[^"]+"' "$TMP/p12.html";
  echo "# @import/url() absolutos en css/style.css:"; grep -o -E '@import url\("?https?://[^")]+|url\("?https?://[^")]+' "$TMP/s12.css"; } > "$O/T12_recursos_externos.txt"
N12="$(grep -v '^#' "$O/T12_recursos_externos.txt" | grep -c .)"
fila T12 "Recursos cargados desde terceros (CDN)" "$N12" "$(grep -v '^#' "$O/T12_recursos_externos.txt" | sed -E 's#.*https?://([^/]+).*#\1#' | sort -u | tr '\n' ' ')"

# T13 rechazo: fuerza bruta (6 claves erróneas seguidas) y luego la clave correcta. Se usa la
# cuenta admin@gmail.com para no bloquear la de prueba; su clave va en PNK_CLAVE_ADMIN.
A="admin@gmail.com"; CA="${PNK_CLAVE_ADMIN:?definir PNK_CLAVE_ADMIN}"
J13="$TMP/j13"; for i in 1 2 3 4 5 6; do login "$J13" "erronea-$i" "T13_intento_$i" "$A"; done
login "$J13" "$CA" T13_clave_correcta_tras_intentos "$A"
fila T13 "6 claves erróneas y luego la correcta" "$(sesion_activa "$J13")" "$(ubicacion T13_intento_6) | $(ubicacion T13_clave_correcta_tras_intentos)"

echo "Respuestas en $O (la cookie de sesión aparece como [oculta])."
