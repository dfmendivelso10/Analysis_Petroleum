# Design decisions

A short log of the main methodological and data choices behind the project, and why
they were made. Details and numbers are in the working paper (`report/`).

## Research design

- **Identification: difference-in-differences (TWFE).** The 2022 Brent spike was driven
  by the Russian invasion of Ukraine: a global, unexpected shock that no Latin American
  country could move through its own subsidy policy. That makes it plausibly exogenous
  to subsidy policy. All countries faced the same price increase, so the design
  identifies the *differential* response of net exporters relative to net importers,
  not the total effect of the shock. A before/after comparison would attribute every
  2022 change (post-pandemic rebound, inflation) to the shock, and a 2022 cross-section
  would confuse the effect with pre-existing level differences. Both differences are
  needed at once.
- **Treatment rule fixed before estimation (2026-09-28).** Net oil exporter = positive
  average 2015–2019 net trade in crude and refined products (HS 2709 + 2710, UN Comtrade;
  mirror data where a country does not report). Chosen before seeing results; the earlier
  hand-coded list of seven exporters and other variants are reported only as sensitivity.
- **Treatment = net oil exporter × post-2022.** Classification is by *net* oil trade
  position, not by whether a country produces oil: Argentina and Brazil extract crude
  but import more refined products than they export, so they do not capture oil rents
  when prices rise. The Brent level itself is absorbed by year fixed effects;
  identification comes only from the interaction.
- **Outcome = explicit subsidy (% of GDP).** The explicit subsidy is the gap between
  consumer price and supply cost, so it reacts directly to the oil price. The implicit
  subsidy (externalities and forgone taxes) is dominated by slow-moving structural
  components and is used as an auxiliary (falsification) outcome. It is an imperfect
  one: both measures are built jointly and the forgone-VAT part of the implicit
  subsidy scales with the price.
- **No fiscal controls in the model.** Debt, fiscal balance and revenue are themselves
  affected by the shock (they are outcomes, not exogenous covariates), so including
  them would introduce bias. They are used only in the policy section.
- **Countries weighted equally.** The model treats each country as one unit (no GDP
  weighting). Country-level responses are very heterogeneous, so large economies
  should not dominate the estimate; heterogeneity is then addressed in the policy
  section country by country.

## Data

- **Sample window 2015–2023.** Pre-shock years 2015–2021 to assess parallel
  trends (six event-study leads relative to 2021), the treatment year (2022) and the
  reversal year (2023).
  2015 is the first year extracted from the IMF database.
- **IMF WEO instead of World Bank for fiscal data.** The policy analysis crosses debt
  against subsidies country by country, which requires full coverage. The WEO covers
  all 34 countries with no missing values; the World Bank series leave 50–79 % missing
  values for the Caribbean.
- **Country risk (EMBIG) and reserves downloaded but not merged.** EMBIG covers only
  8 of 34 countries and would bias the sample toward large economies; reserves were
  kept as a reference for a possible external-sector extension. See
  `data/raw/SOURCES.md`.
- **Processing in Python, analysis in R.** Reading the IMF `.xlsb` file in R is
  prohibitively slow; `pyxlsb` handles it in seconds. All modelling is in R.

## Inference and robustness

- **Small treated group (7 exporters).** Standard errors are clustered by country, but
  with seven treated clusters conventional inference is likely optimistic (p ≈ 0.06 for
  the main effect). Wild cluster bootstrap, randomization inference and Conley–Taber
  intervals are the natural next checks; they are listed as extensions, not claimed.
- **Parallel trends assessed with an event study, and reported honestly.** Pre-shock
  coefficients show no monotonic trend, but a joint test rejects that they are all zero
  (F(6, 33) = 4.09, p = 0.004) and they co-move with the Brent price. With a single
  post-shock year this can bias the estimate, so the paper discusses it rather than
  attributing it to noise, and points to Rambachan–Roth sensitivity analysis.
- **Leave-one-out instead of dropping outliers by hand.** Venezuela is an extreme value,
  but dropping it ad hoc would be selection on the outcome. Re-estimating without each
  exporter keeps the effect positive in all cases
  (range 1.15–2.21 pp of GDP).

## Policy analysis

- **Subsidy–debt matrix split at the medians.** Medians rather than means, because they
  are robust to extreme values such as Venezuela. Fiscal space is proxied by the debt
  stock rather than the one-year deficit, which is volatile and cyclical.
- **The matrix is descriptive prioritisation, not a causal model.** It indicates where
  reform is most pressing; it does not estimate the effect of any specific policy.
- **Illustrative differential cost for all exporters.** β3 × 2022 GDP is computed for
  all seven exporters (including Guyana, whose subsidy fell, to avoid selecting on the
  outcome), with a range from β3's 95% CI. It is not the total cost of the shock.

## Communication

- **A working paper instead of slides.** The results were first presented in a Spanish
  Beamer deck. It was replaced by an English R Markdown working paper whose numbers are
  computed from the pipeline outputs at render time, so text, tables and figures cannot
  drift apart. Writing it surfaced several errors in the deck (e.g. the largest 2022
  increase was Suriname, a net importer, not an exporter).
