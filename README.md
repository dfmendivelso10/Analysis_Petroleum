# The 2022 Oil Price Shock and Fossil Fuel Subsidies in Latin America

Personal applied economics project. It quantifies and characterizes the effect of the 2022
international oil price shock on fossil fuel subsidies in Latin America, and discusses its
fiscal implications to inform a policy recommendation.

## Research question

How did the 2022 oil price shock affect fossil fuel subsidies in Latin America, and what
does it imply for fiscal and subsidy policy?

## Data sources

- **IMF Fossil Fuel Subsidies Database**: explicit and implicit subsidies.
- **EIA**: Brent crude oil price.
- **IMF World Economic Outlook** (via IMF DataMapper): fiscal indicators (gross public debt,
  fiscal balance, general government revenue). The WEO is used instead of the World Bank
  because it covers all 34 countries with no missing values (World Bank data has 50–79 %
  missing values for the Caribbean).

Downloaded for reference but not merged into the panel: EMBIG country risk (BCRP) and
international reserves (World Bank). Details for each source, including URL and the reason
for inclusion or exclusion, are in `data/raw/FUENTES.md`.

## Structure

```
code/               config.R + model (06), fiscal analysis (07) and robustness (08)
code/limpieza/      download, processing, validation and data dictionary
code/descriptivas/  descriptive tables and figures (01–05)
data/raw/           Unmodified raw sources (IMF .xlsb, Brent, WEO fiscal data)
data/processed/     Clean panels (.xlsx)
outputs/            figures/ and tables/
docs/               Communication materials
```

## Reproducing the results

Requires **Python 3** (data) and **R 4.4+** (analysis). From the project root:

```bash
# Dependencies (once)
pip install pyxlsb pandas openpyxl requests
Rscript -e 'install.packages(c("here","tidyverse","readxl","writexl","openxlsx","patchwork","fixest","sandwich","lmtest"))'

# 1) Download complementary sources (Brent price and fiscal data)
python3 code/limpieza/00a_descargar_brent.py
python3 code/limpieza/00b_descargar_fiscal.py
# Optional (downloaded but not merged into the panel; see data/raw/FUENTES.md)
python3 code/limpieza/00d_descargar_riesgo.py     # EMBIG country risk
python3 code/limpieza/00e_descargar_reservas.py   # international reserves

# 2) Processing: IMF + Brent + fiscal -> panels in data/processed/  (~9 s)
python3 code/limpieza/00c_procesar.py
python3 code/limpieza/01_variables.py
python3 code/limpieza/02_validar.py

# 3) Descriptives in R (tables and figures; read the .xlsx panels)
Rscript code/descriptivas/01_tabla_resumen.R   # Table 1: descriptives by group
Rscript code/descriptivas/02_tabla_paises.R    # Table 2: classification of the 34 countries
Rscript code/descriptivas/03_fig_ruptura.R     # Figure 1: 2022 structural break
Rscript code/descriptivas/04_fig_brent.R       # Figure 2: co-movement with Brent
Rscript code/descriptivas/05_fig_impacto.R     # Figure 3: change by country

# 4) Model and analysis in R
Rscript code/06_modelo.R       # DiD/TWFE: main effect + event study (Table 4, Figure 4)
Rscript code/07_pieza_fiscal.R # subsidy–debt matrix and recommendation (Table 5, Figure 5)
Rscript code/08_robustez.R     # leave-one-out and outlier exclusion (Table 6)
```

Processing is done in Python (pyxlsb) because reading the IMF `.xlsb` file in R is
prohibitively slow; the analysis is 100% R. All outputs can be regenerated from
`data/raw/`.

## Visual conventions

Figures follow the **World Bank Data Visualization Style Guide** palette
(https://wbg-vis-design.vercel.app/, packages `wbpyplot` / `wbplot`), set in Times New
Roman. Tables follow an AER-style standard (Times New Roman, horizontal rules only, running
footnotes). Both are defined centrally in `code/config.R` and documented in
`docs/convenciones.md`.

## Use of AI

**Claude Code (Anthropic)** was used as a support assistant for three specific tasks:
(i) data validation and numerical consistency checks between the processed panel and the
reported results; (ii) producing AER-format tables through R scripts; and (iii) building and
editing the Beamer presentation, with iterative compilation to ensure it builds without
errors. In every case, methodological decisions —choice of estimator, country
classification, outcome variables, and identification strategy—were made by the author.

The `.claude/` folder documents how the assistant was configured. It contains:

- `.claude/rules/` — instructions defining the code, econometrics, table and academic
  writing standards the assistant had to follow in every task.
- `.claude/agents/` — specialized reviewers (R code, econometrics, proofreading) run on the
  scripts and slides before a result was reported as finished.
- `.claude/skills/` — reusable routines for recurring tasks (compiling LaTeX, running the
  analysis, committing).

## Repository contents

1. Data — `data/`
2. Processing code — `code/limpieza/`
3. Analysis code — `code/descriptivas/`, `code/06_modelo.R`, `code/07_pieza_fiscal.R`,
   `code/08_robustez.R`
4. Results presentation (Beamer, in Spanish) — `Prueba_Tecnica_Completa/`
