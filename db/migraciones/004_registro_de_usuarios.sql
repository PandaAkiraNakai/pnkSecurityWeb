-- 004 · Registro de cuentas desde la interfaz
-- La API ahora puede crear usuarios. Solo recibe permiso de INSERT sobre las columnas que llena
-- (nombre, email y el hash); "activo", los contadores de intentos y "creado" quedan con sus
-- valores por defecto y la API no puede fijarlos. Sigue sin poder cambiar ni borrar usuarios.
GRANT INSERT (nombre, email, password_hash) ON usuarios TO pnk_app;
GRANT USAGE ON SEQUENCE usuarios_id_seq TO pnk_app;

-- Nombre visible acotado (el registro valida además el formato en la API)
ALTER TABLE usuarios ADD CONSTRAINT usuarios_nombre_largo CHECK (char_length(btrim(nombre)) BETWEEN 2 AND 60);
