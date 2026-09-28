###############################################################
# 2022 oil shock - 06_model.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Main model of the effect of the 2022 shock on explicit fossil fuel subsidies,
#   estimated by difference-in-differences (DiD). The specification was fixed in a
#   written plan before estimation: no specification search.
#
#   Estimand: beta3 = differential change in the explicit subsidy (% of GDP) of net
#   exporters relative to net importers, from the pre-shock period (2015-2021) to
#   the shock year (2022 only; the static sample is 2015-2022 and 2023 is left out),
#   under parallel trends. Importers are also exposed to the price shock, so beta3
#   is a differential effect, not the total effect of the shock on exporters. The
#   event study (2015-2023) is the only place where 2023 enters.
#
#   Model ladder (simple -> robust):
#     (1) 2x2 DiD:  Subsidy ~ Post2022 * Exporter             [main-effect terms]
#     (2) TWFE:     Subsidy ~ Post2022:Exporter | iso + year  [country and year FE]
#     (3) Alt DV:   (2) with implicit and total as DV         [channel robustness]
#   Event study: Subsidy ~ sum_t (year_t : Exporter) | iso + year, base 2021.
#   SEs clustered by country throughout (project convention).
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs = 34 countries x 9 years)
# Output: outputs/tables/tab3_model.xlsx       (regression table)
#         outputs/figures/fig4_eventstudy.png   (event study)
###############################################################

source(here::here("code/config.R"))
suppressMessages(library(fixest))

log_file <- iniciar_log("06_model")

# ---------------------------------------------------------------------------
# 1. Load, check and build model variables
# ---------------------------------------------------------------------------

df <- cargar_panel_anio()
stopifnot(nrow(df) == 306)

# The shock is 2022. The static estimator compares 2022 (post) against the pre-shock
# period (2015-2021); 2023 is EXCLUDED from the estimator because it is already
# recovery (Brent falls) and pooling it would dilute the shock effect. The event
# study (below) does keep 2023 to show that the effect reverses.
df_est <- df |>
  filter(anio <= YEAR_SHOCK) |>                # 2015-2022 for the static DiD
  mutate(
    subsidio   = 100 * expl_pctgdp,            # main DV: explicit (% of GDP)
    subs_impl  = 100 * impl_pctgdp,            # alt DV: implicit (% of GDP)
    subs_tot   = 100 * tot_pctgdp,             # alt DV: total (% of GDP)
    post2022   = as.integer(anio == YEAR_SHOCK),  # post = shock year only
    exportador = as.integer(exportador_neto)
  )

# Full panel (with 2023) for the event study and derived variables
df <- df |>
  mutate(
    subsidio   = 100 * expl_pctgdp,
    exportador = as.integer(exportador_neto)
  )

n_pais <- dplyr::n_distinct(df$iso)
n_exp  <- dplyr::n_distinct(df$iso[df$exportador_neto])
cat("Panel:", nrow(df), "obs |", n_pais, "countries (",
    n_exp, "exporters,", n_pais - n_exp, "importers)\n")

# ---------------------------------------------------------------------------
# 2. Ladder of static models
# ---------------------------------------------------------------------------

# (1) Pure 2x2 DiD: main-effect terms + interaction (didactic, shows where beta3
#     comes from). SE clustered by country. Panel 2015-2022 (post = 2022 only).
m1 <- feols(subsidio ~ post2022 * exportador, data = df_est, cluster = ~ iso)

# (2) TWFE: country and year fixed effects. post2022 and exportador drop out
#     (absorbed); only the interaction survives = beta3 identified within country-year.
m2 <- feols(subsidio ~ post2022:exportador | iso + anio, data = df_est, cluster = ~ iso)

# (3) Alternative DVs with the same TWFE specification (channel robustness): the
#     effect should be smaller or null for implicit and total, which do not react to
#     the international price in the short run.
m3_impl <- feols(subs_impl ~ post2022:exportador | iso + anio, data = df_est, cluster = ~ iso)
m3_tot  <- feols(subs_tot  ~ post2022:exportador | iso + anio, data = df_est, cluster = ~ iso)

b <- "post2022:exportador"
cat("\n--- beta3 (interaction Post2022 x Exporter), pp of GDP ---\n")
cat("(1) 2x2 DiD  explicit:", fmt_num(coef(m1)[b], 3),
    " SE", fmt_num(se(m1)[b], 3), "| N", nobs(m1), "\n")
cat("(2) TWFE     explicit:", fmt_num(coef(m2)[b], 3),
    " SE", fmt_num(se(m2)[b], 3), "| N", nobs(m2), "\n")
cat("(3) TWFE     implicit:", fmt_num(coef(m3_impl)[b], 3),
    " SE", fmt_num(se(m3_impl)[b], 3), "| N", nobs(m3_impl), "\n")
cat("(4) TWFE     total:    ", fmt_num(coef(m3_tot)[b], 3),
    " SE", fmt_num(se(m3_tot)[b], 3), "| N", nobs(m3_tot), "\n")

# ---------------------------------------------------------------------------
# 3. Event study (dynamic model, base = 2021)
# ---------------------------------------------------------------------------

# i(anio, exportador, ref = 2021): one coef per year of the interaction, omitting
# 2021 (last pre-shock year). Country and year FE. SE clustered by country.
m_es <- feols(subsidio ~ i(anio, exportador, ref = 2021) | iso + anio,
              data = df, cluster = ~ iso)

es <- broom::tidy(m_es, conf.int = TRUE) |>
  mutate(anio = as.integer(gsub("\\D", "", term))) |>
  filter(!is.na(anio)) |>
  select(anio, estimate, conf.low, conf.high)

# Add the base point (2021 = 0 by construction) so the trajectory is continuous
es <- bind_rows(es,
  tibble(anio = 2021, estimate = 0, conf.low = 0, conf.high = 0)) |>
  arrange(anio)

cat("\n--- Event study (coef by year, base 2021 = 0) ---\n")
print(as.data.frame(es |> mutate(across(where(is.numeric), ~ round(., 3)))))

# Pre-trends test: H0 = the pre-shock coefs (2015-2020) are jointly zero.
# fixest::wald() uses df2 = N - K; with a cluster-robust VCOV the relevant
# denominator df is G - 1 (number of clusters minus one), so the F statistic is
# re-referenced to F(q, G - 1). Both versions are stored; the G - 1 one is the main.
terms_pre <- grep("201[5-9]|2020", names(coef(m_es)), value = TRUE)
w_pre <- wald(m_es, keep = terms_pre, print = FALSE)
es_n_obs      <- as.integer(nobs(m_es))
es_n_clusters <- as.integer(dplyr::n_distinct(df$iso[obs(m_es)]))
w_df1 <- as.integer(w_pre$df1)
w_df2 <- es_n_clusters - 1L
w_p   <- pf(w_pre$stat, w_df1, w_df2, lower.tail = FALSE)
cat("\n--- Pre-trends (Wald, H0: pre-shock coefs jointly = 0) ---\n")
cat("F(", w_df1, ", ", w_df2, ") = ", fmt_num(w_pre$stat, 2), " | p = ", fmt_num(w_p, 4),
    "  [fixest default: F(", w_df1, ", ", w_pre$df2, "), p = ", fmt_num(w_pre$p, 4), "]\n",
    sep = "")
cat("Pre-shock coefs:",
    paste(sprintf("%+.2f", coef(m_es)[terms_pre]), collapse = " "), "\n")
cat("Event-study N =", es_n_obs, "|", es_n_clusters, "clusters\n")

# ---------------------------------------------------------------------------
# 4. Regression table (AER style, openxlsx; coef, clustered SE and significance
#    stars based on the clustered p-value)
# ---------------------------------------------------------------------------

# Significance stars from the p-value (project convention)
estrellas <- function(p) {
  if (is.na(p))      ""
  else if (p < .001) "***"
  else if (p < .01)  "**"
  else if (p < .05)  "*"
  else if (p < .10)  "†"
  else               ""
}

# Extract coef, SE and p-value from a fixest model, indexed by term name
extraer <- function(m) {
  ct <- as.data.frame(summary(m)$coeftable)
  data.frame(var = rownames(ct), est = ct[[1]], se = ct[[2]], p = ct[[4]],
             row.names = NULL, stringsAsFactors = FALSE)
}

# "coef***" and "(se)" cells for variable v in an extracted model co
celda <- function(co, v) {
  i <- match(v, co$var)
  if (is.na(i)) return(list(coef = "", se = ""))
  list(coef = paste0(fmt_num(co$est[i], 3), estrellas(co$p[i])),   # true minus
       se   = paste0("(", fmt_num(co$se[i], 3), ")"))
}

cols_mod <- list(extraer(m1), extraer(m2), extraer(m3_impl), extraer(m3_tot))

# Row order: interaction first, then main-effect terms (only in (1)), then the
# constant. Readable label per variable.
etiqueta <- c("post2022:exportador" = "Post2022 × Net exporter",
              "post2022"            = "Post2022",
              "exportador"          = "Net exporter",
              "(Intercept)"         = "Constant")
orden_vars <- names(etiqueta)

filas <- list()
for (v in orden_vars) {
  cs <- lapply(cols_mod, celda, v = v)
  if (all(vapply(cs, function(x) x$coef == "", logical(1)))) next  # var absent
  filas[[length(filas)+1L]] <- c(etiqueta[v], vapply(cs, `[[`, "", "coef"))
  filas[[length(filas)+1L]] <- c("",          vapply(cs, `[[`, "", "se"))
}

# Bottom rows: FE, N. fixest reports nobs() per model (drops NA in impl/tot).
ef_pais <- c("Country FE", "No", "Yes", "Yes", "Yes")
ef_anio <- c("Year FE",    "No", "Yes", "Yes", "Yes")
fila_n  <- c("N (country-years)", as.character(c(nobs(m1), nobs(m2),
                                                 nobs(m3_impl), nobs(m3_tot))))

tabla_m <- as.data.frame(do.call(rbind, c(filas, list(ef_pais, ef_anio, fila_n))),
                         stringsAsFactors = FALSE)
names(tabla_m) <- c("Variable", "(1)", "(2)", "(3)", "(4)")

# Subheaders: what each column measures (DV and specification)
subhead <- c("", "Explicit\n2×2 DiD", "Explicit\nTWFE",
             "Implicit\nTWFE", "Total\nTWFE")

# Quantities quoted in the note (computed, not typed)
yr_pre      <- yr_range(min(df_est$anio), YEAR_SHOCK - 1)
yr_static   <- yr_range(min(df_est$anio), max(df_est$anio))
n_c_static  <- dplyr::n_distinct(df_est$iso[obs(m2)])
n_c_alt     <- dplyr::n_distinct(df_est$iso[obs(m3_impl)])
brent_shock <- mean(df$brent_usd[df$anio == YEAR_SHOCK], na.rm = TRUE)
brent_next  <- mean(df$brent_usd[df$anio == YEAR_SHOCK + 1], na.rm = TRUE)

tab_path <- file.path(PATH$tab, "tab3_model.xlsx")
tabla_aer(
  tabla_m,
  name        = "tab3_model.xlsx",
  titulo      = "Table 3. Effect of the 2022 shock on fossil fuel subsidies (DiD)",
  subheader   = subhead,
  ancho_datos = 14,
  notas = c(
    paste0("\u03b2\u2083 (Post2022 \u00d7 Net exporter) is the change in the subsidy of net oil ",
           "exporters between the ", yr_pre, " average and ", YEAR_SHOCK, " in excess of ",
           "the corresponding change among net oil importers (the comparison group)."),
    paste0("Dependent variable (% of GDP): explicit subsidy in columns (1)\u2013(2), ",
           "implicit in (3), and total in (4). Columns (2)\u2013(4) include country and year ",
           "fixed effects. For the implicit component, the effect is small and statistically ",
           "insignificant."),
    paste("Standard errors are clustered by country in parentheses.",
          "\u2020 p < 0.10, * p < 0.05, ** p < 0.01, *** p < 0.001."),
    paste0("Sample: ", yr_static, " (", n_c_static, " countries; ", n_c_alt,
           " in columns (3)\u2013(4)). ",
           YEAR_SHOCK + 1, ", a reversal year (Brent fell from USD ",
           fmt_num(brent_shock, 1), " to USD ", fmt_num(brent_next, 1), " per barrel), is ",
           "excluded."),
    "Source: IMF Fossil Fuel Subsidies Database; U.S. Energy Information Administration (EIA)."
  )
)
message("\nTable saved: ", tab_path)

# ---------------------------------------------------------------------------
# 5. Event study figure
# ---------------------------------------------------------------------------

# Discrete 95% CIs per year (error bars, no interpolating ribbon or line); the
# reference year 2021 is a hollow point without a CI.
es_plot <- es |> mutate(ref = anio == 2021)
fig <- ggplot(es_plot, aes(anio, estimate)) +
  geom_hline(yintercept = 0, colour = WB_SUBTLE, linewidth = 0.3) +
  geom_vline(xintercept = YEAR_SHOCK, linetype = "dashed",
             colour = WB_SUBTLE, linewidth = 0.4) +
  geom_errorbar(data = filter(es_plot, !ref),
                aes(ymin = conf.low, ymax = conf.high),
                width = 0.18, colour = WB_CAT[6], linewidth = 0.5) +
  geom_point(data = filter(es_plot, !ref), colour = WB_CAT[6], size = 2.2) +
  geom_point(data = filter(es_plot, ref), shape = 21, fill = "white",
             colour = WB_CAT[6], size = 2.4, stroke = 0.9) +
  annotate("text", x = 2021, y = 0, label = "reference\nyear", vjust = 1.5,
           family = "Times New Roman", size = 2.9, colour = WB_TEXT, lineheight = 0.9) +
  scale_x_continuous(breaks = YEARS_OBS) +
  scale_y_continuous(breaks = seq(floor(min(es$conf.low)), ceiling(max(es$conf.high)), 1),
                     labels = lab_minus) +
  labs(x = NULL, y = "Effect (pp of GDP)") +
  tema_wb_ts() +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor = element_blank())

# Countries with missing event-study observations (for the note)
es_na <- df |> filter(is.na(subsidio)) |> group_by(iso) |>
  summarise(a0 = min(anio), a1 = max(anio), n = dplyr::n(), .groups = "drop")
txt_es_na <- if (nrow(es_na) == 0) "" else paste0(
  "; ", enum_en(paste(country_en(es_na$iso),
                      ifelse(es_na$n > 1 & es_na$a1 - es_na$a0 + 1 == es_na$n,
                             yr_range(es_na$a0, es_na$a1), as.character(es_na$a0)))),
  " missing")

nota_es <- paste0(
  "Coefficients on the year \u00d7 net oil exporter interactions (percentage points of GDP), ",
  "with 2021 as the reference year (hollow point), and 95% confidence intervals from ",
  "standard errors clustered by country. The dashed line marks the ", YEAR_SHOCK, " shock. ",
  "Before ", YEAR_SHOCK, ", the coefficients fluctuate without a monotonic trend, but a joint ",
  "test rejects that all ", num_en(length(terms_pre)), " are zero (F(", w_df1, ", ", w_df2,
  ") = ", fmt_num(w_pre$stat, 2), ", ", fmt_p(w_p), "). Groups: ", num_en(n_exp),
  " net oil exporters and ", num_en(n_pais - n_exp), " net oil importers. N = ", es_n_obs,
  " country-years (", es_n_clusters, " countries, ", yr_range(min(df$anio), max(df$anio)),
  txt_es_na, ")."
)

save_fig_png(fig, "fig4_eventstudy.png", nota = nota_es,
             fuente = "IMF Fossil Fuel Subsidies Database.",
             w = 6.5, h = 4.3, dpi = 300)

# ---------------------------------------------------------------------------
# 6. Verification
# ---------------------------------------------------------------------------

delta <- abs(coef(m1)[b] - coef(m2)[b])
stopifnot(
  file.exists(tab_path),
  file.exists(file.path(PATH$fig, "fig4_eventstudy.png")),
  delta < 0.5                                   # beta3 stable between (1) and (2)
)
cat("\n--- Verification ---\n")
cat("Table and figure generated: OK\n")
cat("beta3 stable between (1) and (2): |", fmt_num(coef(m1)[b], 3), "-",
    fmt_num(coef(m2)[b], 3), "| =", fmt_num(delta, 3), "< 0.5: OK\n")
cat("VERIFICATION PASS\n")

# ---------------------------------------------------------------------------
# 7. Key results for the paper (outputs/results/06_model.rds)
# ---------------------------------------------------------------------------
# Elements:
#   did_2x2_cells    data frame: group (Net exporter/Net importer) x period
#                    (pre 2015-2021 / post 2022) mean explicit subsidy (% of GDP), n obs
#   did_2x2          list: exporter_change, importer_change, double_difference (pp of GDP)
#   twfe             data frame, one row per Table 3 column: column, model, dep_var,
#                    fixed_effects, coef, se, p_value, ci_low, ci_high, n_obs,
#                    n_countries, n_treated (beta3 = Post2022 x Net exporter)
#   event_study      data frame: year, coef, se, ci_low, ci_high (base 2021: coef 0, se NA)
#   event_study_base_year  2021
#   event_study_n_obs       integer: estimation N of the event study (nobs)
#   event_study_n_clusters  integer: number of country clusters in the event study
#   pretrend_wald    list: f_stat, df1, df2, p_value (H0: 2015-2020 coefs jointly = 0),
#                    df2 = clusters - 1 (F(6, 33) style); main version for the paper
#   pretrend_wald_fixest  list: same fields, fixest default df2 = N - K
#   sample           list: n_obs_panel, n_countries, n_exporters, n_importers,
#                    static_years, event_study_years
#   notes            character: SE clustered by country; CI are 95%

# 2x2 cell means on the same sample used by column (1)
cells <- df_est[obs(m1), ] |>
  mutate(group  = ifelse(exportador == 1, "Net exporter", "Net importer"),
         period = ifelse(post2022 == 1, "post_2022", "pre_2015_2021")) |>
  group_by(group, period) |>
  summarise(mean_subsidy = mean(subsidio, na.rm = TRUE), n_obs = dplyr::n(),
            .groups = "drop") |>
  as.data.frame()
cell <- function(g, t) cells$mean_subsidy[cells$group == g & cells$period == t]
chg_exp <- cell("Net exporter", "post_2022") - cell("Net exporter", "pre_2015_2021")
chg_imp <- cell("Net importer", "post_2022") - cell("Net importer", "pre_2015_2021")
stopifnot(abs((chg_exp - chg_imp) - coef(m1)[b]) < 1e-8)   # saturated OLS = cell means

# One row per regression column: beta3 with clustered inference
twfe_row <- function(m, column, model, dep_var, fe) {
  ci <- confint(m)[b, ]
  d  <- df_est[obs(m), ]
  data.frame(column = column, model = model, dep_var = dep_var, fixed_effects = fe,
             coef = unname(coef(m)[b]), se = unname(se(m)[b]),
             p_value = unname(pvalue(m)[b]),
             ci_low = unname(ci[[1]]), ci_high = unname(ci[[2]]),
             n_obs = nobs(m), n_countries = dplyr::n_distinct(d$iso),
             n_treated = dplyr::n_distinct(d$iso[d$exportador == 1]),
             stringsAsFactors = FALSE)
}
twfe_tab <- rbind(
  twfe_row(m1,      "(1)", "did_2x2",               "explicit", FALSE),
  twfe_row(m2,      "(2)", "twfe_explicit",         "explicit", TRUE),
  twfe_row(m3_impl, "(3)", "twfe_implicit_placebo", "implicit", TRUE),
  twfe_row(m3_tot,  "(4)", "twfe_total",            "total",    TRUE)
)

es_tab <- broom::tidy(m_es, conf.int = TRUE) |>
  mutate(year = as.integer(gsub("\\D", "", term))) |>
  filter(!is.na(year)) |>
  transmute(year, coef = estimate, se = std.error, ci_low = conf.low, ci_high = conf.high)
es_tab <- bind_rows(es_tab, tibble(year = 2021L, coef = 0, se = NA_real_,
                                   ci_low = 0, ci_high = 0)) |>
  arrange(year) |>
  as.data.frame()

res_06 <- list(
  did_2x2_cells = cells,
  did_2x2 = list(exporter_change = chg_exp, importer_change = chg_imp,
                 double_difference = chg_exp - chg_imp),
  twfe = twfe_tab,
  event_study = es_tab,
  event_study_base_year = 2021L,
  event_study_n_obs      = es_n_obs,
  event_study_n_clusters = es_n_clusters,
  pretrend_wald = list(f_stat = unname(w_pre$stat), df1 = w_df1, df2 = w_df2,
                       p_value = unname(w_p)),
  pretrend_wald_fixest = list(f_stat = unname(w_pre$stat), df1 = w_df1,
                              df2 = as.integer(w_pre$df2), p_value = unname(w_pre$p)),
  sample = list(n_obs_panel = nrow(df), n_countries = n_pais, n_exporters = n_exp,
                n_importers = n_pais - n_exp, static_years = "2015-2022",
                event_study_years = "2015-2023"),
  notes = "Units: % of GDP / pp of GDP. SE clustered by country; CI are 95%."
)
saveRDS(res_06, file.path(PATH$res, "06_model.rds"))
message("Results saved: ", file.path(PATH$res, "06_model.rds"))

cerrar_log()
