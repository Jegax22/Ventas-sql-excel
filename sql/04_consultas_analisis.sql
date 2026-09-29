-- =====================================================================
-- 04_consultas_analisis.sql | 15 consultas de análisis (MySQL 8.0+)
-- Requiere haber ejecutado 01, 02 y 03 (usa las vistas v_ventas y v_ingresos_producto).
-- Cada consulta indica: PREGUNTA de negocio, TÉCNICA SQL usada y QUÉ LEER en el resultado.
-- =====================================================================
USE tienda_online;

-- ---------------------------------------------------------------------
-- Q01 | ¿Cuántos registros hay en cada tabla?     [UNION ALL]
-- Sanity check: siempre se empieza verificando que los datos cargaron completos.
-- ---------------------------------------------------------------------
SELECT 'clientes' AS tabla, COUNT(*) AS filas FROM clientes
UNION ALL SELECT 'productos',    COUNT(*) FROM productos
UNION ALL SELECT 'pedidos',      COUNT(*) FROM pedidos
UNION ALL SELECT 'pagos',        COUNT(*) FROM pagos
UNION ALL SELECT 'devoluciones', COUNT(*) FROM devoluciones;

-- ---------------------------------------------------------------------
-- Q02 | KPIs generales del negocio     [agregaciones sobre la vista]
-- Lectura: ticket_promedio = ingreso medio por pedido; margen_pct = utilidad / ingreso neto.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                        AS pedidos_entregados,
       ROUND(SUM(ingreso), 0)                          AS ingresos,
       ROUND(SUM(reembolso), 0)                        AS reembolsos,
       ROUND(SUM(ingreso_neto), 0)                     AS ingreso_neto,
       ROUND(SUM(ingreso) * 1.0 / COUNT(*), 0)         AS ticket_promedio,
       ROUND(100.0 * SUM(utilidad) / SUM(ingreso_neto), 1) AS margen_pct
FROM v_ventas;

-- ---------------------------------------------------------------------
-- Q03 | Ingresos por mes y ventas ACUMULADAS     [CTE + SUM() OVER (ORDER BY ...)]
-- La CTE agrupa por mes; la función de ventana suma "hasta la fila actual".
-- ---------------------------------------------------------------------
WITH mensual AS (
    SELECT DATE_FORMAT(fecha_pedido, '%Y-%m') AS mes,
           SUM(ingreso)                       AS ingresos
    FROM v_ventas
    GROUP BY DATE_FORMAT(fecha_pedido, '%Y-%m')
)
SELECT mes,
       ROUND(ingresos, 0) AS ingresos,
       ROUND(SUM(ingresos) OVER (ORDER BY mes ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0)
           AS ingresos_acumulados
FROM mensual
ORDER BY mes;

-- ---------------------------------------------------------------------
-- Q04 | Variación % de ingresos frente al mes anterior     [LAG]
-- LAG(x) trae el valor de la fila anterior. El primer mes no tiene anterior (NULL).
-- ---------------------------------------------------------------------
WITH mensual AS (
    SELECT DATE_FORMAT(fecha_pedido, '%Y-%m') AS mes,
           SUM(ingreso)                       AS ingresos
    FROM v_ventas
    GROUP BY DATE_FORMAT(fecha_pedido, '%Y-%m')
),
con_anterior AS (
    SELECT mes, ingresos, LAG(ingresos) OVER (ORDER BY mes) AS ingresos_mes_anterior
    FROM mensual
)
SELECT mes,
       ROUND(ingresos, 0)               AS ingresos,
       ROUND(ingresos_mes_anterior, 0)  AS ingresos_mes_anterior,
       ROUND(100.0 * (ingresos - ingresos_mes_anterior) / ingresos_mes_anterior, 1) AS variacion_pct
FROM con_anterior
ORDER BY mes;

-- ---------------------------------------------------------------------
-- Q05 | Top 10 productos por ingresos     [RANK() OVER + LIMIT]
-- ---------------------------------------------------------------------
SELECT RANK() OVER (ORDER BY ingresos DESC) AS ranking,
       producto_id, nombre_producto, categoria,
       ROUND(ingresos, 0) AS ingresos,
       unidades
FROM v_ingresos_producto
ORDER BY ranking
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q06 | Top 3 productos DENTRO de cada categoría     [RANK() OVER (PARTITION BY ...)]
-- PARTITION BY reinicia el ranking en cada categoría. Se filtra en una consulta externa
-- porque no se puede usar un alias de ventana en el WHERE del mismo SELECT.
-- ---------------------------------------------------------------------
SELECT categoria, pos_en_categoria, nombre_producto, ROUND(ingresos, 0) AS ingresos
FROM (
    SELECT categoria, nombre_producto, ingresos,
           RANK() OVER (PARTITION BY categoria ORDER BY ingresos DESC) AS pos_en_categoria
    FROM v_ingresos_producto
) t
WHERE pos_en_categoria <= 3
ORDER BY categoria, pos_en_categoria;

-- ---------------------------------------------------------------------
-- Q07 | Ingresos, margen y participación por categoría     [GROUP BY + SUM() OVER ()]
-- SUM(SUM(x)) OVER () = total general, útil para calcular "% del total".
-- ---------------------------------------------------------------------
SELECT categoria,
       COUNT(*)                                            AS pedidos,
       ROUND(SUM(ingreso), 0)                              AS ingresos,
       ROUND(100.0 * SUM(ingreso) / SUM(SUM(ingreso)) OVER (), 1) AS participacion_pct,
       ROUND(100.0 * SUM(utilidad) / SUM(ingreso_neto), 1) AS margen_pct
FROM v_ventas
GROUP BY categoria
ORDER BY ingresos DESC;

-- ---------------------------------------------------------------------
-- Q08 | ANÁLISIS DE PARETO: ¿cuántos productos generan el 70 % de los ingresos?
--      [CTE + SUM() OVER (frame acumulado) + ROW_NUMBER + subconsultas escalares]
-- Se ordenan los productos de mayor a menor ingreso, se acumula el % y se busca
-- el primer producto donde el acumulado alcanza el 70 %.
-- ---------------------------------------------------------------------
WITH acum AS (
    SELECT producto_id, ingresos,
           ROW_NUMBER() OVER (ORDER BY ingresos DESC, producto_id) AS n,
           SUM(ingresos) OVER (ORDER BY ingresos DESC, producto_id
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado,
           SUM(ingresos) OVER () AS total
    FROM v_ingresos_producto
)
SELECT (SELECT COUNT(*) FROM productos)                                        AS total_productos,
       (SELECT MIN(n) FROM acum WHERE acumulado >= 0.70 * total)               AS productos_para_70pct_ingresos,
       ROUND(100.0 * (SELECT MIN(n) FROM acum WHERE acumulado >= 0.70 * total)
             / (SELECT COUNT(*) FROM productos), 1)                            AS pct_del_catalogo,
       ROUND(100.0 * (SELECT SUM(ingresos) FROM acum
                      WHERE n <= 0.20 * (SELECT COUNT(*) FROM productos))
             / (SELECT SUM(ingresos) FROM acum), 1)                            AS pct_ingresos_del_top20pct_productos;

-- ---------------------------------------------------------------------
-- Q09 | Tasa de devoluciones por categoría     [GROUP BY + HAVING + agregación condicional]
-- devuelto es 0/1, así que SUM(devuelto) cuenta los pedidos devueltos.
-- HAVING filtra grupos (categorías con al menos 100 pedidos, para no sacar conclusiones con poca muestra).
-- ---------------------------------------------------------------------
SELECT categoria,
       COUNT(*)                                     AS pedidos_entregados,
       SUM(devuelto)                                AS pedidos_devueltos,
       ROUND(100.0 * SUM(devuelto) / COUNT(*), 2)   AS tasa_devolucion_pct,
       ROUND(SUM(reembolso), 0)                     AS reembolsos
FROM v_ventas
GROUP BY categoria
HAVING COUNT(*) >= 100
ORDER BY tasa_devolucion_pct DESC;

-- ---------------------------------------------------------------------
-- Q10 | Motivo de devolución más frecuente por categoría     [CTE + ROW_NUMBER PARTITION]
-- ---------------------------------------------------------------------
WITH motivos AS (
    SELECT pr.categoria, d.motivo, COUNT(*) AS n
    FROM devoluciones d
    JOIN pedidos p    ON p.pedido_id    = d.pedido_id
    JOIN productos pr ON pr.producto_id = p.producto_id
    GROUP BY pr.categoria, d.motivo
),
ordenado AS (
    SELECT categoria, motivo, n,
           ROW_NUMBER() OVER (PARTITION BY categoria ORDER BY n DESC, motivo) AS pos,
           ROUND(100.0 * n / SUM(n) OVER (PARTITION BY categoria), 1)         AS pct_de_la_categoria
    FROM motivos
)
SELECT categoria, motivo AS motivo_principal, n AS devoluciones, pct_de_la_categoria
FROM ordenado
WHERE pos = 1
ORDER BY devoluciones DESC;

-- ---------------------------------------------------------------------
-- Q11 | Top 10 clientes por gasto y su % del total     [GROUP BY + subconsulta escalar]
-- ---------------------------------------------------------------------
SELECT cliente_id,
       COUNT(*)                                                    AS pedidos,
       ROUND(SUM(ingreso), 0)                                      AS gasto_total,
       ROUND(100.0 * SUM(ingreso) / (SELECT SUM(ingreso) FROM v_ventas), 2) AS pct_del_total
FROM v_ventas
GROUP BY cliente_id
ORDER BY gasto_total DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q12 | Cuartiles de clientes según gasto: ¿qué % de ingresos aporta cada 25 %?     [NTILE]
-- NTILE(4) reparte los clientes en 4 grupos del mismo tamaño (1 = los que más gastan).
-- ---------------------------------------------------------------------
WITH por_cliente AS (
    SELECT cliente_id, SUM(ingreso) AS gasto
    FROM v_ventas
    GROUP BY cliente_id
),
cuartiles AS (
    SELECT cliente_id, gasto, NTILE(4) OVER (ORDER BY gasto DESC, cliente_id) AS cuartil
    FROM por_cliente
)
SELECT cuartil,
       COUNT(*)                                                       AS clientes,
       ROUND(AVG(gasto), 0)                                           AS gasto_promedio,
       ROUND(100.0 * SUM(gasto) / (SELECT SUM(gasto) FROM por_cliente), 1) AS pct_de_ingresos
FROM cuartiles
GROUP BY cuartil
ORDER BY cuartil;

-- ---------------------------------------------------------------------
-- Q13 | Clientes de compra única vs. recurrentes     [CTE + CASE + agregación]
-- ---------------------------------------------------------------------
WITH por_cliente AS (
    SELECT cliente_id, COUNT(*) AS pedidos, SUM(ingreso) AS gasto
    FROM v_ventas
    GROUP BY cliente_id
),
segmentado AS (
    SELECT cliente_id, gasto,
           CASE WHEN pedidos = 1              THEN '1. Compra única'
                WHEN pedidos BETWEEN 2 AND 4  THEN '2. De 2 a 4 compras'
                ELSE                               '3. 5 o más compras' END AS tipo_cliente
    FROM por_cliente
)
SELECT tipo_cliente,
       COUNT(*)                                                        AS clientes,
       ROUND(SUM(gasto), 0)                                            AS ingresos,
       ROUND(100.0 * SUM(gasto) / (SELECT SUM(gasto) FROM por_cliente), 1) AS pct_de_ingresos
FROM segmentado
GROUP BY tipo_cliente
ORDER BY tipo_cliente;

-- ---------------------------------------------------------------------
-- Q14 | Ingresos y participación por método de pago     [GROUP BY + SUM(SUM()) OVER ()]
-- ---------------------------------------------------------------------
SELECT metodo_pago,
       COUNT(*)                                                     AS pedidos,
       ROUND(SUM(ingreso), 0)                                       AS ingresos,
       ROUND(100.0 * SUM(ingreso) / SUM(SUM(ingreso)) OVER (), 1)   AS participacion_pct
FROM v_ventas
GROUP BY metodo_pago
ORDER BY ingresos DESC;

-- ---------------------------------------------------------------------
-- Q15 | Productos que venden MÁS que el promedio de su propia categoría
--      [subconsulta CORRELACIONADA: se recalcula para cada fila de la consulta externa]
-- ---------------------------------------------------------------------
SELECT pp.categoria,
       pp.nombre_producto,
       ROUND(pp.ingresos, 0) AS ingresos,
       ROUND((SELECT AVG(x.ingresos) FROM v_ingresos_producto x
              WHERE x.categoria = pp.categoria), 0) AS promedio_de_su_categoria
FROM v_ingresos_producto pp
WHERE pp.ingresos > (SELECT AVG(x.ingresos) FROM v_ingresos_producto x
                     WHERE x.categoria = pp.categoria)
ORDER BY pp.categoria, pp.ingresos DESC;
