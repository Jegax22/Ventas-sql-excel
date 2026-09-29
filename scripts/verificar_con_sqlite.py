"""
verificar_con_sqlite.py | Validación cruzada y ejecución in-memory
=====================================================================================
Propósito: Validar la lógica SQL de negocio contra una implementación en Pandas (testing cruzado).
Arquitectura:
  1. Levanta SQLite in-memory (evita dependencias de motor externo para testing).
  2. Transpila dialecto MySQL a SQLite al vuelo mediante Regex.
  3. Ejecuta DDL y DML (ETL pipeline).
  4. Compara salidas de consultas SQL vs resultados de DataFrames aplicando tolerancias.
"""
import re
import sqlite3
from pathlib import Path
import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
SQL_DIR, DATA_DIR, RES_DIR = RAIZ / "sql", RAIZ / "data", RAIZ / "resultados"
RES_DIR.mkdir(exist_ok=True)

def quitar_comentarios(texto: str) -> str:
    return "\n".join(l for l in texto.splitlines() if not l.strip().startswith("--"))

def traducir(sql: str) -> str:
    # Transpilación básica MySQL -> SQLite para permitir ejecución in-memory
    sql = re.sub(r"(?im)^\s*(USE\s+\w+|SET\s+[^;]+|DROP DATABASE[^;]+|CREATE DATABASE[^;]+)\s*;", "", sql)
    sql = re.sub(r"(?i)TRUNCATE TABLE (\w+)", r"DELETE FROM \1", sql)
    sql = re.sub(r"DATE_FORMAT\(\s*(\w+)\s*,\s*'%Y-%m'\s*\)", r"strftime('%Y-%m', \1)", sql)
    return sql

def sentencias(texto: str):
    return [s.strip() for s in texto.split(";") if s.strip()]

# Instanciar DB in-memory y registrar función escalar UPPER para soporte Unicode básico
con = sqlite3.connect(":memory:")
con.create_function("UPPER", 1, lambda s: s.upper() if s is not None else None)   

# ---- 1. DDL: Esquema
for s in sentencias(traducir(quitar_comentarios((SQL_DIR / "01_schema.sql").read_text(encoding="utf-8")))):
    con.execute(s)

# ---- 2. Carga Staging
for t in ["clientes", "productos", "pedidos", "pagos", "devoluciones"]:
    df = pd.read_csv(DATA_DIR / f"{t}.csv", dtype=str, keep_default_na=False)
    df.to_sql(f"stg_{t}", con, if_exists="append", index=False)

# ---- 3. Transformación y Calidad (Pipeline)
print("=== 03_limpieza.sql: controles de calidad ===")
for s in sentencias(traducir(quitar_comentarios((SQL_DIR / "03_limpieza.sql").read_text(encoding="utf-8")))):
    cur = con.execute(s)
    # Output de auditoría (Data Quality checks)
    if s.lstrip().upper().startswith("SELECT"):
        cols = [c[0] for c in cur.description]
        print(pd.DataFrame(cur.fetchall(), columns=cols).to_string(index=False), "\n")

# ---- 4. Ejecución de Consultas de Negocio
texto = (SQL_DIR / "04_consultas_analisis.sql").read_text(encoding="utf-8")
consultas, actual, buffer = {}, None, []

# Parseo del script SQL segmentando por bloque (marcador -- Qxx)
for linea in texto.splitlines():
    m = re.match(r"^-- (Q\d\d) \|", linea)
    if m:
        if actual:
            consultas[actual] = "\n".join(buffer)
        actual, buffer = m.group(1), []
    elif not linea.strip().startswith("--") and actual:
        buffer.append(linea)
consultas[actual] = "\n".join(buffer)

resultados = {}
for q, sql in consultas.items():
    sql = traducir(sql).strip().rstrip(";")
    cur = con.execute(sql)
    cols = [c[0] for c in cur.description]
    df = pd.DataFrame(cur.fetchall(), columns=cols)
    resultados[q] = df
    df.to_csv(RES_DIR / f"{q}.csv", index=False, encoding="utf-8")
print(f"{len(resultados)} consultas ejecutadas sin errores -> resultados en {RES_DIR}")

# Exportar dataset consolidado para el generador de reportes (Excel)
base = pd.read_sql("SELECT v.pedido_id, v.cliente_id, v.producto_id, v.nombre_producto, v.categoria, "
                   "v.fecha_pedido, v.cantidad, v.metodo_pago, v.ingreso, v.costo, v.reembolso, v.devuelto "
                   "FROM v_ventas v ORDER BY v.pedido_id", con)
(RAIZ / "excel").mkdir(exist_ok=True)
base.to_csv(RAIZ / "excel" / "base_pedidos.csv", index=False, encoding="utf-8")

# ======================================================================================
# VALIDACIÓN CRUZADA: Implementación homóloga en Pandas
# ======================================================================================
print("\n=== Verificación cruzada SQL vs pandas ===")
ped = pd.read_csv(DATA_DIR / "pedidos.csv").drop_duplicates("pedido_id")
pag = pd.read_csv(DATA_DIR / "pagos.csv")
prd = pd.read_csv(DATA_DIR / "productos.csv")
dev = pd.read_csv(DATA_DIR / "devoluciones.csv")

# Denormalización base
v = (ped[ped.estado == "entregado"].merge(prd, on="producto_id").merge(pag[["pedido_id", "valor_pagado", "metodo_pago"]], on="pedido_id")
     .merge(dev[["pedido_id", "valor_reembolsado"]], on="pedido_id", how="left"))

# Cálculo de variables financieras
v["reembolso"] = v.valor_reembolsado.fillna(0)
v["devuelto"] = v.valor_reembolsado.notna().astype(int)
v["ingreso"] = v.valor_pagado
v["neto"] = v.ingreso - v.reembolso
v["utilidad"] = v.neto - v.cantidad * v.costo_unitario

def comprobar(nombre, sql_val, pd_val, tol=1.0):
    # Función de aserción aplicando umbral de tolerancia para inconsistencias de precisión flotante
    ok = abs(float(sql_val) - float(pd_val)) <= tol
    print(f"[{'OK' if ok else 'FALLA'}] {nombre:45s} SQL={float(sql_val):>18,.2f}   pandas={float(pd_val):>18,.2f}")
    assert ok, f"Diferencia en {nombre}"

k = resultados["Q02"].iloc[0]
comprobar("Pedidos entregados", k.pedidos_entregados, len(v), 0)
comprobar("Ingresos", k.ingresos, v.ingreso.sum())
comprobar("Reembolsos", k.reembolsos, v.reembolso.sum())
comprobar("Margen %", k.margen_pct, 100 * v.utilidad.sum() / v.neto.sum(), 0.06)

ing_prod = v.groupby("producto_id").ingreso.sum().sort_values(ascending=False)
n70 = int((ing_prod.cumsum() / ing_prod.sum() < 0.70).sum() + 1)
q8 = resultados["Q08"].iloc[0]
comprobar("Productos para 70 % de ingresos (Pareto)", q8.productos_para_70pct_ingresos, n70, 0)
comprobar("% ingresos del top 20 % de productos", q8.pct_ingresos_del_top20pct_productos,
          100 * ing_prod.head(int(0.2 * len(prd))).sum() / ing_prod.sum(), 0.06)

tasa = v.groupby("categoria").devuelto.mean() * 100
for _, r in resultados["Q09"].iterrows():
    comprobar(f"Tasa devolución {r.categoria}", r.tasa_devolucion_pct, tasa[r.categoria], 0.006)

mensual = v.groupby(v.fecha_pedido.str[:7]).ingreso.sum()
q3 = resultados["Q03"]
comprobar("Ingresos mes (último)", q3.ingresos.iloc[-1], mensual.iloc[-1])
comprobar("Ingresos acumulados (último) = total", q3.ingresos_acumulados.iloc[-1], v.ingreso.sum())

q12 = resultados["Q12"]
comprobar("Cuartiles suman 100 %", q12.pct_de_ingresos.sum(), 100, 0.3)
print("\nTodas las verificaciones pasaron.")