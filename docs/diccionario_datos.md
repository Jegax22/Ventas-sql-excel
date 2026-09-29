# Diccionario de datos

Describe cada tabla y columna. Es el documento que responde "¿qué significa esta columna?" sin tener que adivinar.

**Datos:** sintéticos, generados con `scripts/generar_datos.py` (semilla 42). Periodo: 2024-07-01 a 2025-12-31. Moneda: COP.

## Relaciones

```
clientes (1) ────< (N) pedidos (N) >──── (1) productos
                        │ 1
                        ├────< 1 pagos
                        └────< 0..1 devoluciones
```

Un pedido pertenece a un cliente y contiene un producto. Tiene un pago y, como máximo, una devolución.

## clientes (8.000 filas limpias; 8.090 en el CSV)

| Columna | Tipo | Descripción | Notas de calidad |
|---|---|---|---|
| cliente_id | INT (PK) | Identificador único | 90 filas duplicadas en el CSV |
| ciudad | VARCHAR | Ciudad del cliente | ~160 nulos -> `SIN DATO`; texto con mayúsculas/espacios inconsistentes -> `UPPER(TRIM())` |
| departamento | VARCHAR | Departamento | Sin problemas |
| fecha_registro | DATE | Fecha de alta | 2023-01-01 a 2024-06-30 |
| canal_adquisicion | VARCHAR | orgánico, redes_sociales, publicidad_pago, referido | Sin problemas |

## productos (500 filas)

| Columna | Tipo | Descripción |
|---|---|---|
| producto_id | INT (PK) | Identificador único |
| nombre_producto | VARCHAR | Código legible, p. ej. `ELE-0002` |
| categoria | VARCHAR | Electrónica, Ropa, Hogar, Deportes, Belleza, Juguetes, Libros |
| precio_lista | INT | Precio de lista en COP |
| costo_unitario | INT | Costo del producto en COP (55 %-80 % del precio) |

## pedidos (45.000 filas limpias; 45.230 en el CSV)

| Columna | Tipo | Descripción | Notas de calidad |
|---|---|---|---|
| pedido_id | INT (PK) | Identificador único | 230 filas duplicadas en el CSV |
| cliente_id | INT (FK) | Cliente que compra | |
| producto_id | INT (FK) | Producto comprado | |
| fecha_pedido | DATE | Fecha del pedido | |
| cantidad | INT | Unidades (1 a 4) | |
| precio_unitario | INT | Precio cobrado por unidad | Varía +/-3 % frente al precio de lista |
| descuento_pct | DECIMAL | 0, 5, 10, 15 o 20 | ~700 nulos -> 0 (supuesto) |
| estado | VARCHAR | entregado (92 %), cancelado (6 %), en_proceso (2 %) | |

## pagos (45.000 filas)

| Columna | Tipo | Descripción | Notas de calidad |
|---|---|---|---|
| pago_id | INT (PK) | Identificador único | |
| pedido_id | INT (FK) | Pedido pagado (1 a 1) | |
| metodo_pago | VARCHAR | tarjeta_credito, pse, contraentrega, transferencia, billetera_digital | ~450 nulos -> `NO REGISTRADO` |
| valor_pagado | BIGINT | Valor pagado en COP (0 si el pedido fue cancelado) | |
| fecha_pago | DATE | Fecha del pago | |

## devoluciones (2.978 filas)

| Columna | Tipo | Descripción |
|---|---|---|
| devolucion_id | INT (PK) | Identificador único |
| pedido_id | INT (FK) | Pedido devuelto (solo pedidos entregados) |
| fecha_devolucion | DATE | Entre 3 y 25 días después del pedido |
| motivo | VARCHAR | talla_incorrecta, producto_defectuoso, no_cumple_expectativas, llegó_dañado, otro |
| valor_reembolsado | BIGINT | Dinero devuelto (100 % o 80 % del valor pagado) |

## Métricas derivadas (vista `v_ventas`)

| Métrica | Fórmula |
|---|---|
| ingreso | `pagos.valor_pagado` de pedidos entregados |
| reembolso | `devoluciones.valor_reembolsado` (0 si no hubo devolución) |
| ingreso_neto | ingreso - reembolso |
| costo | cantidad x costo_unitario |
| utilidad | ingreso_neto - costo |
| margen % | utilidad / ingreso_neto |
| tasa de devolución | pedidos devueltos / pedidos entregados |

## Supuestos y limitaciones

1. Los datos son **sintéticos**: los hallazgos ilustran la metodología, no describen un negocio real.
2. Descuento nulo = 0. Afecta a ~330 pedidos cuyo pago sí tenía descuento; por eso el ingreso sale de `pagos`, no se recalcula.
3. Se asume que lo devuelto no se revende (utilidad conservadora).
4. Cada pedido tiene un solo producto (simplificación; en la vida real habría una tabla de líneas de pedido).
5. No hay costos de envío, comisiones ni impuestos.
