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

session_start();
$volver = '../index.php?id=' . (id_valido($_SESSION['id'] ?? null) ?? 1);

// ES3: si el correo alcanzó el límite de intentos fallidos, ni siquiera se comprueba la clave.
if (login_bloqueado($usuario)) {
    header('Location: ' . $volver . '&login=bloqueado', true, 303);
    exit;
}

// ES3 (OBS-05): se busca la cuenta solo por correo y la clave se verifica en PHP contra el
// hash guardado. La clave ya no viaja dentro del SQL ni se guarda en texto plano.
$result = consulta("SELECT Id, nombre, password FROM usuarios WHERE email=? AND estado='1'", 's', [$usuario]);
$datos = mysqli_fetch_assoc($result);
$valida = password_verify($clave, $datos['password'] ?? HASH_FICTICIO) && $datos !== null;

if (!$valida) {
    registrar_intento_fallido($usuario);
    // Mismo aviso para correo inexistente y clave errónea: no se revela cuál de los dos falló.
    header('Location: ' . $volver . '&login=invalido', true, 303);
    exit;
}

// Si el hash se creó con un costo o algoritmo anterior, se actualiza ahora que se conoce la clave.
if (password_needs_rehash($datos['password'], PASSWORD_DEFAULT, OPCIONES_HASH)) {
    consulta("UPDATE usuarios SET password=? WHERE Id=?", 'si', [hash_clave($clave), (int)$datos['Id']]);
}
consulta("DELETE FROM intentos_login WHERE email=?", 's', [$usuario]);

session_regenerate_id(true);
$_SESSION['nombre'] = $datos['nombre'];
header('Location: ' . $volver, true, 303);
exit;
