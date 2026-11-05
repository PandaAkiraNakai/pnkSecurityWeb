<?php

require __DIR__ . "/../../app/setup.php";

// H-04: las credenciales del formulario se validan antes de consultar la base y la
// consulta usa parámetros. Regla: frmusuario debe ser un correo válido de hasta 255
// caracteres y frmpassword un texto no vacío de hasta 255 caracteres; si algo no cumple,
// se vuelve a la carta con un aviso y no se consulta la base.
$usuario = filter_var(trim($_POST['frmusuario'] ?? ''), FILTER_VALIDATE_EMAIL);
$clave = $_POST['frmpassword'] ?? '';
if ($_SERVER['REQUEST_METHOD'] !== 'POST' || $usuario === false || strlen($usuario) > 255
    || !is_string($clave) || $clave === '' || strlen($clave) > 255) {
    header('Location: ../index.php?id=1&login=invalido', true, 303);
    exit;
}

// Pendiente (OBS-05, Evaluación 3): las contraseñas siguen almacenadas en texto plano;
// aquí solo se evita la concatenación en el SQL.
$result = consulta("select nombre from usuarios where email=? and password=? and estado='1'", 'ss', [$usuario, $clave]);
$datos = mysqli_fetch_array($result);

session_start();
if ($datos) {
    session_regenerate_id(true);
    $_SESSION['nombre'] = $datos['nombre'];
    header('Location: ../index.php?id=' . ($_SESSION['id'] ?? 1));
} else {
    header('Location: ../index.php?id=' . ($_SESSION['id'] ?? 1) . '&login=invalido', true, 303);
}
exit;
