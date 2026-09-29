-- =====================================================================
-- 03_limpieza.sql | Transformación (T de ETL) y Data Quality
-- Manejo de anomalías, imputación de nulos y estandarización.
-- =====================================================================

USE tienda_online;

-- Disable constraints temporalmente para permitir reprocesamiento idempotente
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE devoluciones;
TRUNCATE TABLE pagos;
TRUNCATE TABLE pedidos;
TRUNCATE TABLE productos;
TRUNCATE TABLE clientes;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1) PRODUCTOS: Limpieza básica de espacios y conversión a números (CAST)
-- ---------------------------------------------------------------------
INSERT INTO productos (producto_id, nombre_producto, categoria, precio_lista, costo_unitario)
SELECT CAST(producto_id AS SIGNED), TRIM(nombre_producto), TRIM(categoria),
       CAST(precio_lista AS SIGNED), CAST(costo_unitario AS SIGNED)
FROM stg_productos;

-- ---------------------------------------------------------------------
-- 2) CLIENTES: Deduplicación vía partición de ventana (ROW_NUMBER) e imputación (COALESCE)
-- ---------------------------------------------------------------------
INSERT INTO clientes (cliente_id, ciudad, departamento, fecha_registro, canal_adquisicion)
SELECT CAST(cliente_id AS SIGNED),
       COALESCE(UPPER(NULLIF(TRIM(ciudad), '')), 'SIN DATO'), -- Si está vacío, pon 'SIN DATO'
       TRIM(departamento),
       fecha_registro,                                        -- MySQL detecta 'AAAA-MM-DD' y lo vuelve fecha
       TRIM(canal_adquisicion)
FROM (
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.cliente_id ORDER BY s.cliente_id) AS rn
    FROM stg_clientes s
) t
WHERE rn = 1;

-- ---------------------------------------------------------------------
-- 3) PEDIDOS: Quitamos duplicados y arreglamos descuentos nulos
-- ---------------------------------------------------------------------
INSERT INTO pedidos (pedido_id, cliente_id, producto_id, fecha_pedido, cantidad,
                     precio_unitario, descuento_pct, estado)
SELECT CAST(pedido_id AS SIGNED), CAST(cliente_id AS SIGNED), CAST(producto_id AS SIGNED),
       fecha_pedido,
       CAST(cantidad AS SIGNED), CAST(precio_unitario AS SIGNED),
       COALESCE(CAST(NULLIF(TRIM(descuento_pct), '') AS DECIMAL(5,2)), 0), -- Si no hay descuento, es 0
       TRIM(estado)
FROM (
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.pedido_id ORDER BY s.pedido_id) AS rn
    FROM stg_pedidos s
) t
WHERE rn = 1;

-- ---------------------------------------------------------------------
-- 4) PAGOS: Si no sabemos cómo pagó, le ponemos 'NO REGISTRADO'
-- ---------------------------------------------------------------------
INSERT INTO pagos (pago_id, pedido_id, metodo_pago, valor_pagado, fecha_pago)
SELECT CAST(pago_id AS SIGNED), CAST(pedido_id AS SIGNED),
       COALESCE(UPPER(NULLIF(TRIM(metodo_pago), '')), 'NO REGISTRADO'),
       CAST(valor_pagado AS SIGNED), fecha_pago
FROM stg_pagos;

-- ---------------------------------------------------------------------
-- 5) DEVOLUCIONES: Limpieza estándar (sin complicaciones)
-- ---------------------------------------------------------------------
INSERT INTO devoluciones (devolucion_id, pedido_id, fecha_devolucion, motivo, valor_reembolsado)
SELECT CAST(devolucion_id AS SIGNED), CAST(pedido_id AS SIGNED), fecha_devolucion,
       TRIM(motivo), CAST(valor_reembolsado AS SIGNED)
FROM stg_devoluciones;

-- ---------------------------------------------------------------------
-- 6) ABSTRACCIÓN DE LÓGICA DE NEGOCIO (Vistas)
-- Centraliza KPIs financieros:
-- Utilidad = Ingreso_neto (pagado - rembolsado) - Costo de ventas
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
LEFT JOIN devoluciones d ON d.pedido_id   = p.pedido_id   -- LEFT JOIN porque NO TODOS los pedidos se devuelven
WHERE p.estado = 'entregado';                             -- Solo nos importa la plata de pedidos entregados

DROP VIEW IF EXISTS v_ingresos_producto;
CREATE VIEW v_ingresos_producto AS
SELECT producto_id, nombre_producto, categoria,
       SUM(ingreso)  AS ingresos,
       SUM(cantidad) AS unidades
FROM v_ventas
GROUP BY producto_id, nombre_producto, categoria;

-- ---------------------------------------------------------------------
-- 7) AUDITORÍA / CONTROLES DE CALIDAD: Comprobando que no rompimos nada.
-- Todo profesional de datos hace estas pruebas después de limpiar.
-- ---------------------------------------------------------------------

-- 7.1 ¿Eliminamos bien los duplicados? 
-- Deberías ver que la tabla final tiene menos registros que la staging.
SELECT 'clientes' AS tabla,
       (SELECT COUNT(*) FROM stg_clientes) AS filas_staging,
       (SELECT COUNT(*) FROM clientes)     AS filas_final
UNION ALL
SELECT 'pedidos', (SELECT COUNT(*) FROM stg_pedidos), (SELECT COUNT(*) FROM pedidos);

-- 7.2 ¿Hay registros huérfanos? 
-- Pedidos que apunten a un cliente o producto que no existe. (Debería dar 0).
SELECT COUNT(*) AS pedidos_huerfanos
FROM pedidos p
LEFT JOIN clientes c  ON c.cliente_id  = p.cliente_id
LEFT JOIN productos pr ON pr.producto_id = p.producto_id
WHERE c.cliente_id IS NULL OR pr.producto_id IS NULL;

-- 7.3 Conciliación financiera:
-- Comprobamos si el pago registrado cuadra con la matemática de: Cantidad * Precio * (1 - Descuento).
-- Deberían salir unas 330 diferencias pequeñas (culpa de los nulos que imputamos).
SELECT COUNT(*) AS pedidos_con_diferencia
FROM pedidos p
JOIN pagos pg ON pg.pedido_id = p.pedido_id
WHERE p.estado <> 'cancelado'
  AND ABS(pg.valor_pagado - ROUND(p.cantidad * p.precio_unitario * (1 - p.descuento_pct / 100.0), 0)) > 1;

-- 7.4 Lógica de negocio: 
-- ¿Se le devolvió dinero a alguien de un pedido que ni siquiera se entregó? (Debería dar 0).
SELECT COUNT(*) AS devoluciones_de_pedidos_no_entregados
FROM devoluciones d
JOIN pedidos p ON p.pedido_id = d.pedido_id
WHERE p.estado <> 'entregado';