# Prueba Técnica — El choque petrolero de 2022 y los subsidios a combustibles fósiles

Carpeta **autocontenida y portable** con todo lo necesario para compilar la presentación
de la prueba técnica en cualquier repositorio. Verificada: compila en limpio a 32 páginas
con XeLaTeX.

**Autor:** Daniel Mendivelso · 2026

---

## Contenido

```
Prueba_Tecnica_Completa/
├── Prueba_Tecnica_Resultados.tex          ← fuente Beamer (autocontenida, sin \input externos)
├── Prueba_Tecnica_Resultados.pdf          ← PDF compilado (versión final, 32 pp.)
├── figures/
│   ├── cropped/   fig1–fig5  (8-bit RGB, sin banda de notas — usadas en \fig)
│   ├── compiled/  fig1–fig5  (8-bit RGB completas con nota quemada — usadas en \figfull)
│   └── fig1–fig5.png         (copias en la raíz)
└── tables/
    ├── tab{1,2,4,5,6}.pdf    ← tablas que incrusta el .tex (\tab)
    └── tab{1,2,4,5,6}.xlsx   ← fuente editable de cada tabla
```

## Cómo compilar (en este o cualquier otro repo)

```bash
cd Prueba_Tecnica_Completa
xelatex -interaction=nonstopmode Prueba_Tecnica_Resultados.tex
xelatex -interaction=nonstopmode Prueba_Tecnica_Resultados.tex   # 2ª pasada: TOC / outlines
```

Dos pasadas bastan (no usa bibliografía ni `\cite`). Sale `Prueba_Tecnica_Resultados.pdf`.

## Requisitos

- **XeLaTeX** (NO pdflatex: el preámbulo usa `fontspec`; con `inputenc/fontenc` el `¿` se
  rompería). En macOS/Linux viene con TeX Live / MacTeX.
- Paquetes Beamer estándar (beamer, fontspec, babel-spanish, amsmath, graphicx, booktabs,
  xcolor, microtype). Todos en una instalación TeX Live completa.

## Notas de portabilidad

- **Rutas locales:** el `.tex` referencia `figures/...` y `tables/...` de forma relativa a
  sí mismo (`\fig`, `\figfull`, `\tab`). Mientras `.tex`, `figures/` y `tables/` viajen
  juntos, compila en cualquier lado. (En el proyecto original las rutas eran
  `../Prueba_Tecnica/...`; aquí se ajustaron para que la carpeta sea autocontenida.)
- **Figuras en 8-bit RGB:** las originales de 16-bit no renderizan bajo XeLaTeX/xdvipdfmx
  (salen en blanco). Estas ya están convertidas a 8-bit.
- **Sin auxiliares:** la carpeta trae solo fuentes + PDF; los `.aux/.log/.nav/...` se
  regeneran al compilar.

---

*Tema: diferencias-en-diferencias (TWFE) sobre el choque del Brent 2022 × condición de
exportador neto, panel de 34 países de ALC, 2015–2023. Datos: IMF Fossil Fuel Subsidies
Database, IMF WEO, EIA Brent.*

