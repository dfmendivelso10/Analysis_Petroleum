---
paths:
  - "*.tex"
---

# Convenciones del deck Beamer (presentación de resultados)

Convenciones del deck `oil_shock_subsidies_LAC.tex`. Derivadas del propio archivo; mantener
cualquier edición consistente con ellas. El preámbulo va **inline** (no en `Preambles/`).

## Compilación
- **XeLaTeX siempre** (`fontspec` + `texgyreheros`); nunca pdflatex. Con inputenc/fontenc el
  `¿` se rompe. Dos pasadas para `\insertframenumber`. Ver skill `compile-latex`.

## Paleta (gris carbón minimal, sin marca institucional)
- `Carbon` (#333333) — acento principal y texto.
- `GrisMedio` (#6E6E6E) — secundario, notas, footline.
- `AcentoRojo` (#B00020) — **una sola cifra clave por slide** vía `\key{...}`.
- `GrisClaro` (#EDEDED) — fondos sutiles de bloques.

## Énfasis y cifras
- `\key{...}` — rojo negrita. **Una por slide como máximo** (la cifra clave). No abusar.
- `\alert{...}` — carbón negrita (NO rojo). Para resaltar conceptos, no cifras.
- El rojo se reserva para `\key`; no usarlo en otros lugares.

## Figuras y tablas
- `\captitulo{Figura N}{Título breve}` — caption tipo paper ENCIMA del `\includegraphics`. La
  numeración sigue el nombre de archivo (fig1..5, tab1,2,4,5,6), no el orden de aparición.
- `\fig{...}` → `figures/cropped/` (8-bit, nota recortada). `\figfull{...}` →
  `figures/compiled/` (nota quemada, para respaldo). `\tab{...}` → `tables/`.
- Las figuras de 16-bit NO renderizan bajo XeLaTeX: usar siempre las 8-bit.
- `\fignota{...}` (dentro de columna) / `\fignotaC{...}` (dentro de `center`, full-width):
  nota al pie en gris, pequeña, alineada a la izquierda. Empezar con *Cómo leerla:* y terminar
  con *Fuente:*.

## Estructura
- Bloques temáticos separados por `\divisor{n}{título}{subtítulo}` (frame `[plain]`).
- Frametitle: título en carbón + regla roja fina debajo.
- Footline minimal en gris: solo número de slide (título y autor eliminados).
- Notas del expositor en `\note{...}` bajo cada frame. El registro coloquial vive SOLO ahí,
  nunca en el texto visible del slide.

## Redacción
- Español académico, sin primera persona, sin contracciones (ver `resultados-formato.md`).
- Sigla de la región: **LAC** de forma uniforme (no ALC).
- Notación estadística: `p = .XXX` / `p < .001` (nunca `p = 0.000`), cero antes del decimal,
  `IC 95% [.., ..]`. Una cifra reportada debe ser idéntica en todos los slides.

## Reglas relacionadas
- `proofreading-protocol.md` · `resultados-formato.md` (global) · skills `compile-latex`, `proofread`.
