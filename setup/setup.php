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
