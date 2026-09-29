# Análisis de ventas y rentabilidad de una tienda en línea

**Herramientas:** SQL (MySQL 8) · Excel · Python (solo para generar y verificar datos)

## Objetivo

Identificar qué productos, categorías y clientes generan la mayor parte de los ingresos y dónde se concentran las devoluciones.

## Datos

> **Aviso:** dataset **sintético** (semilla fija) con la estructura de un e-commerce real: 5 tablas y ~101.800 registros. Se generó a propósito con duplicados, nulos y texto inconsistente para practicar la limpieza. Los resultados ilustran la metodología, no un negocio real. Ver [`docs/diccionario_datos.md`](docs/diccionario_datos.md).

| Tabla | Filas en el CSV |
|---|---|
| clientes | 8.090 |
| productos | 500 |
| pedidos | 45.230 |
| pagos | 45.000 |
| devoluciones | 2.978 |

## Estructura del repositorio

```
01-ventas-tienda-online/
├── data/                    CSV de origen (sintéticos)
├── sql/
│   ├── 01_schema.sql            crea BD, tablas staging y tablas finales
│   ├── 02_carga_datos.sql       carga los CSV a staging
│   ├── 03_limpieza.sql          limpia, crea vistas y controles de calidad
│   └── 04_consultas_analisis.sql   15 consultas comentadas
├── excel/analisis_ventas.xlsx   resúmenes con fórmulas y gráficos
├── resultados/              salida CSV de cada consulta (Q01-Q15)
├── scripts/
│   ├── generar_datos.py         genera los CSV
│   ├── verificar_con_sqlite.py  prueba el SQL y lo contrasta con pandas
│   └── construir_excel.py       arma el libro de Excel
└── docs/diccionario_datos.md
```

## Cómo reproducirlo

**Con MySQL 8 (ruta principal):**
1. Ejecuta `sql/01_schema.sql`.
2. Carga los CSV con `sql/02_carga_datos.sql` (cambia `RUTA` por tu carpeta `data/`).
3. Ejecuta `sql/03_limpieza.sql`: los controles del final deben dar 8.090 -> 8.000 clientes, 45.230 -> 45.000 pedidos y 0 huérfanos.
4. Ejecuta `sql/04_consultas_analisis.sql` consulta por consulta.

**Sin MySQL (verificación rápida):** `pip install pandas openpyxl` y luego `python scripts/verificar_con_sqlite.py`. Ejecuta los mismos scripts en SQLite y compara contra pandas.

## Proceso

1. **Modelado:** esquema relacional en dos capas (staging sin restricciones y tablas finales con PK/FK e índices).
2. **Limpieza:** 90 clientes y 230 pedidos duplicados eliminados con `ROW_NUMBER()`; nulos imputados con reglas explícitas; texto normalizado con `TRIM`/`UPPER`.
3. **Definiciones de negocio** en la vista `v_ventas` (ingreso, reembolso, utilidad).
4. **Análisis:** 15 consultas con `JOIN`, subconsultas, CTE y funciones de ventana (`RANK`, `NTILE`, `LAG`, `SUM() OVER`).
5. **Resumen en Excel** con `SUMIFS`/`COUNTIFS` y gráficos, contrastado con el SQL.

## Hallazgos

Periodo jul-2024 a dic-2025, 41.407 pedidos entregados.

| Indicador | Resultado |
|---|---|
| Ingresos | COP 18.815 millones (neto de reembolsos: 17.050 millones) |
| Margen sobre ingreso neto | 20,9 % |
| **Pareto de productos** | **85 de 500 productos (17 %) generan el 70 % de los ingresos**; el 20 % top aporta 73,9 % |
| Concentración por categoría | Electrónica = 45,9 % de los ingresos, pero con margen bajo (16,7 %) |
| **Devoluciones** | **Ropa (15,3 %) y Electrónica (14,6 %)** superan por mucho al resto (2,2 %-5,0 %) |
| Motivo principal | Ropa: talla incorrecta (57,6 %). Electrónica: producto defectuoso (52,5 %) |
| Clientes | El 25 % que más gasta aporta 67,8 % de los ingresos; los de 5+ compras, 78,1 % |
| Estacionalidad | Noviembre (+24 %) y diciembre (+10 %) de 2025 son los meses más fuertes |

**Recomendaciones (hipotéticas):** guía de tallas y fotos más precisas en Ropa; control de calidad de proveedores en Electrónica; programas de fidelización para clientes recurrentes.

## Limitaciones

- Datos sintéticos: los patrones fueron diseñados en el generador (por ejemplo, la tasa de devolución alta en Ropa y Electrónica). Con datos reales habría que validar causas.
- Un producto por pedido, sin costos de envío ni impuestos, y se asume que lo devuelto no se revende.
- Descuentos nulos imputados con 0 (afecta a ~330 pedidos): por eso el ingreso se toma de `pagos`.
- Los scripts son de MySQL 8; fueron probados en SQLite con 4 traducciones mínimas. Si encuentras un error en MySQL, abre un *issue*.

## Aprendizajes

Trabajar con staging evita que la carga falle por datos sucios; las funciones de ventana simplifican rankings y acumulados; y verificar con una segunda herramienta (pandas/Excel) detecta errores de lógica.
