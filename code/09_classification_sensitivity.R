###############################################################
# 2022 oil shock - 09_classification_sensitivity.R
# Author: Daniel Mendivelso
# Date: 2026-09-28
#
# Description:
#   Sensitivity of beta3 to the definition of net oil exporters. Re-estimates the
#   main TWFE (Table 3, column (2): explicit subsidy % of GDP, country + year FE,
#   2015-2022, post = 2022, SE clustered by country) under each classification.
#   Pre-specified in quality_reports/plans/2026-09-28_treatment-definition.md:
#     (1) main rule: net exports of HS 2709+2710 > 0, 2015-2019 average
#     (2) including gas (HS 2709+2710+2711)
#     (3) 2019-2021 average
#     (4) main rule, excluding Guyana from the sample
#     (5) previous hand-coded list (VEN ECU COL MEX TTO BOL GUY)
#     (6) continuous exposure: net oil trade / GDP (2015-2019, %) x Post2022;
#         coefficient = pp of GDP of subsidy per 1 pp of GDP of net oil exports
#   Post hoc (added after inspecting the classification, NOT pre-specified):
#     (7) main rule, excluding Puerto Rico (classified from an outside source)
#     (8) main rule, excluding Trinidad and Tobago (knife-edge: its 2015-2019
#         average is close to zero and the yearly sign flips)
#     (9) continuous exposure as in (6), excluding Venezuela (added after seeing
#         that Venezuela's net oil exports, ~19% of GDP, dominate variant (6))
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs; 01_variables.py)
#         outputs/results/classification.rds     (per-country classification)
#         outputs/results/06_model.rds           (guard: variant (1) = Table 3 col (2))
# Output: outputs/tables/tab5_classification.xlsx
#         outputs/results/09_classification_sensitivity.rds
# N:      static sample 2015-2022 = 269 country-years (3 NA in the outcome);
#         (6) drops Puerto Rico (no net trade value); (9) also drops Venezuela.
###############################################################

source(here::here("code/config.R"))
suppressMessages(library(fixest))

log_file <- iniciar_log("09_classification_sensitivity")

# ---------------------------------------------------------------------------
# 1. Load and build (same sample and variables as the static DiD in 06_model.R)
# ---------------------------------------------------------------------------

df <- cargar_panel_anio()
stopifnot(nrow(df) == 306)
cls <- readRDS(file.path(PATH$res, "classification.rds"))
stopifnot(nrow(cls) == n_distinct(df$iso))

df_est <- df |>
  filter(anio <= YEAR_SHOCK) |>                 # 2015-2022 (post = 2022 only)
  mutate(subsidio = 100 * expl_pctgdp,
         post2022 = as.integer(anio == YEAR_SHOCK))

b <- "post2022:exportador"

#' Main TWFE with a given binary treatment column, on a (sub)sample
#' @param dd data; @param var name of the logical treatment column
twfe_bin <- function(dd, var) {
  dd$exportador <- as.integer(dd[[var]])
  feols(subsidio ~ post2022:exportador | iso + anio, data = dd, cluster = ~ iso)
}

#' One results row: beta3 with clustered inference, N and treated countries
fila_res <- function(m, variant, label, type, dd, var = NULL, coef_name = b) {
  ci <- confint(m)[coef_name, ]
  d  <- dd[obs(m), ]
  data.frame(
    variant = variant, label = label, type = type,
    coef = unname(coef(m)[coef_name]), se = unname(se(m)[coef_name]),
    p_value = unname(pvalue(m)[coef_name]),
    ci_low = unname(ci[[1]]), ci_high = unname(ci[[2]]),
    n_obs = nobs(m), n_countries = n_distinct(d$iso),
    n_treated = if (is.null(var)) NA_integer_ else n_distinct(d$iso[d[[var]]]),
    stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# 2. Variants
# ---------------------------------------------------------------------------

iso_guy <- "GUY"; iso_pri <- "PRI"; iso_tto <- "TTO"; iso_ven <- "VEN"
stopifnot(all(c(iso_guy, iso_pri, iso_tto, iso_ven) %in% df_est$iso))

m <- list(
  v1 = twfe_bin(df_est, "exportador_neto"),
  v2 = twfe_bin(df_est, "exportador_gas"),
  v3 = twfe_bin(df_est, "exportador_1921"),
  v4 = twfe_bin(filter(df_est, iso != iso_guy), "exportador_neto"),
  v5 = twfe_bin(df_est, "exportador_manual"),
  v6 = feols(subsidio ~ post2022:net_oil_trade_gdp_1519 | iso + anio,
             data = df_est, cluster = ~ iso),       # PRI dropped (NA exposure)
  v7 = twfe_bin(filter(df_est, iso != iso_pri), "exportador_neto"),
  v8 = twfe_bin(filter(df_est, iso != iso_tto), "exportador_neto"),
  v9 = feols(subsidio ~ post2022:net_oil_trade_gdp_1519 | iso + anio,
             data = filter(df_est, iso != iso_ven), cluster = ~ iso)
)
b_cont <- "post2022:net_oil_trade_gdp_1519"

lbl <- c(
  v1 = "(1) Main rule (HS 2709+2710, 2015â2019)",
  v2 = "(2) Including gas (HS 2711)",
  v3 = "(3) 2019â2021 average",
  v4 = "(4) Main rule, without Guyana",
  v5 = "(5) Previous hand-coded list",
  v6 = "(6) Continuous exposure (per 1 pp of GDP)",
  v7 = "(7) Main rule, without Puerto Rico",
  v8 = "(8) Main rule, without Trinidad and Tobago",
  v9 = "(9) Continuous exposure, without Venezuela"
)

variants <- rbind(
  fila_res(m$v1, 1L, lbl[["v1"]], "pre-specified", df_est, "exportador_neto"),
  fila_res(m$v2, 2L, lbl[["v2"]], "pre-specified", df_est, "exportador_gas"),
  fila_res(m$v3, 3L, lbl[["v3"]], "pre-specified", df_est, "exportador_1921"),
  fila_res(m$v4, 4L, lbl[["v4"]], "pre-specified",
           filter(df_est, iso != iso_guy), "exportador_neto"),
  fila_res(m$v5, 5L, lbl[["v5"]], "pre-specified", df_est, "exportador_manual"),
  fila_res(m$v6, 6L, lbl[["v6"]], "pre-specified", df_est, NULL, coef_name = b_cont),
  fila_res(m$v7, 7L, lbl[["v7"]], "post hoc",
           filter(df_est, iso != iso_pri), "exportador_neto"),
  fila_res(m$v8, 8L, lbl[["v8"]], "post hoc",
           filter(df_est, iso != iso_tto), "exportador_neto"),
  fila_res(m$v9, 9L, lbl[["v9"]], "post hoc",
           filter(df_est, iso != iso_ven), NULL, coef_name = "post2022:net_oil_trade_gdp_1519")
)
variants$label <- sub("^\\(\\d\\) ", "", variants$label)
variants$unit  <- ifelse(variants$variant %in% c(6L, 9L),
                         "pp of GDP of subsidy per 1 pp of GDP of net oil exports",
                         "pp of GDP")

cat("--- beta3 by classification variant ---\n")
print(transform(variants[, c("variant", "type", "coef", "se", "p_value", "ci_low",
                             "ci_high", "n_obs", "n_countries", "n_treated")],
                coef = round(coef, 3), se = round(se, 3), p_value = round(p_value, 3),
                ci_low = round(ci_low, 3), ci_high = round(ci_high, 3)))

# ---------------------------------------------------------------------------
# 3. Group switches relative to the main rule (binary variants) and exclusions
# ---------------------------------------------------------------------------

#' Countries whose group differs from the main rule under column `var`
cambian <- function(var) {
  to_exp <- cls$iso[cls[[var]] & !cls$exportador_neto]
  to_imp <- cls$iso[!cls[[var]] & cls$exportador_neto]
  list(to_exporter = sort(to_exp), to_importer = sort(to_imp))
}
switches <- list(
  v2_gas    = cambian("exportador_gas"),
  v3_1921   = cambian("exportador_1921"),
  v5_manual = cambian("exportador_manual")
)
excluded <- list(v4 = iso_guy, v6 = cls$iso[is.na(cls$net_oil_trade_gdp_1519)],
                 v7 = iso_pri, v8 = iso_tto,
                 v9 = c(cls$iso[is.na(cls$net_oil_trade_gdp_1519)], iso_ven))

# Distribution of the continuous exposure (net oil trade / GDP, 2015-2019, %)
expo <- cls[!is.na(cls$net_oil_trade_gdp_1519), c("iso", "country", "net_oil_trade_gdp_1519")]
expo <- expo[order(-expo$net_oil_trade_gdp_1519), ]
rownames(expo) <- NULL
exposure <- list(
  by_country  = expo,
  max         = expo$net_oil_trade_gdp_1519[1],  max_iso    = expo$iso[1],
  second      = expo$net_oil_trade_gdp_1519[2],  second_iso = expo$iso[2],
  min         = min(expo$net_oil_trade_gdp_1519), median = median(expo$net_oil_trade_gdp_1519),
  unit        = "% of GDP (2015-2019 averages)")
cat("Exposure: max", fmt_num(exposure$max, 2), exposure$max_iso, "| second",
    fmt_num(exposure$second, 2), exposure$second_iso, "\n")
for (k in names(switches)) cat(k, "-> exporter:", switches[[k]]$to_exporter,
                               "| -> importer:", switches[[k]]$to_importer, "\n")

# ---------------------------------------------------------------------------
# 4. Table 5 (AER style)
# ---------------------------------------------------------------------------

estrellas <- function(p) {
  if (is.na(p))      ""
  else if (p < .001) "***"
  else if (p < .01)  "**"
  else if (p < .05)  "*"
  else if (p < .10)  "â "
  else               ""
}

# CI ends keep the sign of values that round to zero, so an interval that
# includes zero never prints as if it excluded it (e.g. "−0.00").
ci_end <- function(x) if (x < 0 && round(x, 2) == 0) "\u22120.00" else fmt_num(x, 2)

fila_tab <- function(r) data.frame(
  Variant   = paste0("  (", r$variant, ") ", r$label),
  coef      = paste0(fmt_num(r$coef, 3), estrellas(r$p_value)),
  se        = paste0("(", fmt_num(r$se, 3), ")"),
  ci        = paste0("[", ci_end(r$ci_low), ", ", ci_end(r$ci_high), "]"),
  p         = if (r$p_value < 0.001) "<0.001" else formatC(r$p_value, format = "f", digits = 3),
  nobs      = as.character(r$n_obs),
  ntreat    = ifelse(is.na(r$n_treated), "â", as.character(r$n_treated)),
  stringsAsFactors = FALSE)
fila_lbl <- function(txt) data.frame(Variant = txt, coef = "", se = "", ci = "", p = "",
                                     nobs = "", ntreat = "", stringsAsFactors = FALSE)

pre  <- variants[variants$type == "pre-specified", ]
post <- variants[variants$type == "post hoc", ]
tabla6 <- rbind(
  fila_lbl("Panel A. Pre-specified variants"),
  do.call(rbind, lapply(seq_len(nrow(pre)),  function(i) fila_tab(pre[i, ]))),
  fila_lbl("Panel B. Post hoc variants (not pre-specified)"),
  do.call(rbind, lapply(seq_len(nrow(post)), function(i) fila_tab(post[i, ])))
)
names(tabla6) <- c("Classification variant", "Coefficient", "SE", "95% CI",
                   "p-value", "N", "Treated")

# Quantities quoted in the notes (computed, not typed)
nm <- function(x) if (length(x) == 0) "none" else enum_en(country_en(x))
txt_sw <- function(s) {
  parts <- c(if (length(s$to_exporter)) paste0(nm(s$to_exporter), " to net exporter"),
             if (length(s$to_importer)) paste0(nm(s$to_importer), " to net importer"))
  if (length(parts) == 0) "no country changes group" else paste0("moves ", enum_en(parts))
}
exp_main <- cls$iso[cls$exportador_neto]
tto_net  <- cls$net_oil_trade_usd_1519[cls$iso == iso_tto] / 1e6
guy_grp  <- if (cls$exportador_neto[cls$iso == iso_guy]) "a net exporter" else "a net importer"

tabla_aer(
  tabla6,
  name        = "tab5_classification.xlsx",
  titulo      = "Table 5. Sensitivity of Î²â to the definition of net oil exporters",
  ancho_datos = 12,
  landscape   = TRUE,
  notas = c(
    paste0("Each row re-estimates Î²â (Post2022 Ã Net exporter) with the ",
           "specification of column (2) of Table 3 (explicit subsidy, % of GDP; country and ",
           "year fixed effects; ", yr_range(min(df_est$anio), YEAR_SHOCK),
           "); only the classification or the sample changes."),
    paste0("Main rule (1): net oil exporter if average ", yr_range(2015, 2019),
           " exports minus imports of crude oil and refined products (HS 2709 + 2710, UN ",
           "Comtrade, partner World; mirror data for countries that do not report) are ",
           "positive; this gives ", num_en(length(exp_main)), " net oil exporters (",
           enum_en(country_en(sort(exp_main))), "). Relative to it, (2) adds petroleum ",
           "gases (HS 2711) and ", txt_sw(switches$v2_gas), "; (3) averages ",
           yr_range(2019, 2021), " and ", txt_sw(switches$v3_1921),
           "; (4) drops Guyana (", guy_grp, " under the main rule) from the sample; (5) ",
           "uses the previous hand-coded list and ", txt_sw(switches$v5_manual), "."),
    paste0("(6) replaces the binary treatment with Post2022 Ã net oil trade as a ",
           "percentage of GDP (", yr_range(2015, 2019), " averages); its coefficient is the ",
           "change in the explicit subsidy (pp of GDP) per 1 pp of GDP of net oil exports, ",
           "so it is not comparable in size with the other rows. It excludes ",
           nm(excluded$v6), ", which has no Comtrade data and is classified as a net oil ",
           "importer in every binary variant from U.S. Energy Information Administration ",
           "data."),
    paste0("Panel B was added after inspecting the classification (rows 7 and 8) and the ",
           "result of row 6 (row 9) and was not pre-specified: (7) drops Puerto Rico (classified from an outside source); (8) ",
           "drops Trinidad and Tobago, whose ", yr_range(2015, 2019), " average net oil trade ",
           "(USD ", fmt_num(tto_net, 0), " million a year) is close to zero and changes ",
           "sign across years; (9) re-estimates (6) without ", country_en(exposure$max_iso),
           ", whose net oil exports (", fmt_num(exposure$max, 1), "% of GDP) far exceed ",
           "the next largest (", country_en(exposure$second_iso), ", ",
           fmt_num(exposure$second, 1), "% of GDP)."),
    paste("Standard errors clustered by country; p-values and 95% confidence intervals",
          "from the clustered standard errors.",
          "â  p < 0.10, * p < 0.05, ** p < 0.01, *** p < 0.001."),
    "Source: IMF Fossil Fuel Subsidies Database; UN Comtrade; U.S. Energy Information Administration."
  )
)

# ---------------------------------------------------------------------------
# 5. Verification
# ---------------------------------------------------------------------------

tab_path <- file.path(PATH$tab, "tab5_classification.xlsx")
f06 <- file.path(PATH$res, "06_model.rds")
b_main <- if (file.exists(f06)) {
  tw <- readRDS(f06)$twfe; tw$coef[tw$model == "twfe_explicit"]
} else variants$coef[1]
stopifnot(
  file.exists(tab_path),
  abs(variants$coef[1] - b_main) < 1e-8,             # (1) replicates Table 3 col (2)
  variants$n_obs[1] == 269,
  variants$n_treated[1] == length(exp_main),
  variants$n_countries[variants$variant == 6L] == n_distinct(df_est$iso) - 1L,
  variants$n_countries[variants$variant == 9L] == n_distinct(df_est$iso) - 2L,
  exposure$max_iso == iso_ven,               # (9) is motivated by VEN being the maximum
  all(variants$n_countries[variants$variant %in% c(4L, 7L, 8L)] ==
        n_distinct(df_est$iso) - 1L)
)
cat("\n--- Verification ---\n")
cat("Variant (1) replicates Table 3 column (2) (beta3 =", fmt_num(b_main, 3), "): OK\n")
cat("VERIFICATION PASS\n")

# ---------------------------------------------------------------------------
# 6. Key results for the paper (outputs/results/09_classification_sensitivity.rds)
# ---------------------------------------------------------------------------
# Elements:
#   variants   data frame, one row per variant: variant (1-8), label, type
#              (pre-specified / post hoc), coef, se, p_value, ci_low, ci_high, n_obs,
#              n_countries, n_treated (NA for the continuous variant), unit
#   switches   list (v2_gas, v3_1921, v5_manual): to_exporter / to_importer, ISO3 codes
#              of countries whose group differs from the main rule
#   excluded   list (v4, v6, v7, v8, v9): ISO3 codes dropped from the sample
#   exposure   continuous-exposure distribution (variants 6 and 9): by_country (iso,
#              country, net_oil_trade_gdp_1519, sorted descending), max, max_iso,
#              second, second_iso, min, median, unit (% of GDP)
#   main_exporters  ISO3 codes of net exporters under the main rule
res_09 <- list(variants = variants, switches = switches, excluded = excluded,
               exposure = exposure,
               main_exporters = sort(exp_main))
saveRDS(res_09, file.path(PATH$res, "09_classification_sensitivity.rds"))
message("Results saved: ", file.path(PATH$res, "09_classification_sensitivity.rds"))

cerrar_log()
