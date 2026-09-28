---
paths:
  - "code/**/*.py"
  - "code/**/*.R"
  - "code/**/*.do"
  - "code/config.R"
---

# Code Standards — Econometría Macro

## 1. Configuración del Proyecto

Todo script DEBE comenzar importando/sourcing el archivo de configuración del proyecto:
- Python: `from config import *` o `import config`
- R: `source(here::here("config.R"))`
- Stata: `do "config.do"`

El config define: rutas, parámetros del modelo, semilla aleatoria, funciones auxiliares.

## 2. Estructura del Script

```python
###############################################################
# FISLAC — [Título descriptivo]
# Autor: [nombre]
# Fecha: YYYY-MM-DD
#
# Descripción:
#   [1-3 líneas de qué hace]
#
# Input:  [archivo(s) de entrada]
# Output: [archivo(s) de salida]
# N:      [observaciones esperadas]
###############################################################
```

Flujo lógico: setup → carga de datos → transformación → estimación → exportación.

## 3. Reproducibilidad

- Semilla aleatoria una sola vez en el config (no en scripts individuales)
- Todos los paths relativos a la raíz del proyecto (`pathlib.Path`, `here()`, etc.)
- Sin rutas absolutas hardcodeadas
- `mkdir -p` / `Path.mkdir(parents=True, exist_ok=True)` para carpetas de output
- Script debe correr limpio desde cero: `python script.py` o `Rscript script.R`

## 4. Datos Faltantes

- Documentar convención de missings del proyecto en CLAUDE.md
- Reportar N por variable antes de regresiones
- Nunca imputar valores sin justificación explícita
- Distinguir: missing estructural vs. no-respuesta vs. fuera de muestra

## 5. Estimación

- Usar especificaciones centralizadas del config
- Si el script se desvía del modelo estándar: documentar POR QUÉ en comentario
- Ver CLAUDE.md para convenciones de SE (robust, clustered, Newey-West, etc.)
- Para series de tiempo: especificar explícitamente el orden de rezagos y criterio de selección

## 6. Output

- Tablas: `outputs/tables/`
- Figuras: `outputs/figures/`
- Diagnósticos: `quality_reports/`
- Nunca sobreescribir datos en `data/`

## 7. Console Output

- Usar logging (Python) o `message()` (R) para hitos de progreso
- No usar `print()` para debugging — remover antes de commit

## 8. R — disciplina específica

Adaptado del estándar de R del toolkit. Las convenciones de figuras (paleta World Bank,
Times New Roman, dimensiones) viven en `code/config.R` y `docs/conventions.md`, no aquí;
esto cubre estilo y, sobre todo, **disciplina numérica**.

- `library()` (no `require()`) y `set.seed()` una sola vez, arriba (en `config.R`).
- `snake_case` verbo-sustantivo; documentar funciones (Roxygen); sin números mágicos.
- Retornos con nombre (listas o tibbles).
- Líneas ≤ 100 caracteres, **salvo fórmulas matemáticas** (funciones de influencia,
  operaciones matriciales, implementación de ecuaciones del paper) cuando partir la línea
  dañaría la legibilidad y un comentario explica la operación.

### Disciplina numérica (aplica a todo R)

- **Sin igualdad de flotantes.** Nunca `==` sobre doubles: usar `all.equal()` o
  `abs(a - b) < tol`.
- **Clamping de CDF** a un intervalo ABIERTO. Un 0 o 1 exacto en `qnorm()`/`pbinom()` da
  `±Inf`: `p <- pmin(1 - eps, pmax(eps, p))` con `eps <- 1e-12`.
- **Literales enteros para conteos:** `n <- 1000L`, `for (i in 1L:nL)` — evita promoción
  silenciosa.
- **Pre-asignar vectores** antes de un loop (`numeric(n)`, `vector("list", n)`); nunca
  crecer con `c()`.
- **Semilla de bootstrap determinista:** fijar antes del bootstrap; si está anidado,
  `seed_base + b` por réplica.
- **`na.rm` explícito** en `mean()`/`sd()`/`sum()` sobre datos con posibles NA; no
  depender del default.
- **Sin `T`/`F`** (son variables, no constantes): escribir `TRUE`/`FALSE`.

Checklist completo de revisión de R en `agents/r-reviewer.md` (categoría "Numerical
Discipline").

## 9. Checklist

```
[ ] Config importado/sourced al inicio
[ ] Datos cargados via función estándar del proyecto
[ ] N verificado contra CLAUDE.md
[ ] SE type correcto para el estimador
[ ] Output guardado en ruta correcta
[ ] Sin rutas absolutas
[ ] Sin print() de debugging
```
