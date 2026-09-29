-- =====================================================================
-- 02_carga_datos.sql | Carga de los CSV a las tablas de staging
-- =====================================================================
-- OPCIÓN A (recomendada para empezar): asistente gráfico de MySQL Workbench
--   1. Clic derecho sobre la tabla stg_clientes > "Table Data Import Wizard".
--   2. Selecciona data/clientes.csv, destino "Use existing table" (stg_clientes).
--   3. Repite para cada CSV con su tabla stg_ correspondiente.
--
-- OPCIÓN B: LOAD DATA (rápido, reproducible). Cambia RUTA por tu carpeta data/,
-- SIEMPRE con barras "/" (también en Windows): C:/Users/tu_usuario/portafolio/01-ventas-tienda-online/data
--
--   Requisitos: el servidor debe permitir local_infile.
--     En Workbench:  Edit connection > Advanced > "Others" > OPT_LOCAL_INFILE=1
--     Y en SQL:      SET GLOBAL local_infile = 1;   (requiere usuario administrador)
-- =====================================================================

USE tienda_online;
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'RUTA/clientes.csv'
INTO TABLE stg_clientes
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'RUTA/productos.csv'
INTO TABLE stg_productos
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'RUTA/pedidos.csv'
INTO TABLE stg_pedidos
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'RUTA/pagos.csv'
INTO TABLE stg_pagos
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'RUTA/devoluciones.csv'
INTO TABLE stg_devoluciones
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Verificación: debes ver 8090 / 500 / 45230 / 45000 / 2978 filas
SELECT 'stg_clientes' AS tabla, COUNT(*) AS filas FROM stg_clientes
UNION ALL SELECT 'stg_productos',    COUNT(*) FROM stg_productos
UNION ALL SELECT 'stg_pedidos',      COUNT(*) FROM stg_pedidos
UNION ALL SELECT 'stg_pagos',        COUNT(*) FROM stg_pagos
UNION ALL SELECT 'stg_devoluciones', COUNT(*) FROM stg_devoluciones;

-- Si una fila trae un carácter invisible al final (\r) porque el CSV se guardó con
-- saltos de línea de Windows, cambia  '\n'  por  '\r\n'  en LINES TERMINATED BY.
