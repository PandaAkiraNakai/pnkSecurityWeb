FROM php:8.3-apache
RUN docker-php-ext-install mysqli
# Igual que XAMPP: "localhost" conecta por socket Unix compartido con el contenedor de MySQL
RUN printf 'mysqli.default_socket=/var/run/mysqld/mysqld.sock\n' > /usr/local/etc/php/conf.d/socket.ini
