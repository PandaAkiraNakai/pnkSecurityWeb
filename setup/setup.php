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
