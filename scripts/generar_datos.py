"""
generar_datos.py  |  Proyecto 1 - Análisis de ventas y rentabilidad de una tienda en línea
=====================================================================================
Genera un dataset SINTÉTICO de comercio electrónico con la misma estructura que
usarías con un dataset público real (5 tablas relacionadas):

    clientes, productos, pedidos, pagos, devoluciones   (~100.000 registros en total)

¿Por qué sintético?  Para que el proyecto sea 100 % reproducible sin descargar nada.
El generador incluye "suciedad" a propósito (duplicados, nulos, texto inconsistente)
para que la fase de limpieza tenga sentido.

Uso:
    python generar_datos.py            # escribe los CSV en ../data/

La semilla (SEED) es fija: cualquiera que lo ejecute obtiene exactamente los mismos datos.
"""
from pathlib import Path
import numpy as np
import pandas as pd

SEED = 42
rng = np.random.default_rng(SEED)
OUT = Path(__file__).resolve().parent.parent / "data"
OUT.mkdir(exist_ok=True)

N_CLIENTES, N_PRODUCTOS, N_PEDIDOS = 8000, 500, 45000
FECHA_INI, FECHA_FIN = pd.Timestamp("2024-07-01"), pd.Timestamp("2025-12-31")

# ------------------------------------------------------------------ PRODUCTOS
# categoria: (nº de productos, precio mínimo, precio máximo en COP, prob. devolución)
CATEGORIAS = {
    "Electrónica": (80, 150_000, 2_500_000, 0.140),
    "Ropa":        (100, 40_000,    300_000, 0.160),
    "Hogar":       (90,  30_000,    800_000, 0.040),
    "Deportes":    (70,  50_000,    600_000, 0.045),
    "Belleza":     (60,  15_000,    200_000, 0.035),
    "Juguetes":    (50,  20_000,    250_000, 0.040),
    "Libros":      (50,  25_000,    120_000, 0.020),
}
filas = []
pid = 1
for cat, (n, pmin, pmax, _) in CATEGORIAS.items():
    for _ in range(n):
        precio = int(round(rng.uniform(pmin, pmax), -2))
        costo = int(round(precio * rng.uniform(0.55, 0.80), -2))
        filas.append((pid, f"{cat[:3].upper()}-{pid:04d}", cat, precio, costo))
        pid += 1
productos = pd.DataFrame(filas, columns=["producto_id", "nombre_producto", "categoria", "precio_lista", "costo_unitario"])

# ------------------------------------------------------------------ CLIENTES
CIUDADES = [("Bogotá", "Cundinamarca"), ("Medellín", "Antioquia"), ("Cali", "Valle del Cauca"),
            ("Barranquilla", "Atlántico"), ("Cartagena", "Bolívar"), ("Bucaramanga", "Santander"),
            ("Ibagué", "Tolima"), ("Pereira", "Risaralda"), ("Manizales", "Caldas"),
            ("Cúcuta", "Norte de Santander"), ("Neiva", "Huila"), ("Santa Marta", "Magdalena")]
pesos_ciudad = np.array([28, 18, 12, 8, 6, 6, 5, 5, 4, 3, 3, 2], dtype=float)
pesos_ciudad /= pesos_ciudad.sum()
idx_ciudad = rng.choice(len(CIUDADES), N_CLIENTES, p=pesos_ciudad)
clientes = pd.DataFrame({
    "cliente_id": np.arange(1, N_CLIENTES + 1),
    "ciudad": [CIUDADES[i][0] for i in idx_ciudad],
    "departamento": [CIUDADES[i][1] for i in idx_ciudad],
    "fecha_registro": (pd.Timestamp("2023-01-01") + pd.to_timedelta(rng.integers(0, 547, N_CLIENTES), unit="D")).strftime("%Y-%m-%d"),
    "canal_adquisicion": rng.choice(["orgánico", "redes_sociales", "publicidad_pago", "referido"], N_CLIENTES, p=[.35, .30, .25, .10]),
})

# ------------------------------------------------------------------ PEDIDOS
# Popularidad de productos y de clientes: log-normal (pocos muy populares, muchos poco populares)
w_prod = rng.lognormal(0, 1.2, N_PRODUCTOS)   # sigma=1.2 -> concentración tipo Pareto
w_prod /= w_prod.sum()
w_cli = rng.lognormal(0, 1.0, N_CLIENTES)
w_cli /= w_cli.sum()

dias = (FECHA_FIN - FECHA_INI).days + 1
fechas_base = pd.date_range(FECHA_INI, FECHA_FIN)
# Estacionalidad: más ventas en nov-dic y un leve crecimiento en el tiempo
peso_dia = np.array([1.0 + 0.5 * (d.month in (11, 12)) + 0.25 * (d.month == 6) + 0.0008 * i
                     for i, d in enumerate(fechas_base)])
peso_dia /= peso_dia.sum()
fecha_pedido = np.sort(fechas_base[rng.choice(dias, N_PEDIDOS, p=peso_dia)])  # ids crecientes en el tiempo

prod_ids = rng.choice(productos["producto_id"].to_numpy(), N_PEDIDOS, p=w_prod)
precio_lista = productos.set_index("producto_id").loc[prod_ids, "precio_lista"].to_numpy()
pedidos = pd.DataFrame({
    "pedido_id": np.arange(100001, 100001 + N_PEDIDOS),
    "cliente_id": rng.choice(clientes["cliente_id"].to_numpy(), N_PEDIDOS, p=w_cli),
    "producto_id": prod_ids,
    "fecha_pedido": pd.DatetimeIndex(fecha_pedido).strftime("%Y-%m-%d"),
    "cantidad": rng.choice([1, 2, 3, 4], N_PEDIDOS, p=[.72, .18, .07, .03]),
    "precio_unitario": (precio_lista * rng.uniform(0.97, 1.03, N_PEDIDOS)).round(-2).astype(int),
    "descuento_pct": rng.choice([0, 5, 10, 15, 20], N_PEDIDOS, p=[.50, .20, .15, .10, .05]).astype(float),
    "estado": rng.choice(["entregado", "cancelado", "en_proceso"], N_PEDIDOS, p=[.92, .06, .02]),
})

# ------------------------------------------------------------------ PAGOS
metodo = rng.choice(["tarjeta_credito", "pse", "contraentrega", "transferencia", "billetera_digital"],
                    N_PEDIDOS, p=[.45, .25, .18, .07, .05])
valor_neto = (pedidos["cantidad"] * pedidos["precio_unitario"] * (1 - pedidos["descuento_pct"] / 100)).round(0)
pagos = pd.DataFrame({
    "pago_id": np.arange(1, N_PEDIDOS + 1),
    "pedido_id": pedidos["pedido_id"],
    "metodo_pago": metodo,
    "valor_pagado": np.where(pedidos["estado"] == "cancelado", 0, valor_neto).astype(int),
    "fecha_pago": pedidos["fecha_pedido"],
})

# ------------------------------------------------------------------ DEVOLUCIONES
cat_por_pedido = productos.set_index("producto_id").loc[pedidos["producto_id"], "categoria"].to_numpy()
p_dev = np.array([CATEGORIAS[c][3] for c in cat_por_pedido])
hay_dev = (rng.random(N_PEDIDOS) < p_dev) & (pedidos["estado"].to_numpy() == "entregado")
MOTIVOS = {
    "Electrónica": (["producto_defectuoso", "no_cumple_expectativas", "llegó_dañado", "otro"], [.50, .20, .20, .10]),
    "Ropa":        (["talla_incorrecta", "no_cumple_expectativas", "llegó_dañado", "otro"], [.55, .25, .10, .10]),
}
MOT_DEFAULT = (["no_cumple_expectativas", "llegó_dañado", "producto_defectuoso", "otro"], [.40, .25, .20, .15])
dev_rows = []
for i in np.where(hay_dev)[0]:
    lst, pr = MOTIVOS.get(cat_por_pedido[i], MOT_DEFAULT)
    f0 = pd.Timestamp(pedidos.loc[i, "fecha_pedido"])
    dev_rows.append((int(pedidos.loc[i, "pedido_id"]),
                     (f0 + pd.Timedelta(days=int(rng.integers(3, 26)))).strftime("%Y-%m-%d"),
                     str(rng.choice(lst, p=pr)),
                     int(round(valor_neto[i] * rng.choice([1.0, 0.8], p=[.85, .15]), 0))))
devoluciones = pd.DataFrame(dev_rows, columns=["pedido_id", "fecha_devolucion", "motivo", "valor_reembolsado"])
devoluciones.insert(0, "devolucion_id", np.arange(1, len(devoluciones) + 1))

# ------------------------------------------------------------------ "SUCIEDAD" A PROPÓSITO
# (1) nulos
clientes.loc[rng.choice(N_CLIENTES, 160, replace=False), "ciudad"] = None
pedidos.loc[rng.choice(N_PEDIDOS, 700, replace=False), "descuento_pct"] = np.nan
pagos.loc[rng.choice(N_PEDIDOS, 450, replace=False), "metodo_pago"] = None
# (2) texto inconsistente (mayúsculas / espacios)
for i in rng.choice(N_CLIENTES, 400, replace=False):
    if clientes.loc[i, "ciudad"] is not None:
        c = str(clientes.loc[i, "ciudad"])
        clientes.loc[i, "ciudad"] = c.upper() if rng.random() < 0.5 else " " + c + " "
# (3) filas duplicadas exactas
clientes = pd.concat([clientes, clientes.sample(90, random_state=1)], ignore_index=True)
pedidos = pd.concat([pedidos, pedidos.sample(230, random_state=2)], ignore_index=True)

# ------------------------------------------------------------------ GUARDAR
total = 0
for nombre, df in [("clientes", clientes), ("productos", productos), ("pedidos", pedidos),
                   ("pagos", pagos), ("devoluciones", devoluciones)]:
    df.to_csv(OUT / f"{nombre}.csv", index=False, encoding="utf-8")
    total += len(df)
    print(f"{nombre:13s} {len(df):>7,d} filas")
print(f"{'TOTAL':13s} {total:>7,d} filas")
