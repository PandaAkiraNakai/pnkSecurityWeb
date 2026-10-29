<?php

require __DIR__ . "/../app/setup.php";
session_start();

// H-02: solo un usuario con sesión iniciada puede comentar, y el nombre que se guarda
// es el de la sesión, no el que envíe el formulario.
if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_SESSION['nombre'])) {
    responder_error(403, 'Debe iniciar sesión para comentar.');
}
$id_restaurante = id_valido($_SESSION['id'] ?? null);
if ($id_restaurante === null) {
    responder_error(400, 'No se pudo determinar el restaurante del comentario.');
}

// Regla H-02 (ver comentario_valido): texto UTF-8 sin caracteres de control,
// de 1 a 500 caracteres una vez recortados los espacios. Si no cumple, se vuelve
// a la carta con un aviso y no se escribe nada en la base.
$comentario = comentario_valido($_POST['comentario'] ?? null);
if ($comentario === null) {
    header('Location: index.php?id=' . $id_restaurante . '&comentario=invalido#comentarios', true, 303);
    exit;
}

consulta(
    "INSERT INTO comentarios (usuario, comentario, id_restaurante) VALUES (?, ?, ?)",
    'ssi',
    [$_SESSION['nombre'], $comentario, $id_restaurante]
);

header('Location: index.php?id=' . $id_restaurante . '#comentarios', true, 303);
exit;
