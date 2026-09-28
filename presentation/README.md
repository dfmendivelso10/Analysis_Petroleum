# Presentation — The 2022 Oil Price Shock and Fossil Fuel Subsidies

Self-contained, portable folder with everything needed to compile the results
presentation (Beamer, **in Spanish**, 32 slides).

**Author:** Daniel Mendivelso · 2026

📄 **[Read the slides (PDF)](oil_shock_subsidies_LAC.pdf)**

---

## Contents

```
presentation/
├── oil_shock_subsidies_LAC.tex   ← Beamer source (self-contained, no external \input)
├── oil_shock_subsidies_LAC.pdf   ← compiled slides (32 pp.)
├── figures/
│   ├── cropped/   fig1–fig5  (8-bit RGB, notes band removed — used by \fig)
│   ├── compiled/  fig1–fig5  (8-bit RGB with the note embedded — used by \figfull)
│   └── fig1–fig5.png         (copies at the root)
└── tables/
    ├── tab{1,2,4,5,6}_*.pdf  ← tables embedded by the .tex (\tab)
    └── tab{1,2,4,5,6}_*.xlsx ← editable source of each table
```

## How to compile

```bash
cd presentation
xelatex -interaction=nonstopmode oil_shock_subsidies_LAC.tex
xelatex -interaction=nonstopmode oil_shock_subsidies_LAC.tex   # 2nd pass: TOC / outlines
```

Two passes are enough (no bibliography or `\cite`).

## Requirements

- **XeLaTeX** (not pdflatex: the preamble uses `fontspec`; with `inputenc/fontenc` the
  Spanish `¿` would break). Included in TeX Live / MacTeX.
- Standard Beamer packages (beamer, fontspec, babel-spanish, amsmath, graphicx, booktabs,
  xcolor, microtype), all part of a full TeX Live installation.

## Portability notes

- **Relative paths:** the `.tex` references `figures/...` and `tables/...` relative to
  itself (`\fig`, `\figfull`, `\tab`). As long as the `.tex`, `figures/` and `tables/`
  travel together, it compiles anywhere.
- **8-bit RGB figures:** the original 16-bit PNGs do not render under
  XeLaTeX/xdvipdfmx (they come out blank). These are already converted to 8-bit.
- **No auxiliary files:** only sources and the PDF are kept; `.aux/.log/.nav/...` are
  regenerated on compilation.

---

*Topic: difference-in-differences (TWFE) on the 2022 Brent shock × net oil exporter
status, panel of 34 Latin American and Caribbean countries, 2015–2023. Data: IMF Fossil
Fuel Subsidies Database, IMF WEO, EIA Brent.*
