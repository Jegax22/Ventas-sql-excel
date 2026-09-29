-- =====================================================================
-- 02_carga_datos.sql | Ingesta Bulk
-- Utiliza LOAD DATA INFILE para optimizar throughput de E/S.
-- Requiere configuración del daemon/cliente: OPT_LOCAL_INFILE=1
-- =====================================================================

USE tienda_online;

-- Habilitamos el permiso para cargar archivos locales desde tu PC
SET GLOBAL local_infile = 1; 

-- Cargamos el CSV de clientes a su tabla temporal
LOAD DATA LOCAL INFILE 'RUTA/clientes.csv'
-- (Repetir para resto de tablas stg_)
INTO TABLE stg_clientes
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Cargamos el CSV de productos
LOAD DATA LOCAL INFILE 'RUTA/productos.csv'
INTO TABLE stg_productos
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Cargamos el CSV de pedidos
LOAD DATA LOCAL INFILE 'RUTA/pedidos.csv'
INTO TABLE stg_pedidos
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Cargamos el CSV de pagos
LOAD DATA LOCAL INFILE 'RUTA/pagos.csv'
INTO TABLE stg_pagos
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Cargamos el CSV de devoluciones
LOAD DATA LOCAL INFILE 'RUTA/devoluciones.csv'
INTO TABLE stg_devoluciones
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- =====================================================================
-- PRUEBA DE ÉXITO: Contemos cuántas filas se cargaron en cada tabla.
-- Si todo salió bien, deberías ver estos números aprox:
-- Clientes: 8090 | Productos: 500 | Pedidos: 45230 | Pagos: 45000 | Devoluciones: 2978
-- =====================================================================
SELECT 'stg_clientes' AS tabla, COUNT(*) AS filas FROM stg_clientes
UNION ALL SELECT 'stg_productos',    COUNT(*) FROM stg_productos
UNION ALL SELECT 'stg_pedidos',      COUNT(*) FROM stg_pedidos
UNION ALL SELECT 'stg_pagos',        COUNT(*) FROM stg_pagos
UNION ALL SELECT 'stg_devoluciones', COUNT(*) FROM stg_devoluciones;

