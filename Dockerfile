# Imagen de la aplicación PNKSecurity: PHP 8.3 con Apache y la extensión mysqli.
FROM php:8.3-apache
RUN docker-php-ext-install mysqli
