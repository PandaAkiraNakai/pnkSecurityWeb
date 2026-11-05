# Imagen de la aplicación PNKSecurity: PHP 8.5 con Apache y la extensión mysqli.
# ES3: de php:8.3-apache (8.3 solo recibe parches de seguridad) a 8.5, con soporte activo hasta
# el 31/12/2027 y de seguridad hasta el 31/12/2029 (php.net/supported-versions.php, 04/11/2026).
# La versión queda fijada para que cada build sea reproducible; se actualiza a propósito.
FROM php:8.5.12-apache
RUN docker-php-ext-install mysqli
# Configuración de producción de PHP más los ajustes del proyecto (P-01).
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY docker/php.ini "$PHP_INI_DIR/conf.d/zz-pnksecurity.ini"
# Apache sin versión en el encabezado Server ni firma en las páginas de error.
RUN sed -ri 's/^ServerTokens .*/ServerTokens Prod/; s/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
# Carpeta pública (ES3, punto 1): Apache solo publica public/. El código con la conexión
# (app/) queda fuera de la raíz web; .env, Script_BD/, evidencias/ y .git no entran a la imagen.
COPY docker/apache-pnksecurity.conf /etc/apache2/conf-available/pnksecurity.conf
RUN a2enmod headers && a2enconf pnksecurity \
 && sed -ri 's#DocumentRoot /var/www/html#DocumentRoot /var/www/public#' /etc/apache2/sites-available/000-default.conf
COPY app/ /var/www/app/
COPY public/ /var/www/public/
# Los archivos son de root y www-data solo puede leerlos: la aplicación no escribe en disco
# (las sesiones van a /tmp). Directorios 755 y archivos 644, sin 777.
RUN chown -R root:root /var/www/app /var/www/public \
 && find /var/www/app /var/www/public -type d -exec chmod 755 {} + \
 && find /var/www/app /var/www/public -type f -exec chmod 644 {} +
WORKDIR /var/www/public
