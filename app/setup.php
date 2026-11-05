<?php

// Conexión a la base de datos (T-U2-01, OBS-01/OBS-02/OBS-12).
// Host, usuario, clave y base se leen del entorno (ver compose.yaml y .env.example);
// el código no contiene credenciales. Se abre una sola conexión por petición y
// cualquier error de MySQL se convierte en excepción (no se devuelve false silencioso).
function conectar()
{
    static $con = null;
    if ($con instanceof mysqli) {
        return $con;
    }
    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
    $con = mysqli_connect(
        getenv('DB_HOST') ?: 'localhost',
        getenv('DB_USER') ?: '',
        getenv('DB_PASSWORD') ?: '',
        getenv('DB_NAME') ?: 'pnk_security'
    );
    mysqli_set_charset($con, 'utf8mb4');
    return $con;
}

// Ejecuta una consulta preparada. $tipos sigue el formato de mysqli_stmt_bind_param
// ("i" entero, "s" texto): los valores viajan como parámetros y nunca se concatenan al SQL.
function consulta(string $sql, string $tipos = '', array $valores = [])
{
    $stmt = mysqli_prepare(conectar(), $sql);
    if ($tipos !== '') {
        mysqli_stmt_bind_param($stmt, $tipos, ...$valores);
    }
    mysqli_stmt_execute($stmt);
    return mysqli_stmt_get_result($stmt);
}

// Regla H-01: un identificador es válido solo si es un entero entre 1 y 2147483647
// (rango de INT en MySQL). Devuelve el entero, o null si falta o no cumple la regla.
function id_valido($valor): ?int
{
    if (!is_string($valor) && !is_int($valor)) {
        return null;
    }
    $id = filter_var($valor, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 2147483647]]);
    return $id === false ? null : $id;
}

// Regla H-02: un comentario es válido solo si es texto UTF-8 correcto, sin caracteres de
// control (se aceptan saltos de línea y tabulador) y con 1 a 500 caracteres después de
// recortar los espacios de los extremos. Devuelve el texto normalizado o null.
function comentario_valido($valor): ?string
{
    if (!is_string($valor)) {
        return null;
    }
    $texto = str_replace("\r\n", "\n", trim($valor));
    if ($texto === '' || !mb_check_encoding($texto, 'UTF-8')) {
        return null;
    }
    if (preg_match('/[^\P{C}\n\t]/u', $texto)) {
        return null;
    }
    if (mb_strlen($texto, 'UTF-8') > 500) {
        return null;
    }
    return $texto;
}

// Contraseñas (ES3, OBS-05): se guardan con password_hash() (bcrypt, el algoritmo por
// defecto de PHP) y se comprueban con password_verify(), que compara en tiempo constante.
// El costo 12 hace que cada intento tome del orden de 200 ms: invisible para un usuario,
// pero muy caro para quien quiera probar millones de claves con una copia de la tabla.
const OPCIONES_HASH = ['cost' => 12];

function hash_clave(string $clave): string
{
    return password_hash($clave, PASSWORD_DEFAULT, OPCIONES_HASH);
}

function es_hash_de_clave(string $valor): bool
{
    return password_get_info($valor)['algo'] !== null;
}

// Hash de una clave aleatoria que nadie conoce. Se verifica contra él cuando el correo no
// existe, para que el tiempo de respuesta no revele qué cuentas están registradas.
const HASH_FICTICIO = '$2y$12$3XHSj6iOgjxG9TV5q41cBuwVfXNKqCb2qBeNPT8zX23N2eufviyl.';

// Límite de intentos de login (ES3): MAX_INTENTOS fallos para un mismo correo dentro de
// VENTANA_MINUTOS bloquean ese correo durante la ventana, aunque luego se envíe la clave
// correcta. Se cuenta por correo (exista o no), así el bloqueo tampoco revela cuentas.
const MAX_INTENTOS = 5;
const VENTANA_MINUTOS = 15;

function login_bloqueado(string $email): bool
{
    $r = consulta(
        "SELECT COUNT(*) AS n FROM intentos_login WHERE email=? AND momento > (NOW() - INTERVAL " . VENTANA_MINUTOS . " MINUTE)",
        's',
        [$email]
    );
    return (int)mysqli_fetch_assoc($r)['n'] >= MAX_INTENTOS;
}

function registrar_intento_fallido(string $email): void
{
    consulta("INSERT INTO intentos_login (email, ip) VALUES (?, ?)", 'ss', [$email, $_SERVER['REMOTE_ADDR'] ?? '']);
    // Limpieza: los intentos de más de un día ya no sirven para el bloqueo.
    consulta("DELETE FROM intentos_login WHERE momento < (NOW() - INTERVAL 1 DAY)");
}

// Codificación de salida para HTML: todo dato que viene de la base o del usuario pasa
// por aquí antes de imprimirse (OBS-14; complementa la validación, no la reemplaza).
// Reemplaza a utf8_encode(), obsoleta desde PHP 8.2 e innecesaria con la conexión en
// utf8mb4 (OBS-11).
function e($texto): string
{
    return htmlspecialchars((string)$texto, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

// Respuesta controlada ante una petición inválida o un recurso inexistente:
// código HTTP y mensaje genérico, sin rutas, consultas ni trazas (P-01).
function responder_error(int $codigo, string $mensaje): void
{
    http_response_code($codigo);
    header('Content-Type: text/html; charset=UTF-8');
    echo '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>PNKSecurity</title>'
       . '<link rel="stylesheet" href="vendors/bootstrap/bootstrap.min.css"></head><body>'
       . '<div class="container mt-5"><div class="alert alert-warning"><h4>Error ' . $codigo . '</h4><p>'
       . htmlspecialchars($mensaje, ENT_QUOTES, 'UTF-8')
       . '</p><a href="index.php?id=1">Volver a la carta</a></div></div></body></html>';
    exit;
}

function quitarespacios($titulo)
{
    $titulo =str_replace(" ", "", $titulo);
    $cadena =str_replace("ñ", "", $titulo);
    $cadena =str_replace("Ñ", "", $cadena);
    return $cadena;
}

function moneda_chilena($numero){
    $numero = (string)$numero;
    $puntos = floor((strlen($numero)-1)/3);
    $tmp = "";
    $pos = 1;
    for($i=strlen($numero)-1; $i>=0; $i--){
    $tmp = $tmp.substr($numero, $i, 1);
    if($pos%3==0 && $pos!=strlen($numero))
    $tmp = $tmp.".";
    $pos = $pos + 1;
    }
    $formateado = "$ ".strrev($tmp);
    return $formateado;
    }

?>
