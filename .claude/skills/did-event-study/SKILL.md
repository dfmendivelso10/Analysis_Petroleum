---
name: did-event-study
description: Corre un análisis de diferencias en diferencias escalonado / event-study al estándar de práctica de Sant'Anna — maneja los paquetes canónicos (R `did`/`DRDID`/`didFF`/`contdid`), impone el default doblemente robusto, una suite obligatoria de diagnóstico + sensibilidad, inferencia con bandas uniformes, disciplina de replicar-y-verificar-contra-la-fuente, y termina en un veredicto graduado de credibilidad. Usar cuando se pida "correr un DiD", "event study", "adopción escalonada", "Callaway Sant'Anna", "att_gt", o cuando haya panel con una variable de timing de tratamiento. NUNCA reimplementa un estimador.
argument-hint: "[ruta datos] [--outcome --unit --time --gvar] [--control nevertreated|notyettreated] [--continuous]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Bash"]
effort: high
---

# /did-event-study — DiD / event study, estándar de práctica de Sant'Anna

> **CONTEXTO DE ESTE PROYECTO (leer primero).** El diseño de este proyecto es un
> **2×2 canónico** (un único período de tratamiento, 2022; exportadores vs. importadores),
> estimado con **TWFE en `fixest`** (`06_model.R`). Para ese caso, esta skill misma indica
> que basta un one-liner (`DRDID::drdid()` o `feols(y ~ d*post)`), no el pipeline escalonado
> completo. Esta skill queda como **referencia / biblioteca**: aplica plenamente solo si el
> diseño crece a **adopción escalonada** (varios años de tratamiento, timing heterogéneo).
> Mientras el diseño sea 2×2, las reglas vigentes son `econometrics-conventions.md` (§DiD).

Es un **orquestador delgado sobre los paquetes canónicos** — nunca reimplementa un estimador.
Recorre el workflow de *Difference-in-Differences with Multiple Time Periods* (Callaway &
Sant'Anna 2021), *Doubly Robust DiD* (Sant'Anna & Zhao 2020) y la síntesis *"What's Trending
in DiD?"* (Roth, Sant'Anna, Bilinski & Poe 2023), con disciplina de **replicar-y-verificar-
contra-la-fuente**.

> **Actor → Crítico.** La skill es el *Actor*: corre los paquetes y los diagnósticos. Luego se
> pone el sombrero de *Crítico* en la **Fase 8 — un veredicto graduado de credibilidad**, nunca
> un "pasa/no pasa" binario. Una discrepancia con un pre-test es *evidencia sobre credibilidad*,
> no un gate.

> **Leer primero:** `.claude/rules/econometrics-conventions.md` (§DiD) en este proyecto. Para
> los estándares HARD completos del diseño escalonado, ver los recursos canónicos en §Recursos
> (Callaway & Sant'Anna 2021; hub did-resources).

## Cuándo usarla

- Adopción escalonada o 2×T con panel o cortes transversales repetidos; tratamiento binario
  absorbente, o una **dosis continua**.
- Cada vez que alguien recurra a un event study TWFE bajo timing escalonado — enrutar aquí.

## Cuándo NO usarla

- Un 2×2 simple con un pre / un post y sin covariables es un one-liner — usar `DRDID::drdid()`
  o `feols(y ~ d*post)`, sin el pipeline completo. **(Este es el caso del proyecto.)**
- Tratamientos reversibles / con switching: estos paquetes asumen tratamiento absorbente.

## Workflow (orden fijo)

### Fase 0 — Setup de reproducibilidad (gate antes de estimar)
- `set.seed(...)` **REQUERIDO** — toda la inferencia es por bootstrap.
- Fijar software (`renv::restore(prompt = FALSE)`), rutas con `here::here()`, un master script
  que corre el pipeline de punta a punta.

### Fase 1 — Diseño / estimando
- Reshape a **LONG**: una fila por unidad-período.
- Columnas: `yname` (resultado), `tname` (tiempo), `idname` (id **invariante, numérico**),
  `gname` (grupo = **primer período tratado**; never-treated codificado **EXACTAMENTE `0`**).
- Tabular el roll-out (share por cohorte): **2×2 → 2×T → escalonado G×T**.
- Elegir el estimando de antemano. El resumen recomendado es el **Overall ATT de
  `aggte(type = "group")`**; dinámica vía `type = "dynamic"`.

### Fase 2 — Selección de estimador
Seguir la lógica en §Selección de estimador. Output: estimador, `est_method`/`estMethod`,
`control_group`, `panel` vs RC, covariables sí/no.

### Fase 3 — Estimación (manejar el paquete; no reimplementar)
- **2×2 (un pre / un post):**
  ```r
  DRDID::drdid(yname, tname, idname, dname, xformla = ~covs, data, panel = TRUE, estMethod = "imp")
  ```
  - Pre-flight: `panel = TRUE` requiere `idname` único por período y panel balanceado. Si está
    desbalanceado, reproducir el 2×2 de libro con `panel = FALSE` e id único por fila, o
    balancear (distinto estimando — documentarlo).
  - DR sin covariables se reduce al 2×2 simple.
- **Escalonado / multi-período:**
  ```r
  out <- did::att_gt(yname, tname, idname, gname, xformla = NULL, data = mydata,
    panel = TRUE, control_group = "notyettreated", est_method = "dr",
    base_period = "universal", bstrap = TRUE, cband = TRUE, biters = 1000,
    clustervars = NULL, weightsname = NULL)
  ```
  `att_gt` arma cada `ATT(g,t)` desde un `drdid` 2×2 limpio — por eso evita las comparaciones
  prohibidas (already-treated como control) que sesgan TWFE.
- **Event study TWFE — benchmark/sanity check, nunca el titular bajo heterogeneidad:**
  `fixest::feols(y ~ i(time_to_treat, treat, ref = -1) | id + year, cluster = ~id)`. Confirmar
  que `att_gt(est_method = "reg")` lo replica en casos simples, para que cualquier divergencia
  sea atribuible al *diseño* (pesos negativos), no a un bug.
- **Dosis continua [ALPHA]:** `contdid::cont_did(...)` con `dname` invariante real (no 0).

### Fase 4 — Diagnósticos obligatorios (ninguno saltable)
1. **Pre-tendencias (un PRE-TEST, no una prueba):** leer `ATT(g,t)` para `t<g` y el Wald
   p-value. Pasar es *evidencia sobre credibilidad*, **no prueba**. **NO** pre-testear con un
   event study TWFE bajo timing selectivo.
2. **Event study:** `aggte(out, type = "dynamic")` → `ggdid()`.
3. **Pesos negativos / comparación prohibida:** satisfecho *por diseño* vía `att_gt`.
4. **Overlap DR:** inspeccionar el solapamiento del propensity score.

### Fase 5 — Sensibilidad (ROBUSTEZ, nunca un pre-test pasa/falla)
- **HonestDiD (Rambachan & Roth)** — liderar con el breakdown de magnitudes relativas `Mbar`.
  Requiere `base_period = "universal"`. `honest_did()` es un método S3 interno NO exportado:
  usar `HonestDiD:::honest_did(es, …)`.
- **didFF (Roth & Sant'Anna 2023):** sensibilidad a la forma funcional. Paralelismo no es
  invariante a niveles vs logs.

### Fase 6 — Inferencia
- Multiplier bootstrap, `bstrap = TRUE`, `cband = TRUE` → bandas **uniformes/simultáneas**.
  `biters = 25000` para publicación. **Nunca** publicar bandas solo puntuales como titular.
- `clustervars` ≤ 2 (uno = `idname`). Pocos clusters tratados requieren cuidado (wild-cluster
  bootstrap vía `fwildclusterboot`/`boottest`).

### Fase 7 — Agregación y reporte
- `aggte(out, type = "dynamic"/"group"/"calendar")`. **Siempre pasar `type` explícito; evitar
  `type = "simple"`** (sobrepondera los tratados temprano).
- Mapear cada coeficiente/figura a su script + línea generadora.

### Fase 8 — Veredicto de credibilidad (graduado, honesto — el Crítico)
Sintetizar en un veredicto **graduado** (Fuerte / Moderado / Débil / No-creíble) con razones:
Diseño · Pre-tendencias · Sensibilidad · Overlap · Inferencia.

## Selección de estimador

```
¿Dosis continua?            → contdid::cont_did(...)            [ALPHA]
¿2 grupos × 2 períodos?     → DRDID::drdid(..., estMethod="imp")   ← caso del proyecto
¿Muchos períodos/cohortes?  → did::att_gt(...)
¿Cortes repetidos?          → att_gt(panel=FALSE) / drdid(panel=FALSE)
```
- **Doblemente robusto es el default** (`est_method="dr"`/`estMethod="imp"`). `est_method`
  importa solo con covariables.
- **Control:** `notyettreated` default para G×T escalonado; `nevertreated` para 2×T limpio.

## Estándar de verificación / replicación
- **R es el benchmark.** `did`/`DRDID`/`didFF`/`contdid` son las implementaciones canónicas;
  Stata (`csdid`/`drdid` vía `asinr`) y ports de Python deben **reproducir R** a `abs_diff <
  1e-6` (punto + SE analítico).
- Replicar un paper publicado es un check distinto: traducir desde, y verificar contra, el
  código original del autor (a menudo Stata); ese código es la verdad para sus números.
- "Replicación primero — igualar los números originales antes de extender."

## Recursos (canónicos, públicos)
- **Hub did-resources:** <https://psantanna.com/did-resources/>
- **Paquetes:** `did` <https://bcallaway11.github.io/did/> · `DRDID` <https://psantanna.com/DRDID/> · `didFF` · `contdid` · `staggered`.
- **Papers:** Callaway & Sant'Anna (2021) · Sant'Anna & Zhao (2020) · Roth & Sant'Anna (2023, *Econometrica*) · Rambachan & Roth (2023, HonestDiD).

## Qué NO hace esta skill
- **Reimplementar un estimador** — maneja los paquetes; si un número es implausible, depurar
  el wrapper / muestra / pesos / clustering / construcción de datos antes de interpretar.
- **Manejar tratamientos reversibles**, ni usar TWFE como titular bajo timing escalonado.
- **Reemplazar tu juicio** — el veredicto de credibilidad es asesor; el auditor eres tú.

## Cross-references
- `.claude/rules/econometrics-conventions.md` (§DiD) — reglas vigentes para el 2×2 del proyecto.
- `.claude/rules/inference-robustness.md` — testeo múltiple, leave-one-out, robustez de spec.
- Estándares HARD completos del diseño escalonado: §Recursos (Callaway & Sant'Anna 2021).
