###############################################################
# 2022 oil shock - 08_robustness.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Robustness of the main effect (beta3, 06_model.R) to extreme countries.
#   The main sample (34 countries) is NOT changed: it is the baseline
#   specification. Here the TWFE is re-estimated dropping the outliers by hand
#   as a sensitivity check:
#     (1) full sample (replicates Table 3)
#     (2) without Venezuela  (the exporter with the most extreme subsidy)
#     (3) without Suriname   (the importer with the most extreme subsidy, in the control)
#     (4) without both
#   The note reports the leave-one-out range over the 7 exporters (re-estimating
#   beta3 dropping one at a time): the systematic test that no single country
#   drives the effect. Dropping countries based on the DV value would bias the
#   estimate if it were the main specification; as a sensitivity check alongside
#   the full sample, it is legitimate and transparent.
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs)
# Output: outputs/tables/tab4_robustness.xlsx
# N:      static estimator 2015-2022 = 269 (3 dropped for NA in LHS).
#         Subsamples: without VEN 261, without SUR 261, without both 253.
###############################################################

source(here::here("code/config.R"))
suppressMessages(library(fixest))

log_file <- iniciar_log("08_robustness")

# ---------------------------------------------------------------------------
# 1. Load and build (same as the static estimator in 06_model.R)
# ---------------------------------------------------------------------------

df <- cargar_panel_anio()
stopifnot(nrow(df) == 306)

df_est <- df |>
  filter(anio <= YEAR_SHOCK) |>                # 2015-2022 (post = 2022 only)
  mutate(
    subsidio   = 100 * expl_pctgdp,
    post2022   = as.integer(anio == YEAR_SHOCK),
    exportador = as.integer(exportador_neto)
  )

b <- "post2022:exportador"

# Main TWFE (same as column (2) of Table 3). post2022 is equivalent to the 2022
# dummy and is absorbed by the year FE; only the interaction is identified
# (within country and year), which is beta3.
twfe <- function(dd) feols(subsidio ~ post2022:exportador | iso + anio,
                           data = dd, cluster = ~ iso)

# ---------------------------------------------------------------------------
# 2. Robustness ladder: full / without VEN / without SUR / without both
# ---------------------------------------------------------------------------

m1 <- twfe(df_est)                                          # full
m2 <- twfe(filter(df_est, iso != "VEN"))                    # without Venezuela
m3 <- twfe(filter(df_est, iso != "SUR"))                    # without Suriname
m4 <- twfe(filter(df_est, !iso %in% c("VEN", "SUR")))       # without both
mods <- list(m1, m2, m3, m4)

cat("--- beta3 (Post2022 x Exporter), pp of GDP ---\n")
etq_col <- c("full", "w/o Venezuela", "w/o Suriname", "w/o both")
for (i in seq_along(mods)) {
  m <- mods[[i]]
  cat(sprintf("(%d) %-14s beta3 = %s  SE %s | N %d\n",
              i, etq_col[i], fmt_num(coef(m)[b], 3), fmt_num(se(m)[b], 3), nobs(m)))
}

# ---------------------------------------------------------------------------
# 3. Leave-one-out over exporters (re-estimate dropping one at a time)
# ---------------------------------------------------------------------------

exps <- sort(unique(df_est$iso[df_est$exportador == 1]))
loo  <- vapply(exps, function(x) coef(twfe(filter(df_est, iso != x)))[b], numeric(1))
loo_min <- min(loo); loo_max <- max(loo)
pais_min <- country_en(exps[which.min(loo)])
pais_max <- country_en(exps[which.max(loo)])

cat("\n--- Leave-one-out exporters (", length(exps), ") ---\n")
for (i in seq_along(exps))
  cat(sprintf("  w/o %-4s (%-18s) beta3 = %s\n",
              exps[i], country_en(exps[i]), fmt_num(loo[i], 3)))
cat(sprintf("LOO range: [%s, %s] | minimum when dropping %s\n",
            fmt_num(loo_min, 2), fmt_num(loo_max, 2), pais_min))

# ---------------------------------------------------------------------------
# 4. Table 4 (AER style) — helpers identical to 06_model.R
# ---------------------------------------------------------------------------

estrellas <- function(p) {
  if (is.na(p))      ""
  else if (p < .001) "***"
  else if (p < .01)  "**"
  else if (p < .05)  "*"
  else if (p < .10)  "†"
  else               ""
}

celda <- function(m) {
  ct <- as.data.frame(summary(m)$coeftable)[b, ]
  list(coef = paste0(fmt_num(ct[["Estimate"]], 3), estrellas(ct[["Pr(>|t|)"]])),
       se   = paste0("(", fmt_num(ct[["Std. Error"]], 3), ")"))
}

cs   <- lapply(mods, celda)
fila_coef <- c("Post2022 × Net exporter",    vapply(cs, `[[`, "", "coef"))
fila_se   <- c("",                           vapply(cs, `[[`, "", "se"))
ef_pais   <- c("Country FE", rep("Yes", length(mods)))
ef_anio   <- c("Year FE",    rep("Yes", length(mods)))
fila_n    <- c("N (country-years)", vapply(mods, function(m) as.character(nobs(m)), ""))

tabla6 <- as.data.frame(
  rbind(fila_coef, fila_se, ef_pais, ef_anio, fila_n),
  stringsAsFactors = FALSE
)
names(tabla6) <- c("Variable", "(1)", "(2)", "(3)", "(4)")

subhead <- c("", "Full\nsample", "Without\nVenezuela",
             "Without\nSuriname", "Without\nboth")

# Maximum subsidy of VEN and SUR (2022), to avoid hardcoding it in the note
ven_max <- fmt_num(max(df_est$subsidio[df_est$iso == "VEN"], na.rm = TRUE), 1)
sur_max <- fmt_num(max(df_est$subsidio[df_est$iso == "SUR"], na.rm = TRUE), 1)

n_c_full <- dplyr::n_distinct(df_est$iso[obs(m1)])

tab_path <- file.path(PATH$tab, "tab4_robustness.xlsx")
tabla_aer(
  tabla6,
  name        = "tab4_robustness.xlsx",
  titulo      = "Table 4. Robustness of the shock effect to extreme countries",
  subheader   = subhead,
  ancho_datos = 13,
  notas = c(
    paste0("Sensitivity of \u03b2\u2083 (Post2022 \u00d7 Net exporter) to excluding the ",
           "countries with the most extreme subsidies. All columns use the TWFE ",
           "specification of column (2) of Table 3; only the sample changes."),
    paste0("Column (1) is the full sample (", n_c_full, " countries). Columns (2)\u2013(4) ",
           "exclude Venezuela (the net oil exporter with the highest subsidy, ", ven_max,
           "% of GDP), Suriname (the net oil importer with the highest subsidy, ", sur_max,
           "% of GDP), and both. Excluding each of the ", num_en(length(exps)),
           " net oil exporters in turn gives estimates between ", fmt_num(loo_min, 2),
           " (without ", pais_min, ") and ", fmt_num(loo_max, 2), " (without ", pais_max,
           "); this is a range of point estimates, not a confidence interval."),
    paste("Standard errors are clustered by country in parentheses.",
          "\u2020 p < 0.10, * p < 0.05, ** p < 0.01, *** p < 0.001."),
    "Source: IMF Fossil Fuel Subsidies Database."
  )
)

# ---------------------------------------------------------------------------
# 5. Verification
# ---------------------------------------------------------------------------

# Column (1) must replicate the main TWFE of 06_model.R, if it has been run
f06 <- file.path(PATH$res, "06_model.rds")
b_main <- if (file.exists(f06)) {
  tw <- readRDS(f06)$twfe; tw$coef[tw$model == "twfe_explicit"]
} else unname(coef(m1)[b])
stopifnot(
  file.exists(tab_path),
  abs(coef(m1)[b] - b_main) < 1e-8,       # col (1) replicates Table 3
  all(loo > 0),                            # effect positive across the whole LOO
  nobs(m1) == 269
)
cat("\n--- Verification ---\n")
cat("Table generated: OK\n")
cat("Column (1) replicates Table 3 (beta3 =", fmt_num(b_main, 3), "): OK\n")
cat("Leave-one-out always positive [", fmt_num(loo_min, 2), ",",
    fmt_num(loo_max, 2), "]: OK\n")
cat("VERIFICATION PASS\n")

# ---------------------------------------------------------------------------
# 6. Key results for the paper (outputs/results/08_robustness.rds)
# ---------------------------------------------------------------------------
# Elements:
#   exclusions      data frame, one row per Table 4 column: column, sample
#                   (full / without_venezuela / without_suriname / without_both),
#                   coef, se, p_value, ci_low, ci_high, n_obs, n_countries
#   leave_one_out   data frame, one row per exporter dropped: iso, country, coef, se, p_value
#   loo_range       list: min, max, country_at_min, country_at_max
#   max_subsidy_pct_gdp  list: venezuela, suriname (max explicit subsidy 2015-2022)
#   n_exporters     number of exporters in the leave-one-out

excl_row <- function(m, column, sample) {
  ci <- confint(m)[b, ]
  data.frame(column = column, sample = sample,
             coef = unname(coef(m)[b]), se = unname(se(m)[b]),
             p_value = unname(pvalue(m)[b]),
             ci_low = unname(ci[[1]]), ci_high = unname(ci[[2]]),
             n_obs = nobs(m), n_countries = unname(m$fixef_sizes["iso"]),
             stringsAsFactors = FALSE)
}
exclusions <- rbind(
  excl_row(m1, "(1)", "full"),
  excl_row(m2, "(2)", "without_venezuela"),
  excl_row(m3, "(3)", "without_suriname"),
  excl_row(m4, "(4)", "without_both")
)

loo_fits <- suppressMessages(lapply(exps, function(x) twfe(filter(df_est, iso != x))))
leave_one_out <- data.frame(
  iso     = exps,
  country = country_en(exps),
  coef    = vapply(loo_fits, function(m) unname(coef(m)[b]),   numeric(1)),
  se      = vapply(loo_fits, function(m) unname(se(m)[b]),     numeric(1)),
  p_value = vapply(loo_fits, function(m) unname(pvalue(m)[b]), numeric(1)),
  stringsAsFactors = FALSE, row.names = NULL
)
stopifnot(isTRUE(all.equal(leave_one_out$coef, unname(loo))))

res_08 <- list(
  exclusions    = exclusions,
  leave_one_out = leave_one_out,
  loo_range     = list(min = loo_min, max = loo_max,
                       country_at_min = pais_min,
                       country_at_max = country_en(exps[which.max(loo)])),
  max_subsidy_pct_gdp = list(
    venezuela = max(df_est$subsidio[df_est$iso == "VEN"], na.rm = TRUE),
    suriname  = max(df_est$subsidio[df_est$iso == "SUR"], na.rm = TRUE)),
  n_exporters   = length(exps)
)
saveRDS(res_08, file.path(PATH$res, "08_robustness.rds"))
message("Results saved: ", file.path(PATH$res, "08_robustness.rds"))

cerrar_log()
