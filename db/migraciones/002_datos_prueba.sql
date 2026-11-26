-- 002 · Datos de prueba
-- Restaurantes, cartas, categorías e ítems tomados del volcado de la versión PHP
-- (Script_BD/pnk_security.sql). Las cuentas son ficticias y su contraseña de prueba está en
-- el README; aquí solo queda el hash bcrypt (costo 12), nunca la contraseña en claro.

INSERT INTO direcciones (id, calle, numero, comuna, region) VALUES
  (1, 'Los Arandanos', '1550', 'La Serena', 'Coquimbo'),
  (2, 'Avenida Argentina', '951', 'La Serena', 'Coquimbo'),
  (3, 'Balmaceda', '357', 'La Serena', 'Coquimbo'),
  (4, 'Peru', '2255', 'La Serena', 'Coquimbo'),
  (5, 'Miraflores', '36', 'Ovalle', 'Coquimbo');

INSERT INTO restaurantes (id, rut, nombre, fono, email, foto, direccion_id) VALUES
  (1, '99887766-5', 'Afríca Restobar', '22334455', 'mail@correo.cl', 'resto1.jpg', 2),
  (2, '88776655-4', 'Restaurant la Bahía', '512323232', 'mail1@correo.cl', 'resto2.jpg', 3),
  (3, '22334455-6', 'La Esquina del Sabor', '22334455', 'mail2@correo.cl', NULL, 4),
  (4, '258-3', 'La Pica de Armando', '223366', 'mail3@correo.cl', NULL, 5);

INSERT INTO cartas (id, restaurante_id, nombre, orden, visible, foto) VALUES
  (1, 1, 'Vinos', 1, true, 'carta2.jpg'),
  (2, 1, 'Bebidas', 2, true, 'carta2.jpg'),
  (3, 1, 'Entradas', 3, true, 'carta3.jpg'),
  (4, 1, 'Principales', 4, true, 'carta6.jpg'),
  (5, 1, 'Postres', 5, true, 'carta6.jpg'),
  (10, 2, 'Vinos', 1, true, 'carta11.jpg'),
  (11, 2, 'Principal', 2, true, 'carta11.jpg');

INSERT INTO categorias (id, carta_id, nombre, visible, orden) VALUES
  (1, 1, 'Blancos', true, 1),
  (2, 1, 'Tintos', true, 2),
  (3, 4, 'Carnes', true, 1),
  (4, 4, 'Pescados', true, 2),
  (5, 4, 'Mariscos', true, 3),
  (6, 4, 'Pastas', true, 4),
  (7, 3, 'Frías', true, 1),
  (8, 3, 'Calientes', true, 2),
  (9, 4, 'Comida casera', false, NULL),
  (10, 2, 'Con Alcohol', true, 1),
  (12, 10, 'Blancos', true, 2),
  (13, 10, 'Tintos', true, 1),
  (14, 11, 'Carnes', true, 1);

INSERT INTO items (id, categoria_id, nombre, descripcion, tiempo, observaciones, precio, visible, destacado, puntuacion, foto, orden, eliminado) VALUES
  (1, 7, 'Ensalada César', 'Ensalada con queso', '15 minutos', NULL, 3500, true, false, 4, 'item1.jpg', 1, NULL),
  (2, 8, 'Crema de espinacas', 'Crema a base de espinacas y finas hierbas', '20 minutos', NULL, 2000, true, true, 4, 'item2.jpg', 2, NULL),
  (3, 9, 'Porotos granados', 'Porotos con verduras', '25 minutos', NULL, 3500, true, false, 5, 'item3.jpg', NULL, '2020-09-29 02:02:48-03'),
  (4, 10, 'Pisco sour', 'Pisco sour casero', '15 minutos', NULL, 3500, true, false, 0, 'item4.jpg', NULL, NULL),
  (5, 3, 'Lomo a lo pobre', 'Lomo con papas fritas, huevo y cebolla', '30 minutos', 'Muy sabroso', 12500, true, true, 5, 'item5.jpg', 1, NULL),
  (7, 14, 'Lomo a lo pobre', 'Lomo a lo pobre', '20 minutos', 'Rico lomo a lo pobre', 9900, true, true, 3, 'item3.jpg', 2, NULL);

-- Contraseña de prueba de ambas cuentas: ver README (sección "Cuentas de prueba")
INSERT INTO usuarios (id, nombre, email, password_hash) VALUES
  (1, 'Alondra', 'alondra@pnk.test', '$2b$12$IDXlOkp7rWo7IYBXO5Slc.hYbSuJocJ/0plT4rJODDzR7GMQD6ga.'),
  (2, 'Bruno', 'bruno@pnk.test', '$2b$12$IDXlOkp7rWo7IYBXO5Slc.hYbSuJocJ/0plT4rJODDzR7GMQD6ga.');

INSERT INTO comentarios (restaurante_id, usuario_id, texto) VALUES
  (1, 2, 'Muy buena atención y el lomo a lo pobre, excelente.');

-- Las identidades siguen después de los id cargados a mano
SELECT setval(pg_get_serial_sequence('direcciones', 'id'), (SELECT max(id) FROM direcciones));
SELECT setval(pg_get_serial_sequence('restaurantes', 'id'), (SELECT max(id) FROM restaurantes));
SELECT setval(pg_get_serial_sequence('cartas', 'id'), (SELECT max(id) FROM cartas));
SELECT setval(pg_get_serial_sequence('categorias', 'id'), (SELECT max(id) FROM categorias));
SELECT setval(pg_get_serial_sequence('items', 'id'), (SELECT max(id) FROM items));
SELECT setval(pg_get_serial_sequence('usuarios', 'id'), (SELECT max(id) FROM usuarios));
