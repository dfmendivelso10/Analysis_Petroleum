---
name: proofread
description: Corre el protocolo de revisión de redacción sobre el .tex de la presentación. Revisa gramática, typos, overflow, consistencia terminológica y numérica, huella de IA y notación estadística. Produce un reporte SIN editar archivos. Usar cuando el usuario pida revisar la redacción de los slides.
disable-model-invocation: true
argument-hint: "[archivo .tex, o vacío = el deck principal]"
---

# Revisar redacción del deck

Corre el protocolo de proofreading sobre el `.tex` de la presentación. Produce un reporte de
todos los problemas SIN editar las fuentes. Sigue `proofreading-protocol.md`.

## Pasos

1. **Identificar el archivo:**
   - Si `$ARGUMENTS` es un `.tex`: revisar ese.
   - Si está vacío: el deck principal del proyecto (`oil_shock_subsidies_LAC.tex`).

2. **Lanzar el agente `proofreader`** sobre el archivo. Revisa:
   - **GRAMÁTICA/ORTOGRAFÍA:** concordancia, tildes, `¿`/`¡`, sin 1ª persona ni informalidad.
   - **TYPOS/ARTEFACTOS:** palabras duplicadas, comandos LaTeX rotos.
   - **OVERFLOW:** `Overfull \hbox`, contenido que excede el frame.
   - **CONSISTENCIA TERMINOLÓGICA:** sigla ALC uniforme, notación, términos.
   - **CONSISTENCIA NUMÉRICA:** la misma cifra idéntica en todos los slides/notas/tablas, y
     coincidente con `logs/` y `data/processed/`. Marcar `[VERIFICAR]` lo no verificable.
   - **HUELLA DE IA:** frases prohibidas (ver el rule global `resultados-formato.md`).
   - **COHERENCIA ECONOMÉTRICA:** que la afirmación verbal no exceda el dato; notación
     estadística del proyecto.

3. **Verificar cifras contra la fuente** cuando sea posible: leer `logs/log_06_model*.txt`,
   `logs/log_08_robustness*.txt` y `data/processed/panel_country_year.xlsx` para confirmar los
   números citados en los slides (no recalcular el modelo; solo cotejar).

4. **Guardar el reporte** en `quality_reports/[NOMBRE_SIN_EXT]_proofread.md`.

5. **IMPORTANTE: NO editar ninguna fuente.** Solo el reporte; las correcciones se aplican
   después con aprobación (fase 2 del protocolo).

6. **Presentar resumen:** total de problemas por categoría y los más críticos (en especial
   inconsistencias numéricas y huella de IA).
