-- =====================================================================
-- 01_schema.sql | Proyecto 1: Análisis de ventas y rentabilidad
-- Motor: MySQL 8.0+   (necesario para CTE y funciones de ventana)
-- Qué hace: crea la base de datos, las tablas de STAGING y las tablas FINALES.
--
-- Diseño en dos capas (práctica profesional):
--   stg_*  -> "staging": copia fiel del CSV, todo como texto y SIN restricciones.
--             Así la carga nunca falla por datos sucios.
--   final  -> tablas tipadas, con llaves primarias/foráneas. Se llenan en
--             03_limpieza.sql, después de limpiar.
-- =====================================================================

DROP DATABASE IF EXISTS tienda_online;
CREATE DATABASE tienda_online CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tienda_online;

-- ---------------------------------------------------------------------
-- 1) STAGING (todo VARCHAR, sin PK/FK)
-- ---------------------------------------------------------------------
CREATE TABLE stg_clientes (
    cliente_id        VARCHAR(20),
    ciudad            VARCHAR(80),
    departamento      VARCHAR(80),
    fecha_registro    VARCHAR(20),
    canal_adquisicion VARCHAR(40)
);

CREATE TABLE stg_productos (
    producto_id     VARCHAR(20),
    nombre_producto VARCHAR(80),
    categoria       VARCHAR(40),
    precio_lista    VARCHAR(20),
    costo_unitario  VARCHAR(20)
);

CREATE TABLE stg_pedidos (
    pedido_id       VARCHAR(20),
    cliente_id      VARCHAR(20),
    producto_id     VARCHAR(20),
    fecha_pedido    VARCHAR(20),
    cantidad        VARCHAR(10),
    precio_unitario VARCHAR(20),
    descuento_pct   VARCHAR(10),
    estado          VARCHAR(20)
);

CREATE TABLE stg_pagos (
    pago_id      VARCHAR(20),
    pedido_id    VARCHAR(20),
    metodo_pago  VARCHAR(40),
    valor_pagado VARCHAR(20),
    fecha_pago   VARCHAR(20)
);

CREATE TABLE stg_devoluciones (
    devolucion_id     VARCHAR(20),
    pedido_id         VARCHAR(20),
    fecha_devolucion  VARCHAR(20),
    motivo            VARCHAR(40),
    valor_reembolsado VARCHAR(20)
);

-- ---------------------------------------------------------------------
-- 2) TABLAS FINALES (tipadas y con integridad referencial)
--    Orden de creación: primero las tablas "padre", luego las "hijas".
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    cliente_id        INT          NOT NULL,
    ciudad            VARCHAR(80)  NOT NULL,
    departamento      VARCHAR(80)  NOT NULL,
    fecha_registro    DATE         NOT NULL,
    canal_adquisicion VARCHAR(40)  NOT NULL,
    PRIMARY KEY (cliente_id)
);

CREATE TABLE productos (
    producto_id     INT           NOT NULL,
    nombre_producto VARCHAR(80)   NOT NULL,
    categoria       VARCHAR(40)   NOT NULL,
    precio_lista    INT           NOT NULL,
    costo_unitario  INT           NOT NULL,
    PRIMARY KEY (producto_id)
);

CREATE TABLE pedidos (
    pedido_id       INT           NOT NULL,
    cliente_id      INT           NOT NULL,
    producto_id     INT           NOT NULL,
    fecha_pedido    DATE          NOT NULL,
    cantidad        INT           NOT NULL,
    precio_unitario INT           NOT NULL,
    descuento_pct   DECIMAL(5,2)  NOT NULL DEFAULT 0,
    estado          VARCHAR(20)   NOT NULL,
    PRIMARY KEY (pedido_id),
    FOREIGN KEY (cliente_id)  REFERENCES clientes (cliente_id),
    FOREIGN KEY (producto_id) REFERENCES productos (producto_id)
);

CREATE TABLE pagos (
    pago_id      INT          NOT NULL,
    pedido_id    INT          NOT NULL,
    metodo_pago  VARCHAR(40)  NOT NULL,
    valor_pagado BIGINT       NOT NULL,
    fecha_pago   DATE         NOT NULL,
    PRIMARY KEY (pago_id),
    FOREIGN KEY (pedido_id) REFERENCES pedidos (pedido_id)
);

CREATE TABLE devoluciones (
    devolucion_id     INT          NOT NULL,
    pedido_id         INT          NOT NULL,
    fecha_devolucion  DATE         NOT NULL,
    motivo            VARCHAR(40)  NOT NULL,
    valor_reembolsado BIGINT       NOT NULL,
    PRIMARY KEY (devolucion_id),
    FOREIGN KEY (pedido_id) REFERENCES pedidos (pedido_id)
);

-- ---------------------------------------------------------------------
-- 3) ÍNDICES: aceleran los JOIN y filtros más usados en el análisis
-- ---------------------------------------------------------------------
CREATE INDEX idx_pedidos_cliente  ON pedidos (cliente_id);
CREATE INDEX idx_pedidos_producto ON pedidos (producto_id);
CREATE INDEX idx_pedidos_fecha    ON pedidos (fecha_pedido);
CREATE INDEX idx_pagos_pedido     ON pagos (pedido_id);
CREATE INDEX idx_dev_pedido       ON devoluciones (pedido_id);
