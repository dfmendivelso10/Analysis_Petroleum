# The 2022 Oil Price Shock and Fossil Fuel Subsidies in Latin America

Personal applied economics project. It estimates how explicit fossil fuel subsidies in
Latin America and the Caribbean responded to the 2022 international oil price shock,
depending on each country's net oil trade position, and discusses the fiscal implications
for subsidy reform.

📄 **[Read the working paper (PDF)](report/oil_shock_subsidies_LAC.pdf)** ·
🧭 **[Design decisions](DECISIONS.md)**

## Research question

How did the 2022 oil price shock affect fossil fuel subsidies in Latin America, and what
does it imply for fiscal and subsidy policy?

## Key results

- **Differential response:** in 2022 the explicit subsidy of the seven net oil exporters
  rose **1.79 pp of GDP more** than that of net importers (TWFE difference-in-differences,
  34 countries, 2015–2022; clustered SE 0.92, p = 0.06, 95% CI [−0.08, 3.66]). With only
  seven treated countries, conventional clustered inference is likely optimistic.
- **Pre-trends:** pre-shock coefficients have no monotonic trend, but a joint test rejects
  that they are all zero (F(6, 33) = 4.09, p = 0.004) and they co-move with the Brent
  price, so the estimate should be read with caution.
- **Auxiliary outcomes:** no detectable differential response of the implicit subsidy
  (−0.32 pp, not significant); the differential fades in 2023 (+0.14 pp) as Brent falls.
- **Sensitivity:** dropping each exporter in turn keeps the estimate positive
  (1.15 to 2.21 pp).
- **Policy:** fiscal pressure is not limited to exporters. Eight countries, five of them
  net importers, combine above-median subsidies with above-median public debt; the paper
  argues for reform sequenced by fiscal space, with targeted compensation instead of
  universal price subsidies.

## Data sources

- **IMF Fossil Fuel Subsidies Database**: explicit and implicit subsidies.
- **EIA**: Brent crude oil price.
- **IMF World Economic Outlook** (via IMF DataMapper): fiscal indicators (gross public debt,
  fiscal balance, general government revenue). The WEO is used instead of the World Bank
  because it covers all 34 countries with no missing values (World Bank data has 50–79 %
  missing values for the Caribbean).

Downloaded for reference but not merged into the panel: EMBIG country risk (BCRP) and
international reserves (World Bank). Details for each source, including URL and the reason
for inclusion or exclusion, are in `data/raw/SOURCES.md`.

## Structure

```
code/               config.R + model (06), fiscal analysis (07) and robustness (08)
code/cleaning/      download, processing, validation and data dictionary (Python)
code/descriptives/  descriptive tables and figures (01–05), tables to PDF (R)
data/raw/           Unmodified raw sources (IMF .xlsb, Brent, WEO fiscal data)
data/processed/     Clean panels (.xlsx)
outputs/            figures/ and tables/
docs/               Visual conventions, variable dictionary, model variables
outputs/results/    Key estimates (.rds) and figure notes read by the paper
report/             Working paper: R Markdown source, bibliography and rendered PDF
DECISIONS.md        Methodological and data decisions, and why
```

## Reproducing the results

Requires **Python 3** (data) and **R 4.4+** (analysis). From the project root:

```bash
# Dependencies (once)
pip install pyxlsb pandas openpyxl requests
Rscript -e 'install.packages(c("here","tidyverse","readxl","writexl","openxlsx","patchwork","fixest","sandwich","lmtest","magick","ggrepel","rmarkdown","knitr"))'

# 1) Download complementary sources (Brent price and fiscal data)
python3 code/cleaning/00a_download_brent.py
python3 code/cleaning/00b_download_fiscal.py
# Optional (downloaded but not merged into the panel; see data/raw/SOURCES.md)
python3 code/cleaning/00d_download_risk.py       # EMBIG country risk
python3 code/cleaning/00e_download_reserves.py   # international reserves

# 2) Processing: IMF + Brent + fiscal -> panels in data/processed/  (~9 s)
python3 code/cleaning/00c_process.py
python3 code/cleaning/01_variables.py
python3 code/cleaning/02_validate.py

# 3) Descriptives in R (tables and figures; read the .xlsx panels)
Rscript code/descriptives/01_summary_table.R  # Table 1: descriptives by group
Rscript code/descriptives/02_country_table.R  # Table 2: classification of the 34 countries
Rscript code/descriptives/03_fig_break.R      # Figure 1: 2022 structural break
Rscript code/descriptives/04_fig_brent.R      # Figure 2: co-movement with Brent
Rscript code/descriptives/05_fig_impact.R     # Figure 3: change by country

# 4) Model and analysis in R (08 runs before 07: the fiscal figure cites its results)
Rscript code/06_model.R            # DiD/TWFE: main effect + event study (Table 3, Figure 4)
Rscript code/08_robustness.R       # exclusions and leave-one-out (Table 4)
Rscript code/07_fiscal_analysis.R  # subsidy–debt matrix (Table 5, Figure 5)

# 5) Working paper (needs XeLaTeX; reads outputs/results, figures and tables)
Rscript -e 'rmarkdown::render("report/oil_shock_subsidies_LAC.Rmd")'
```

Processing is done in Python (pyxlsb) because reading the IMF `.xlsb` file in R is
prohibitively slow; the analysis is 100% R. All outputs can be regenerated from
`data/raw/`.

## Visual conventions

Figures follow the **World Bank Data Visualization Style Guide** palette
(https://wbg-vis-design.vercel.app/, packages `wbpyplot` / `wbplot`), set in Times New
Roman. Tables follow an AER-style standard (Times New Roman, horizontal rules only, running
footnotes). Both are defined centrally in `code/config.R` and documented in
`docs/conventions.md`.

## Use of AI

**Claude Code (Anthropic)** was used as a support assistant for three specific tasks:
(i) data validation and numerical consistency checks between the processed panel and the
reported results; (ii) producing AER-format tables through R scripts; and (iii) drafting and
revising the working paper in R Markdown, including review passes on prose, econometric
framing, numerical consistency and layout. In every case, methodological decisions —choice of estimator, country
classification, outcome variables, and identification strategy—were made by the author.

The `.claude/` folder documents how the assistant was configured. It contains:

- `.claude/rules/` — instructions defining the code, econometrics, table and academic
  writing standards the assistant had to follow in every task.
- `.claude/agents/` — specialized reviewers (R code, econometrics, proofreading) run on the
  scripts and the paper before a result was reported as finished.
- `.claude/skills/` — reusable routines for recurring tasks (compiling LaTeX, running the
  analysis, committing).

## Repository contents

1. Data — `data/`
2. Processing code — `code/cleaning/`
3. Analysis code — `code/descriptives/`, `code/06_model.R`, `code/07_fiscal_analysis.R`,
   `code/08_robustness.R`
4. Working paper (R Markdown → PDF) — `report/`
5. Design decisions — `DECISIONS.md`
