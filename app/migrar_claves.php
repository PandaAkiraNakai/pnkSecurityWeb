<?php
// ES3 (OBS-05): migración de una sola vez de las contraseñas en texto plano a hash.
// Solo se ejecuta por consola, nunca por HTTP (además está fuera de la raíz web):
//   docker compose exec web php /var/www/app/migrar_claves.php
// Es idempotente: las claves que ya son hash no se tocan. No imprime ninguna contraseña.
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/setup.php';

$filas = consulta("SELECT Id, email, password FROM usuarios");
$migradas = 0;
$ya_hash = 0;
while ($u = mysqli_fetch_assoc($filas)) {
    if (es_hash_de_clave((string)$u['password'])) {
        $ya_hash++;
        continue;
    }
    consulta("UPDATE usuarios SET password=? WHERE Id=?", 'si', [hash_clave((string)$u['password']), (int)$u['Id']]);
    $migradas++;
    echo "Migrada la clave de {$u['email']}\n";
}
echo "Listo: $migradas migradas, $ya_hash ya estaban como hash.\n";
