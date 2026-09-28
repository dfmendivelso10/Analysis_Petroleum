---
paths:
  - "code/**/*.R"
  - "code/**/*.py"
  - "code/**/*.do"
---

# Inferencia y Robustez (testeo múltiple + grados de libertad del investigador)

Estándares para las decisiones de inferencia que deciden si un resultado sobrevive a un
referí exigente. Aplica a los scripts de análisis empírico.

## Testeo de hipótesis múltiples

Cuando se testean **muchas hipótesis** (varios resultados, subgrupos, brazos de tratamiento
o especificaciones), los p-values sin ajustar exageran la significancia. Decidir la
corrección **según lo que se controla, y registrar la familia de antemano**:

- **Family-wise error rate (FWER)** — controla la probabilidad de *cualquier* rechazo falso.
  Usar cuando un solo falso positivo es costoso (un claim de titular).
  - **Romano–Wolf** stepdown (resampling, explota la dependencia entre ecuaciones; mucho
    menos conservador que Bonferroni; R `wildrwolf`, Stata `rwolf`) es el default moderno
    para una familia pequeña.
  - Holm–Bonferroni como fallback libre de distribución; Bonferroni plano solo para una
    familia diminuta.
- **False discovery rate (FDR)** — controla la *proporción esperada* de rechazos falsos
  entre los rechazos. Usar para **muchas** hipótesis donde algunos falsos positivos son
  aceptables (screening, barridos de heterogeneidad).
  - Benjamini–Hochberg; los q-values afilados de **Anderson (2008)** son el estándar en
    microeconomía aplicada.
- **Registrar la familia y la corrección de antemano** (la unidad de corrección es un grado
  de libertad del investigador). Reportar p-values con y sin ajuste; nunca elegir la familia
  que hace sobrevivir el resultado.

## Grados de libertad del investigador / robustez de especificación

Una sola especificación es un punto en un jardín de senderos que se bifurcan. Hacer la
robustez explícita:

- **Mostrar que la especificación no está escogida a dedo** — una curva de especificación
  (barrer los conjuntos de controles defendibles, restricciones de muestra, formas
  funcionales; reportar la distribución de estimadores, no uno).
- **Leave-one-out / observaciones influyentes** — confirmar que el resultado no lo arrastran
  unas pocas unidades o un solo cluster. *(En este proyecto: el leave-one-out de los 7
  exportadores, ya implementado en `08_robustness.R`.)*
- **Robustez de la inferencia** — niveles alternativos de clustering, wild-cluster bootstrap
  con pocos clusters, inferencia por aleatorización cuando el diseño lo permite.
- Para **DiD específicamente**, la batería de robustez es la suite de diagnóstico +
  sensibilidad de `econometrics-conventions.md` (§DiD): placebo en el componente estructural,
  pre-tendencias como pre-test, forma funcional (niveles vs logs), leave-one-out — no un
  pre-test TWFE.

## Reporte

- Declarar la **familia** y el **método de corrección** por adelantado; reportar p-values/
  q-values con y sin ajuste.
- Un chequeo de robustez que solo confirma el titular es teatro: reportar la especificación
  donde el resultado **se debilita**, e interpretarla.

## Reglas relacionadas
- `econometrics-conventions.md` (§DiD, §Causalidad e Identificación).
- Para DiD escalonado: Callaway & Sant'Anna (2021), paquete `did`, hub
  <https://psantanna.com/did-resources/>.
