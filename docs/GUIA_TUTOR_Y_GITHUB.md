# Guía de tutor y GitHub: Proyecto 1 (SQL + Excel)

Esta guía es para que puedas **explicar el proyecto con tus propias palabras**. Un proyecto que no puedes explicar en una entrevista perjudica más de lo que ayuda.

---

## PARTE A. Qué usé, cómo y por qué

### 1. Datos sintéticos (`generar_datos.py`)
- **Qué:** un script en Python que crea 5 tablas con `numpy` y `pandas`, con semilla fija (`SEED = 42`).
- **Por qué:** no tenía acceso a internet para descargar un dataset público, y así cualquiera reproduce lo mismo.
- **Qué debes saber decir:** "Los datos son sintéticos; introduje duplicados y nulos a propósito para practicar la limpieza".
- **Para hacerlo más real:** reemplázalo por el dataset público *Brazilian E-Commerce (Olist)* de Kaggle (~100.000 pedidos). Si lo haces, **tus números cambiarán** y deberás actualizar el README y la hoja de vida.

### 2. Diseño en dos capas: staging y tablas finales (`01_schema.sql`)
- **Staging:** tablas con todo en texto y sin llaves. Copia fiel del CSV. La carga nunca falla por un dato sucio.
- **Finales:** tablas tipadas con `PRIMARY KEY`, `FOREIGN KEY` e índices.
- **Por qué importa:** nunca se limpia sobre el original. Si te equivocas, repites el proceso.
- **Conceptos:** llave primaria (identifica una fila), llave foránea (garantiza que un pedido apunte a un cliente que existe), índice (acelera búsquedas y `JOIN`).

### 3. Limpieza (`03_limpieza.sql`)
| Problema | Solución | Función SQL |
|---|---|---|
| Duplicados exactos | Numerar repeticiones y quedarse con la 1ª | `ROW_NUMBER() OVER (PARTITION BY id ...)` |
| Nulos en ciudad | Reemplazar por `SIN DATO` | `COALESCE`, `NULLIF` |
| Texto inconsistente | Quitar espacios y unificar mayúsculas | `TRIM`, `UPPER` |
| Descuento nulo | Imputar 0 (supuesto documentado) | `COALESCE` |

- **Detalle que suma puntos:** el control 7.3 encontró 331 pedidos donde el descuento real no coincidía con el imputado. Por eso el ingreso se toma de la tabla `pagos` (fuente de verdad). **Esta es una historia excelente para entrevista.**

### 4. Vistas (`v_ventas`)
Una vista es una consulta guardada con nombre. Aquí concentra las definiciones de negocio (ingreso, reembolso, utilidad) para que las 15 consultas usen **la misma definición**. Si el negocio cambia la fórmula, la cambias en un solo lugar.

### 5. Las 15 consultas: técnica por técnica
| Consulta | Técnica | Idea clave |
|---|---|---|
| Q01, Q02 | `UNION ALL`, agregaciones | Empezar verificando que los datos estén completos |
| Q03 | CTE + `SUM() OVER (ORDER BY)` | Suma acumulada mes a mes |
| Q04 | `LAG()` | Traer el valor de la fila anterior para calcular variación |
| Q05, Q06 | `RANK()`, `PARTITION BY` | Ranking global y ranking dentro de cada grupo |
| Q07, Q14 | `SUM(SUM(x)) OVER ()` | Porcentaje sobre el total sin subconsulta |
| Q08 | CTE + acumulado + subconsultas | **Pareto** |
| Q09 | `GROUP BY` + `HAVING` | `WHERE` filtra filas, `HAVING` filtra grupos |
| Q10 | `ROW_NUMBER()` por grupo | El "top 1" de cada categoría |
| Q11, Q13 | Subconsulta escalar, `CASE` | Segmentar clientes |
| Q12 | `NTILE(4)` | Cuartiles de clientes |
| Q15 | Subconsulta correlacionada | Comparar cada fila contra su propio grupo |

### 6. Análisis de Pareto
Regla 80/20: pocos productos generan la mayoría de los ingresos. Ordenas de mayor a menor, acumulas el porcentaje y ves cuántos productos hacen falta para llegar al 70 %. **Resultado:** 85 de 500 (17 %).

### 7. Excel (`analisis_ventas.xlsx`)
- Hoja `Base_Pedidos` con los datos limpios; resúmenes con `SUMIFS` y `COUNTIFS`; gráficos nativos; hoja `Verificacion_SQL` (7 de 7 comprobaciones OK).
- **La tabla dinámica NO está creada a propósito:** las instrucciones están en la hoja `LEEME`. Créala tú; es un ejercicio y una pregunta típica de entrevista.

### 8. Verificación (`verificar_con_sqlite.py`)
Ejecuté el SQL en SQLite y recalculé los KPIs con pandas. Coincidieron. **Limitación honesta:** los scripts están escritos para MySQL 8 y no pude ejecutarlos en un servidor MySQL real. Ejecútalos en MySQL Workbench; si algo falla, cópiame el mensaje de error.

---

## PARTE B. Cómo aprender esto (ruta de 2 semanas)

**Días 1-2: Fundamentos.** Instala MySQL 8 y Workbench. Ejecuta los scripts 01 y 02 y responde: ¿qué diferencia hay entre una tabla staging y una final?

**Días 3-4: Limpieza.** Lee `03_limpieza.sql` línea por línea. Ejercicio: quita `WHERE rn = 1` y mira cuántas filas entran. Rompe cosas para entender.

**Días 5-8: Consultas.** Cada día, 4 consultas. Regla: **primero lee la pregunta, intenta escribirla tú, luego compara.** Practica también en SQLBolt, Mode SQL Tutorial o HackerRank (SQL).

**Días 9-10: Excel.** Crea la tabla dinámica y compárala con `Resumen_Categorias`.

**Días 11-12: Modifícalo.** Añade una consulta nueva tuya (por ejemplo, ingresos por ciudad). Un proyecto que ya modificaste te pertenece más.

**Días 13-14: Ensaya.** Explica el proyecto en voz alta en 2 minutos, sin leer.

---

## PARTE C. Preguntas de entrevista sobre este proyecto

1. **¿Diferencia entre `WHERE` y `HAVING`?** `WHERE` filtra filas antes de agrupar; `HAVING` filtra grupos después. En Q09 usé `HAVING` para excluir categorías con pocas ventas.
2. **¿`INNER JOIN` vs `LEFT JOIN`?** `INNER` devuelve solo coincidencias; `LEFT` conserva todas las filas de la izquierda. En `v_ventas` usé `LEFT JOIN` con devoluciones porque no todos los pedidos se devuelven.
3. **¿Qué es una CTE y para qué la usaste?** Una consulta temporal con nombre (`WITH ...`) que hace el código legible y reutilizable. La usé en Pareto y en cuartiles.
4. **¿`RANK` vs `ROW_NUMBER`?** `ROW_NUMBER` da un número único aunque haya empates; `RANK` repite el número en empates y salta el siguiente.
5. **¿Cómo trataste los duplicados?** `ROW_NUMBER() OVER (PARTITION BY id)` y me quedé con la fila 1. Antes/después: 8.090 -> 8.000 y 45.230 -> 45.000.
6. **¿Qué es el Pareto y qué encontraste?** 17 % de los productos concentra el 70 % de los ingresos.
7. **¿Cómo sabes que tus resultados son correctos?** Los recalculé con pandas y Excel; hay una hoja de verificación.
8. **¿Qué limitaciones tiene tu análisis?** Datos sintéticos, un producto por pedido, sin costos de envío.
9. **¿Qué harías distinto?** Usar datos reales y agregar una tabla de líneas de pedido.
10. **¿Por qué usaste staging?** Para no perder el dato original y no fallar la carga.

### Cómo contarlo (formato STAR, ~1 minuto)
> "Quería practicar el ciclo completo de análisis con SQL. Construí una base de una tienda en línea con unos 100.000 registros sintéticos, con duplicados y nulos a propósito. Diseñé el esquema, limpié los datos y escribí 15 consultas. Encontré que el 17 % de los productos genera el 70 % de los ingresos y que Ropa y Electrónica tienen tasas de devolución de 3 a 7 veces las de las demás categorías. Verifiqué los resultados con pandas y Excel."

---

## PARTE D. Subir este proyecto a GitHub

### Una sola vez (configuración)
1. Crea tu cuenta en <https://github.com>.
2. Instala Git desde <https://git-scm.com/downloads> y verifica en una terminal: `git --version`.
3. Configura tu identidad (usa el mismo correo de GitHub):
   ```bash
   git config --global user.name "Jairo Esteban Guzmán"
   git config --global user.email "tu_correo@ejemplo.com"
   ```

### Crear el repositorio en GitHub
1. Clic en **+ > New repository**.
2. Nombre sugerido: `portafolio-analisis-datos` (un solo repositorio con las 3 carpetas) o `ventas-tienda-online`.
3. Marca **Public**. **No** marques "Add a README" (ya tienes el tuyo).
4. Clic en **Create repository**.

### Subirlo desde la terminal
Abre la terminal **dentro de la carpeta** que quieres subir:
```bash
git init
git add .
git commit -m "Proyecto 1: análisis de ventas y rentabilidad (SQL + Excel)"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/NOMBRE_DEL_REPO.git
git push -u origin main
```
Al hacer `push`, GitHub pide autenticación. **No uses tu contraseña**: usa un *Personal Access Token* (Settings > Developer settings > Personal access tokens) o instala GitHub CLI (`gh auth login`).

### Alternativa sin terminal
En la página del repositorio: **Add file > Upload files**, arrastra el contenido y haz *Commit changes*. Límite: 100 archivos por carga, y carpetas dentro de carpetas se suben arrastrándolas.

### Errores comunes
| Mensaje | Causa y solución |
|---|---|
| `fatal: not a git repository` | No estás en la carpeta correcta, o falta `git init` |
| `src refspec main does not match any` | No hiciste `commit` antes del `push` |
| `remote origin already exists` | Usa `git remote set-url origin URL` |
| `failed to push ... non-fast-forward` | Marcaste "Add README" al crear el repo. Usa `git pull origin main --allow-unrelated-histories` y luego `git push` |
| Archivo mayor a 100 MB | GitHub lo rechaza. Aquí el mayor pesa ~3,6 MB, no hay problema |

### Después de subirlo
- Revisa que el README se vea bien en la página del repositorio.
- Añade en el repo un *About* con descripción y temas (`sql`, `mysql`, `excel`, `data-analysis`).
- Copia la URL del repositorio en tu LinkedIn y en tu hoja de vida.
- Cada cambio posterior: `git add .` -> `git commit -m "mensaje"` -> `git push`.

---

## PARTE E. Ajustes recomendados a tu hoja de vida para este proyecto

1. **Sé transparente con los datos.** Tu CV dice "dataset público". Si usas datos sintéticos, escribe "dataset sintético de comercio electrónico (~100.000 registros)". Si usas Olist, sí es público, pero tus cifras cambiarán.
2. **Usa tus números reales.** Con estos datos: "17 % de los productos concentró el 70 % de los ingresos", y Ropa (15,3 %) y Electrónica (14,6 %) tienen las mayores tasas de devolución. Tu CV dice "20 % / 70 %": ajústalo a lo que realmente salga en **tu** ejecución.
3. **Enlace al repositorio** en cada proyecto.
4. La sección "Experiencia profesional" contiene proyectos: renómbrala **"Proyectos de portafolio"**. Presentar proyectos como experiencia laboral puede generar dudas.
5. El perfil tiene una frase cortada ("Tengo conocimientos en SQL, Tambien cuento con..."). Corrígela.
