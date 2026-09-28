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

## oil_trade_comtrade.csv  [in panel, via the treatment classification]
- **Source:** UN Comtrade, public preview API (no key), annual HS trade with partner =
  World, value in current USD (`primaryValue`), aggregate customs regime and transport
  mode only (`customsCode` C00, `motCode` 0, `partner2Code` 0).
- **URL:** https://comtradeapi.un.org/public/v1/preview/C/A/HS
- **Download:** reproducible with `python3 code/cleaning/00f_download_oil_trade.py`
  (network access required; ~80 calls, ~2 minutes).
- **Content:** one row per country × year × commodity × flow: HS 2709 (crude), HS 2710
  (refined products), HS 2711 (petroleum gases, sensitivity only); flows M and X;
  34 countries, 2015–2023 (1,836 rows). Columns: `iso`, `year`, `cmd`, `flow`,
  `value_usd`, `source` (`own` | `mirror`), `n_partners` (reporting partners, mirror rows).
- **Own vs mirror:** a country-year-flow is own-reported when the country publishes its
  TOTAL trade for that year and flow; a commodity missing from an own report is recorded
  as 0 (Comtrade does not publish zero rows). Otherwise the value is rebuilt from
  partners' reports (partners' imports from the country = its exports; partners'
  exports to it = its imports; World and EU aggregates excluded). Mirror imports are
  valued CIF and mirror exports FOB by the partner, so they are an approximation.
- **Coverage, 2015–2019:** 29 countries report every year. Dominica does not report
  2015; Haiti and St. Kitts and Nevis do not report 2018–2019 (mirror rows are stored,
  but under the treatment rule these countries are averaged over their own-reported
  years). Venezuela reports no year 2015–2023 and is classified from mirror data
  (11–16 partners report its crude exports and 16–39 its refined-product trade;
  crude imports come from at most 2 partners). Aruba reports under its own code (533) every year.
  **Puerto Rico** is not a Comtrade reporter and does not exist as a partner either:
  Comtrade's code 842 ("USA") covers the USA, Puerto Rico and the US Virgin Islands,
  so partners book trade with Puerto Rico under the USA. Its own and mirror rows are
  therefore all zero with `n_partners` = 0, which means *no data*, not zero trade.
  **Documented exception:** Puerto Rico is classified as a net oil importer from an
  outside source (source = `external` in `outputs/results/classification.rds`): it has
  no crude oil production and no operating refinery (the last refineries closed in the
  2000s) and imports all refined products — U.S. Energy Information Administration,
  Puerto Rico territory energy profile, https://www.eia.gov/state/print.php?sid=RQ.
  It is an importer in every binary variant; its net oil trade is left missing (not 0),
  so it drops out of the continuous-exposure variant.
- **Use:** pre-specified treatment rule (`quality_reports/plans/
  2026-09-28_treatment-definition.md`), built in `code/cleaning/01_variables.py`:
  net oil exporter iff the 2015–2019 average of exports − imports of HS 2709 + 2710 is
  positive; sensitivity variants add HS 2711 or use 2019–2021.
