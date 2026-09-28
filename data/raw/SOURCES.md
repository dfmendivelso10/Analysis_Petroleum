# Raw data sources

Sources marked **[in panel]** are merged into the analysis panel
(`data/processed/panel_country_year.xlsx`). Sources marked **[downloaded, not merged]**
are downloaded reproducibly and kept in the repo for traceability, but do not enter the
main panel (the reason is documented for each one).

## imffossilfuelsubsidiesdata.xlsb  [in panel]
- **Source:** IMF — Fossil Fuel Subsidies Database (Fiscal Affairs Department).
- **Content:** explicit and implicit fossil fuel subsidies by country, year, fuel and
  end use. Baseline scenario (U1).
- **Use:** main data source of the analysis.

## brent_annual.csv  [in panel]
- **Source:** U.S. Energy Information Administration (EIA), Europe Brent Spot Price FOB,
  annual average in USD per barrel. Downloaded via datahub.io/core/oil-prices
  (series "brent-year", based on EIA data).
- **URL:** https://datahub.io/core/oil-prices/r/brent-year.csv
- **Download:** reproducible with `python3 code/cleaning/00a_download_brent.py`
- **Period:** 2015–2023.
- **Use:** international price shock variable. The IMF database does not include the
  oil price, so it is added as a complementary source.

## fiscal_weo.xlsx  [in panel]
- **Source:** IMF World Economic Outlook, via the IMF DataMapper API. Three fiscal
  indicators for the general government, in % of GDP:
  - fiscal balance (net lending/borrowing) — GGXCNL_NGDP
  - gross public debt — GGXWDG_NGDP
  - government revenue — GGR_G01_GDP_PT
- **Download:** reproducible with `python3 code/cleaning/00b_download_fiscal.py`
- **Period / coverage:** 2015–2023, all 34 Latin American and Caribbean countries,
  no missing values.
- **Use:** fiscal-space analysis (subsidy–debt matrix). The fiscal variables are
  outcomes of the shock, so they are **not** used as controls in the DiD model.

## fiscal_wb.csv  [legacy, not used]
- **Source:** World Bank Open Data (API): fiscal balance (GC.NLD.TOTL.GD.ZS), central
  government debt (GC.DOD.TOTL.GD.ZS) and revenue (GC.REV.XGRT.GD.ZS), % of GDP.
- **Why not used:** 50–79 % missing values for the Caribbean, which prevents a
  country-by-country fiscal comparison. Replaced by the WEO series above; kept only
  for traceability of that decision.

## country_risk.csv  [downloaded, not merged]
- **Source:** Central Reserve Bank of Peru (BCRP), EMBIG series (Emerging Markets Bond
  Index spread), sovereign spread in basis points. Monthly values averaged to annual.
- **Download:** reproducible with `python3 code/cleaning/00d_download_risk.py`
- **Coverage:** 8 Latin American countries that issue USD debt (ARG, BRA, CHL, COL,
  ECU, MEX, PER, VEN), 2015–2023. Small Caribbean islands have no EMBI.
- **Use:** proxy for sovereign financing costs. **Not merged into the panel:** its
  coverage (8 of 34 countries, 70/306 observations) would bias the sample toward
  large economies. Kept as a complementary reference.

## reserves_wb.csv  [downloaded, not merged]
- **Source:** World Bank Open Data (API), international reserves:
  - total reserves (incl. gold), current USD — FI.RES.TOTL.CD
  - reserves in months of imports — FI.RES.TOTL.MO
- **Download:** reproducible with `python3 code/cleaning/00e_download_reserves.py`
- **Period / coverage:** 2015–2023, 34 Latin American countries (291/284 observations).
- **Use:** balance-of-payments dimension (external buffer). **Not merged into the
  panel.** Kept as a reference in case the external angle is revisited.
