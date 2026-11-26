-- 003 · Fotos acordes a lo que dice cada plato, carta y local
-- En los datos heredados de la versión PHP varias fotos no correspondían: "Crema de espinacas"
-- mostraba un lomo a lo pobre, el lomo del restaurante 2 apuntaba a una foto de porotos de otro
-- local, la foto de "Restaurant la Bahía" era un logo y algunas cartas usaban fotos de otra
-- sección. Se corrige con una migración nueva (la 002 ya está aplicada y no se edita).
-- Las fotos viven en frontend/public/imagenes/cod<id del restaurante>/; créditos en CREDITOS.md.

-- Platos
UPDATE items SET foto = 'crema-de-espinacas.jpg' WHERE id = 2;   -- Crema de espinacas (antes: foto de un lomo)
UPDATE items SET foto = 'lomo-a-lo-pobre.jpg'    WHERE id = 7;   -- Lomo a lo pobre, restaurante 2 (antes: porotos de cod1)

-- Cartas
UPDATE cartas SET foto = 'carta1.jpg'  WHERE id = 1;    -- Vinos (antes: bebidas)
UPDATE cartas SET foto = 'carta12.jpg' WHERE id = 4;    -- Principales (antes: helados)
UPDATE cartas SET foto = 'carta10.jpg' WHERE id = 10;   -- Vinos, restaurante 2 (antes: pollo asado)

-- Locales
UPDATE restaurantes SET foto = 'la-bahia.jpg' WHERE id = 2;   -- Restaurant la Bahía (antes: un logo)
