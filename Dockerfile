# Imagen de la aplicación PNKSecurity: PHP 8.3 con Apache y la extensión mysqli.
FROM php:8.3-apache
RUN docker-php-ext-install mysqli
# Configuración de producción de PHP más los ajustes del proyecto (P-01).
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY docker/php.ini "$PHP_INI_DIR/conf.d/zz-pnksecurity.ini"
# Apache sin versión en el encabezado Server ni firma en las páginas de error.
RUN sed -ri 's/^ServerTokens .*/ServerTokens Prod/; s/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
