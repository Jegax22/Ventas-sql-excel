# Análisis de ventas y rentabilidad de una tienda en línea

Proyecto de análisis de datos orientado a evaluar el comportamiento de las ventas, la rentabilidad, las devoluciones y la concentración de ingresos de una tienda en línea.

El proyecto simula un escenario de trabajo en el que se recibe información transaccional con problemas de calidad y es necesario prepararla, validarla y analizarla antes de obtener conclusiones de negocio.

El análisis se desarrolló principalmente con **MySQL y Excel**, utilizando **Python y pandas** como apoyo para la generación y validación de los datos.

## Objetivo

Analizar el comportamiento comercial de la tienda y responder preguntas como:

* ¿Qué productos y categorías generan la mayor parte de los ingresos?
* ¿Dónde se concentra la rentabilidad?
* ¿Qué categorías presentan mayores niveles de devolución?
* ¿Cuáles son los principales motivos de devolución?
* ¿Qué tan concentrados están los ingresos entre los clientes?
* ¿Qué patrones de ventas se presentan durante el periodo analizado?

El objetivo no es únicamente obtener métricas, sino transformar los datos en información que pueda servir como apoyo para la toma de decisiones.

## Tecnologías y herramientas

* **MySQL 8:** modelado de datos, limpieza, transformación y análisis.
* **SQL:** consultas, CTE, subconsultas, funciones de ventana y agregaciones.
* **Excel:** análisis complementario, fórmulas y visualización.
* **Python:** generación del dataset y validación de resultados con pandas.

## Dataset

Los datos utilizados son **sintéticos**, generados específicamente para este proyecto. No corresponden a una empresa real.

El dataset fue construido para incluir algunos problemas comunes de calidad de datos, como duplicados, valores nulos e inconsistencias en determinados campos.

Está compuesto por aproximadamente **101.800 registros** distribuidos en cinco tablas:

| Tabla        | Registros |
| ------------ | --------: |
| clientes     |     8.090 |
| productos    |       500 |
| pedidos      |    45.230 |
| pagos        |    45.000 |
| devoluciones |     2.978 |



## Proceso de análisis

El proyecto sigue un flujo similar al utilizado en un proceso de análisis de datos:

**Datos originales → Staging → Limpieza → Validación → Transformación → Análisis → Resultados**

### 1. Modelado y carga de datos

Se diseñó un modelo relacional para trabajar con clientes, productos, pedidos, pagos y devoluciones.

La carga se realiza inicialmente sobre tablas de **staging**, sin aplicar restricciones estrictas. Esto permite revisar y limpiar los datos antes de llevarlos a las tablas finales.

Las tablas finales cuentan con claves primarias, claves foráneas e índices para mantener la integridad y facilitar las consultas.

### 2. Limpieza y calidad de datos

Durante la etapa de preparación se identificaron diferentes problemas:

* 90 registros duplicados en clientes.
* 230 registros duplicados en pedidos.
* Valores nulos en campos específicos.
* Inconsistencias de texto.
* Posibles registros huérfanos entre tablas.

Para el tratamiento de duplicados se utilizó `ROW_NUMBER()` y para la normalización de texto se utilizaron funciones como `TRIM()` y `UPPER()`.

Después de la limpieza se obtuvieron:

```text
Clientes:  8.090 → 8.000
Pedidos:   45.230 → 45.000
Huérfanos: 0
```

Además de limpiar los datos, se incluyeron controles para comprobar que las transformaciones no afectaran la integridad de las relaciones.

### 3. Definición de métricas

Se creó la vista `v_ventas` para centralizar las principales métricas utilizadas en el análisis:

* Ingresos.
* Reembolsos.
* Ingreso neto.
* Utilidad.
* Margen.

Centralizar estas definiciones permite mantener una lógica consistente entre las diferentes consultas.

### 4. Análisis exploratorio y consultas SQL

Se desarrollaron **15 consultas SQL** enfocadas en diferentes preguntas de negocio.

Entre las técnicas utilizadas se encuentran:

```sql
JOIN
CTE
Subconsultas
RANK()
NTILE()
LAG()
SUM() OVER()
```

También se utilizaron funciones de agregación y funciones relacionadas con fechas para analizar ventas, clientes, productos, categorías y devoluciones.

### 5. Validación de resultados

Los resultados obtenidos mediante SQL fueron contrastados con **pandas y Excel**.

La validación permitió comprobar cálculos como ingresos, devoluciones, rankings y acumulados desde diferentes herramientas.

Esta etapa funciona como un control adicional para reducir errores en la lógica de las consultas.

## Principales resultados

El periodo analizado comprende **julio de 2024 a diciembre de 2025**, considerando 41.407 pedidos entregados.

| Indicador                                       |           Resultado |
| ----------------------------------------------- | ------------------: |
| Ingresos                                        | COP 18.815 millones |
| Ingresos netos de reembolsos                    | COP 17.050 millones |
| Margen sobre ingreso neto                       |              20,9 % |
| Productos que generan el 70 % de los ingresos   |           85 de 500 |
| Participación del 20 % de productos principales |              73,9 % |
| Participación de Electrónica en ingresos        |              45,9 % |
| Margen de Electrónica                           |              16,7 % |
| Devoluciones en Ropa                            |              15,3 % |
| Devoluciones en Electrónica                     |              14,6 % |
| Ingresos del 25 % de clientes con mayor gasto   |              67,8 % |
| Ingresos de clientes con 5+ compras             |              78,1 % |

### Concentración de ingresos por producto

El análisis muestra una concentración significativa de los ingresos.

**85 de los 500 productos generan aproximadamente el 70 % de los ingresos**, mientras que el 20 % de los productos con mayor facturación representa el 73,9 %.

Este análisis permite identificar un grupo reducido de productos que tiene un peso importante dentro de la facturación total.

### Rentabilidad por categoría

Electrónica representa el **45,9 % de los ingresos**, pero presenta un margen del **16,7 %**.

Esto permite diferenciar entre categorías que generan un alto volumen de ingresos y categorías que presentan mejores niveles relativos de margen.

### Análisis de devoluciones

Las mayores tasas de devolución se concentran en:

* **Ropa:** 15,3 %.
* **Electrónica:** 14,6 %.

Al analizar los motivos:

* En Ropa, el principal motivo es **talla incorrecta (57,6 %)**.
* En Electrónica, el principal motivo es **producto defectuoso (52,5 %)**.

Esta segmentación permite pasar de una métrica general de devoluciones a posibles causas operativas que podrían ser investigadas.

### Concentración de clientes

El 25 % de los clientes con mayor gasto representa el **67,8 % de los ingresos**.

Por otra parte, los clientes con cinco o más compras representan el **78,1 % de los ingresos**.

Estos resultados permiten analizar la relación entre frecuencia de compra y generación de ingresos dentro del dataset.

### Comportamiento temporal

Durante 2025 se observa un incremento de la actividad comercial hacia el final del año.

Los principales cambios identificados fueron:

* **Noviembre:** +24 %.
* **Diciembre:** +10 %.

Este comportamiento puede ser relevante para análisis posteriores relacionados con inventario, campañas comerciales y planificación de ventas.

## Posibles acciones a partir del análisis

A partir de los resultados se identificaron algunas líneas de análisis que podrían evaluarse en un escenario empresarial:

* Revisar la información de tallas y medidas de los productos de Ropa.
* Analizar controles de calidad y proveedores relacionados con Electrónica.
* Estudiar estrategias de fidelización para clientes recurrentes.
* Monitorear los productos que concentran una mayor proporción de los ingresos.
* Considerar el comportamiento estacional al planificar inventario y campañas comerciales.

Estas propuestas son hipotéticas, ya que el dataset es sintético y las conclusiones tendrían que validarse con información operativa real.

## Estructura del proyecto

```text
01-ventas-tienda-online/
│
├── data/
│   └── CSV de origen
│
├── sql/
│   ├── 01_schema.sql
│   ├── 02_carga_datos.sql
│   ├── 03_limpieza.sql
│   └── 04_consultas_analisis.sql
│
├── excel/
│   └── analisis_ventas.xlsx
│
├── resultados/
│   └── Resultados de las consultas Q01-Q15
│
├── scripts/
│   ├── generar_datos.py
│   ├── verificar_con_sqlite.py
│   └── construir_excel.py
│
└── docs/
    └── diccionario_datos.md
```

## Reproducción del proyecto

### MySQL 8

Ejecutar los scripts en el siguiente orden:

```text
01_schema.sql
02_carga_datos.sql
03_limpieza.sql
04_consultas_analisis.sql
```

En `02_carga_datos.sql` se debe reemplazar `RUTA` por la ubicación local de la carpeta `data/`.

Después de ejecutar la limpieza, los controles de calidad permiten comprobar los resultados esperados:

```text
Clientes:  8.090 → 8.000
Pedidos:   45.230 → 45.000
Huérfanos: 0
```

### Validación con Python

Para ejecutar la comprobación alternativa:

```bash
pip install pandas openpyxl
python scripts/verificar_con_sqlite.py
```

El script permite contrastar parte de los resultados obtenidos mediante SQL con pandas.

## Limitaciones

El análisis tiene algunas limitaciones que deben considerarse al interpretar los resultados:

* El dataset es sintético y algunos patrones fueron definidos durante su generación.
* Cada pedido contiene un solo producto.
* No se incluyen costos de envío ni impuestos.
* Se asume que los productos devueltos no vuelven a venderse.
* Algunos valores nulos fueron tratados mediante reglas definidas durante la limpieza.
* El análisis principal está desarrollado para MySQL 8.

Por tratarse de datos sintéticos, los resultados sirven para demostrar el proceso de análisis y no deben interpretarse como información real de mercado.

## Conclusión

Este proyecto permitió desarrollar un flujo completo de análisis sobre datos transaccionales, comenzando con información sin depurar y terminando con métricas y hallazgos orientados al negocio.

El trabajo combina **SQL, limpieza y transformación de datos, análisis exploratorio, funciones de ventana, validación con pandas y visualización en Excel**.

Más allá de obtener los resultados, el objetivo fue construir un proceso reproducible en el que cada etapa pudiera ser revisada y validada antes de utilizar los datos para generar conclusiones.
