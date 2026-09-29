"""
construir_excel.py | Generador de reportes dinámicos
=====================================================================================
Compila los resultados de salida (`base_pedidos.csv`) en un workbook analítico.
Inyecta fórmulas de Excel nativas (SUMIFS, COUNTIFS, referenciación relativa) en 
lugar de valores estáticos, permitiendo que el reporte se recalcule automáticamente 
ante mutaciones en los datos base.
"""
from pathlib import Path
import pandas as pd
from openpyxl import Workbook
from openpyxl.chart import BarChart, LineChart, Reference
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

RAIZ = Path(__file__).resolve().parent.parent
base = pd.read_csv(RAIZ / "excel" / "base_pedidos.csv", parse_dates=["fecha_pedido"])
res = {q: pd.read_csv(RAIZ / "resultados" / f"{q}.csv") for q in ["Q02", "Q07", "Q08", "Q09"]}
N = len(base)
ULT = N + 1 # Límite del rango dinámico para evaluación de fórmulas

# Configuraciones de estilos UI/UX del reporte
FUENTE = "Arial"
F_NORMAL, F_BOLD = Font(name=FUENTE, size=10), Font(name=FUENTE, size=10, bold=True)
F_HEAD = Font(name=FUENTE, size=10, bold=True, color="FFFFFF")
F_INPUT = Font(name=FUENTE, size=10, color="0000FF") # Indicador visual de input/SQL statics
F_TITULO = Font(name=FUENTE, size=14, bold=True, color="1F3864")
FILL_HEAD = PatternFill("solid", fgColor="1F3864")
FILL_TOTAL = PatternFill("solid", fgColor="D9E1F2")
BORDE = Border(bottom=Side(style="thin", color="BFBFBF"))
COP, PCT, ENT = '#,##0', '0.0%', '#,##0'

wb = Workbook()

def encabezado(ws, fila, textos, ancho=None):
    # Utilidad para formateo iterativo de headers
    for j, t in enumerate(textos, 1):
        c = ws.cell(row=fila, column=j, value=t)
        c.font, c.fill = F_HEAD, FILL_HEAD
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    ws.row_dimensions[fila].height = 32
    if ancho:
        for j, w in enumerate(ancho, 1):
            ws.column_dimensions[get_column_letter(j)].width = w

# --- [Omisión de lógica visual estándar (LEEME, iteraciones de formato) por brevedad, no requiere cambios conceptuales] ---
# Resto del código se mantiene íntegro, enfocado en inyección de fórmulas como:
# wr.cell(row=i, column=3, value=f"=SUMIFS({rng('I')},{rng('E')},A{i})")