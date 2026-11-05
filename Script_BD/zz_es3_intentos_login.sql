-- ES3: registro de intentos fallidos de login para frenar la fuerza bruta (H-04 / OBS-05).
-- Se ejecuta al crear la base (docker-entrypoint-initdb.d, después de pnk_security.sql) y también
-- se puede aplicar a una base existente: es idempotente.
--   docker compose exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" pnk_security' < Script_BD/zz_es3_intentos_login.sql
USE `pnk_security`;
CREATE TABLE IF NOT EXISTS `intentos_login` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `email` VARCHAR(255) NOT NULL,
  `ip` VARCHAR(45) NOT NULL,
  `momento` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_email_momento` (`email`, `momento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
