-- =====================================================================
-- 03_limpieza.sql | De staging (sucio) a tablas finales (limpias)
-- =====================================================================
-- Problemas que se tratan (todos están sembrados a propósito en el generador):
--   1. Filas duplicadas exactas            -> ROW_NUMBER() y nos quedamos con la 1ª
--   2. Nulos / vacíos en ciudad            -> 'SIN DATO'
--   3. Ciudad con mayúsculas/espacios raros -> TRIM + UPPER
--   4. Nulos en descuento_pct              -> 0  (supuesto: sin dato = sin descuento)
--   5. Nulos en metodo_pago                -> 'NO REGISTRADO'
--
-- Regla de oro: NUNCA se modifican las tablas stg_*. Si algo sale mal,
-- vacías las tablas finales y repites el proceso desde la copia original.
-- =====================================================================

USE tienda_online;

-- Limpieza previa (permite ejecutar el script varias veces sin error)
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE devoluciones;
TRUNCATE TABLE pagos;
TRUNCATE TABLE pedidos;
TRUNCATE TABLE productos;
TRUNCATE TABLE clientes;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1) PRODUCTOS (no tiene problemas; solo tipado)
-- ---------------------------------------------------------------------
INSERT INTO productos (producto_id, nombre_producto, categoria, precio_lista, costo_unitario)
SELECT CAST(producto_id AS SIGNED), TRIM(nombre_producto), TRIM(categoria),
       CAST(precio_lista AS SIGNED), CAST(costo_unitario AS SIGNED)
FROM stg_productos;

-- ---------------------------------------------------------------------
-- 2) CLIENTES: duplicados + nulos + texto inconsistente
--    ROW_NUMBER() numera las filas repetidas de cada cliente_id (1, 2, ...).
--    Nos quedamos solo con rn = 1.
-- ---------------------------------------------------------------------
INSERT INTO clientes (cliente_id, ciudad, departamento, fecha_registro, canal_adquisicion)
SELECT CAST(cliente_id AS SIGNED),
       COALESCE(UPPER(NULLIF(TRIM(ciudad), '')), 'SIN DATO'),
       TRIM(departamento),
       fecha_registro,                       -- 'AAAA-MM-DD' -> MySQL lo convierte a DATE
       TRIM(canal_adquisicion)
FROM (
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.cliente_id ORDER BY s.cliente_id) AS rn
    FROM stg_clientes s
) t
WHERE rn = 1;

-- ---------------------------------------------------------------------
-- 3) PEDIDOS: duplicados + descuento nulo
-- ---------------------------------------------------------------------
INSERT INTO pedidos (pedido_id, cliente_id, producto_id, fecha_pedido, cantidad,
                     precio_unitario, descuento_pct, estado)
SELECT CAST(pedido_id AS SIGNED), CAST(cliente_id AS SIGNED), CAST(producto_id AS SIGNED),
       fecha_pedido,
       CAST(cantidad AS SIGNED), CAST(precio_unitario AS SIGNED),
       COALESCE(CAST(NULLIF(TRIM(descuento_pct), '') AS DECIMAL(5,2)), 0),
       TRIM(estado)
FROM (
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.pedido_id ORDER BY s.pedido_id) AS rn
    FROM stg_pedidos s
) t
WHERE rn = 1;

-- ---------------------------------------------------------------------
-- 4) PAGOS: método de pago nulo
-- ---------------------------------------------------------------------
INSERT INTO pagos (pago_id, pedido_id, metodo_pago, valor_pagado, fecha_pago)
SELECT CAST(pago_id AS SIGNED), CAST(pedido_id AS SIGNED),
       COALESCE(UPPER(NULLIF(TRIM(metodo_pago), '')), 'NO REGISTRADO'),
       CAST(valor_pagado AS SIGNED), fecha_pago
FROM stg_pagos;

-- ---------------------------------------------------------------------
-- 5) DEVOLUCIONES
-- ---------------------------------------------------------------------
INSERT INTO devoluciones (devolucion_id, pedido_id, fecha_devolucion, motivo, valor_reembolsado)
SELECT CAST(devolucion_id AS SIGNED), CAST(pedido_id AS SIGNED), fecha_devolucion,
       TRIM(motivo), CAST(valor_reembolsado AS SIGNED)
FROM stg_devoluciones;

-- ---------------------------------------------------------------------
-- 6) VISTAS de análisis (se definen UNA vez y se reutilizan en las 15 consultas)
--
--    DEFINICIÓN DE NEGOCIO (documentada en el README):
--      ingreso        = valor efectivamente pagado (tabla pagos), solo pedidos ENTREGADOS
--      reembolso      = dinero devuelto al cliente (tabla devoluciones)
--      ingreso_neto   = ingreso - reembolso
--      costo          = cantidad * costo_unitario
--      utilidad       = ingreso_neto - costo   (supuesto: el producto devuelto no se revende)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_ventas;
CREATE VIEW v_ventas AS
SELECT p.pedido_id,
       p.cliente_id,
       p.producto_id,
       pr.nombre_producto,
       pr.categoria,
       p.fecha_pedido,
       p.cantidad,
       pg.metodo_pago,
       pg.valor_pagado                                             AS ingreso,
       p.cantidad * pr.costo_unitario                              AS costo,
       COALESCE(d.valor_reembolsado, 0)                            AS reembolso,
       CASE WHEN d.devolucion_id IS NULL THEN 0 ELSE 1 END         AS devuelto,
       pg.valor_pagado - COALESCE(d.valor_reembolsado, 0)          AS ingreso_neto,
       pg.valor_pagado - COALESCE(d.valor_reembolsado, 0)
                       - p.cantidad * pr.costo_unitario            AS utilidad
FROM pedidos p
JOIN productos pr       ON pr.producto_id = p.producto_id
JOIN pagos pg           ON pg.pedido_id   = p.pedido_id
LEFT JOIN devoluciones d ON d.pedido_id   = p.pedido_id   -- LEFT: no todos los pedidos se devuelven
WHERE p.estado = 'entregado';

DROP VIEW IF EXISTS v_ingresos_producto;
CREATE VIEW v_ingresos_producto AS
SELECT producto_id, nombre_producto, categoria,
       SUM(ingreso)  AS ingresos,
       SUM(cantidad) AS unidades
FROM v_ventas
GROUP BY producto_id, nombre_producto, categoria;

-- ---------------------------------------------------------------------
-- 7) CONTROLES DE CALIDAD (después de limpiar SIEMPRE se verifica)
-- ---------------------------------------------------------------------

-- 7.1 Filas antes vs. después: la diferencia son los duplicados eliminados
--     Esperado: clientes 8090 -> 8000 (90 dup.) | pedidos 45230 -> 45000 (230 dup.)
SELECT 'clientes' AS tabla,
       (SELECT COUNT(*) FROM stg_clientes) AS filas_staging,
       (SELECT COUNT(*) FROM clientes)     AS filas_final
UNION ALL
SELECT 'pedidos', (SELECT COUNT(*) FROM stg_pedidos), (SELECT COUNT(*) FROM pedidos);

-- 7.2 Huérfanos: pedidos sin cliente o sin producto (esperado: 0)
SELECT COUNT(*) AS pedidos_huerfanos
FROM pedidos p
LEFT JOIN clientes c  ON c.cliente_id  = p.cliente_id
LEFT JOIN productos pr ON pr.producto_id = p.producto_id
WHERE c.cliente_id IS NULL OR pr.producto_id IS NULL;

-- 7.3 Conciliación: ¿el valor pagado coincide con cantidad x precio x (1 - descuento)?
--     Esperado: ~330 diferencias (0,7 %). Son pedidos cuyo descuento venía NULO y que
--     imputamos con 0, pero cuyo pago real SÍ incluía descuento (los nulos con descuento
--     real 0 no generan diferencia). Por eso el ingreso se toma de la tabla pagos
--     (fuente de verdad) y no se recalcula con cantidad x precio x descuento.
SELECT COUNT(*) AS pedidos_con_diferencia
FROM pedidos p
JOIN pagos pg ON pg.pedido_id = p.pedido_id
WHERE p.estado <> 'cancelado'
  AND ABS(pg.valor_pagado - ROUND(p.cantidad * p.precio_unitario * (1 - p.descuento_pct / 100.0), 0)) > 1;

-- 7.4 Devoluciones solo de pedidos entregados (esperado: 0 filas)
SELECT COUNT(*) AS devoluciones_de_pedidos_no_entregados
FROM devoluciones d
JOIN pedidos p ON p.pedido_id = d.pedido_id
WHERE p.estado <> 'entregado';
