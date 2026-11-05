<?php

require __DIR__ . "/../../app/setup.php";
session_start();

// ES3: el cierre de sesión solo se acepta por POST y con el token CSRF. Antes bastaba un
// enlace GET, así que cualquier página (o una imagen) podía cerrar la sesión del usuario.
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    responder_error(405, 'Para cerrar sesión use el botón «Cerrar sesión» de la página.');
}
csrf_verificar();

$id = id_valido($_SESSION['id'] ?? null) ?? 1;
cerrar_sesion();
header('Location: ../index.php?id=' . $id, true, 303);
exit;
