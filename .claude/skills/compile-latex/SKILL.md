---
name: compile-latex
description: Compila el deck Beamer del proyecto con XeLaTeX y reporta warnings (overfull hbox, referencias). Usar para compilar la presentación de resultados y verificar que renderiza limpio.
disable-model-invocation: true
argument-hint: "[archivo sin .tex, o vacío = oil_shock_subsidies_LAC]"
---

# Compilar el deck Beamer (XeLaTeX)

Compila la presentación con XeLaTeX. En este proyecto el preámbulo está **inline** en el
`.tex` y las referencias se escriben a mano (no hay `.bib` ni bibtex), así que no se necesitan
`TEXINPUTS`/`BIBINPUTS` ni pasadas de bibtex.

## Pasos

1. **Compilar** (dos pasadas para resolver `\insertframenumber` y cross-refs). Desde la raíz:

   ```bash
   FILE="${ARGUMENTS:-oil_shock_subsidies_LAC}"
   xelatex -interaction=nonstopmode "$FILE.tex"
   xelatex -interaction=nonstopmode "$FILE.tex"
   ```

   > **Siempre XeLaTeX**, nunca pdflatex: el deck usa `fontspec`/`texgyreheros` y depende de
   > XeLaTeX para los signos `¿` `¡` y las tildes (con inputenc el `¿` se rompe).

2. **Revisar warnings** en el log:
   - `Overfull \hbox` (texto que se desborda del frame).
   - `Reference ... undefined` / `Label(s) may have changed` (resuelto por la 2ª pasada).
   - Imágenes faltantes (`File ... not found`) — revisar rutas `\fig`/`\tab`/`\figfull`.

3. **Abrir el PDF** para verificación visual:
   ```bash
   open "$FILE.pdf"
   ```

4. **Reportar:** éxito/fallo, nº de overfull hbox, referencias sin resolver, nº de páginas.

## Notas de este proyecto
- Las figuras de 16-bit no renderizan bajo XeLaTeX/xdvipdfmx: usar las versiones 8-bit RGB de
  `figures/cropped/` (con la nota recortada) o `figures/compiled/` (nota quemada).
- Para ver las notas del expositor, descomentar `\setbeameroption{show notes}` en el preámbulo.
