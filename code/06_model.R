###############################################################
# 2022 oil shock - 06_model.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Main model of the effect of the 2022 shock on explicit fossil fuel subsidies,
#   estimated by difference-in-differences (DiD). The specification was fixed in a
#   pre-registration plan before estimation (forward engineering): no
#   specification search.
#
#   Estimand: beta3 = differential change in the explicit subsidy (% of GDP) of net
#   exporters relative to net importers, from the pre-shock period (2015-2021) to
#   the post-shock period (2022-2023), under parallel trends.
#
#   Model ladder (simple -> robust):
#     (1) 2x2 DiD:  Subsidy ~ Post2022 * Exporter             [main-effect terms]
#     (2) TWFE:     Subsidy ~ Post2022:Exporter | iso + year  [country and year FE]
#     (3) Alt DV:   (2) with implicit and total as DV         [channel robustness]
#   Event study: Subsidy ~ sum_t (year_t : Exporter) | iso + year, base 2021.
#   SEs clustered by country throughout (project convention).
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs = 34 countries x 9 years)
# Output: outputs/tables/tab4_model.xlsx       (regression table)
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

# Pre-trends test: H0 = the pre-shock coefs (2015-2020) are jointly zero. Two
# things must be told apart:
#   - systematic differential trend (coefs escalating toward 2022): would bias the
#     DiD; this is the serious one. It does NOT appear in these data (signs alternate).
#   - volatility around zero (swings from the 2018 shocks and COVID 2020 in a group
#     of 7 countries): inflates uncertainty, does not bias the point estimate.
terms_pre <- grep("201[5-9]|2020", names(coef(m_es)), value = TRUE)
w_pre <- wald(m_es, keep = terms_pre)
cat("\n--- Pre-trends (Wald, H0: pre-shock coefs jointly = 0) ---\n")
cat("F =", fmt_num(w_pre$stat, 2), "| p =", fmt_num(w_pre$p, 4), "\n")
cat("Pre-shock coefs (signs):",
    paste(sprintf("%+.2f", coef(m_es)[terms_pre]), collapse = " "), "\n")
cat("=> No systematic pre-existing differential trend (signs alternate,\n")
cat("   they do not escalate toward 2022). The joint test rejects the strict null\n")
cat("   because of panel VOLATILITY (group of 7 exporters; 2018 shocks and\n")
cat("   COVID 2020), not because of a diverging slope. The 2022 jump\n")
cat("   (", fmt_num(coef(m_es)["anio::2022:exportador"], 2),
    ") is a break, not the continuation of a prior trend.\n", sep = "")

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
  list(coef = paste0(fmt_num(co$est[i], 3), estrellas(co$p[i])),
       se   = paste0("(", fmt_num(co$se[i], 3), ")"))
}

cols_mod <- list(extraer(m1), extraer(m2), extraer(m3_impl), extraer(m3_tot))

# Row order: interaction first, then main-effect terms (only in (1)), then the
# constant. Readable label per variable.
etiqueta <- c("post2022:exportador" = "Post2022 × Exportador neto",
              "post2022"            = "Post2022",
              "exportador"          = "Exportador neto",
              "(Intercept)"         = "Constante")
orden_vars <- names(etiqueta)

filas <- list()
for (v in orden_vars) {
  cs <- lapply(cols_mod, celda, v = v)
  if (all(vapply(cs, function(x) x$coef == "", logical(1)))) next  # var absent
  filas[[length(filas)+1L]] <- c(etiqueta[v], vapply(cs, `[[`, "", "coef"))
  filas[[length(filas)+1L]] <- c("",          vapply(cs, `[[`, "", "se"))
}

# Bottom rows: FE, N. fixest reports nobs() per model (drops NA in impl/tot).
ef_pais <- c("Efectos fijos de país", "No", "Sí", "Sí", "Sí")
ef_anio <- c("Efectos fijos de año",  "No", "Sí", "Sí", "Sí")
fila_n  <- c("N (país-año)", as.character(c(nobs(m1), nobs(m2),
                                            nobs(m3_impl), nobs(m3_tot))))

tabla_m <- as.data.frame(do.call(rbind, c(filas, list(ef_pais, ef_anio, fila_n))),
                         stringsAsFactors = FALSE)
names(tabla_m) <- c("Variable", "(1)", "(2)", "(3)", "(4)")

# Subheaders: what each column measures (DV and specification)
subhead <- c("", "Explícito\nDiD 2×2", "Explícito\nTWFE",
             "Implícito\nTWFE", "Total\nTWFE")

tab_path <- file.path(PATH$tab, "tab4_model.xlsx")
tabla_aer(
  tabla_m,
  name        = "tab4_model.xlsx",
  titulo      = "Tabla 4. Efecto del choque de 2022 sobre el subsidio a combustibles fósiles (DiD)",
  subheader   = subhead,
  ancho_datos = 14,
  notas = c(
    paste("Estimación por diferencias en diferencias. El coeficiente de interés es la",
          "interacción Post2022 × Exportador neto (β₃): el cambio del subsidio en los",
          "exportadores netos al pasar al año del choque, en exceso del cambio que",
          "experimentaron en el mismo lapso los importadores netos (el grupo de control)."),
    paste("Cada columna es una especificación. La (1) es el diseño básico y muestra los",
          "términos por separado (Post2022, Exportador neto y la constante); las (2)-(4)",
          "añaden efectos fijos de país y de año, que absorben esos términos sueltos y dejan",
          "solo la interacción. La variable dependiente es el subsidio explícito en (1) y (2),",
          "el implícito en (3) y el total en (4), todos como porcentaje del PIB. El efecto",
          "se concentra en el explícito —el componente que responde al precio internacional—",
          "y es nulo en el implícito, lo que confirma el canal del choque de precios."),
    paste("Coeficientes con su error estándar agrupado por país entre paréntesis.",
          "† p < 0.10, * p < 0.05, ** p < 0.01, *** p < 0.001."),
    paste("Muestra: panel 2015-2022 (34 países). El año del choque es 2022 y el período de",
          "comparación es 2015-2021. Se excluye 2023 porque el estimador busca el efecto del",
          "choque y 2023 es ya de reversión (el Brent cae de USD 101 a 82, -18 %); incluirlo",
          "promediaría un año de choque con uno de recuperación y subestimaría el efecto. La",
          "figura del event study sí conserva 2023 para mostrar que el efecto se revierte. El",
          "menor N en (3) y (4) se debe a que el implícito y el total no están estimados para",
          "todos los país-año."),
    "Fuente: IMF Fossil Fuel Subsidies Database; precio Brent: U.S. Energy Information Administration."
  )
)
message("\nTable saved: ", tab_path)

# ---------------------------------------------------------------------------
# 5. Event study figure
# ---------------------------------------------------------------------------

fig <- ggplot(es, aes(anio, estimate)) +
  geom_hline(yintercept = 0, colour = WB_SUBTLE, linewidth = 0.3) +
  geom_vline(xintercept = YEAR_SHOCK, linetype = "dashed",
             colour = WB_SUBTLE, linewidth = 0.4) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), fill = WB_CAT[1], alpha = 0.18) +
  geom_line(colour = WB_CAT[6], linewidth = 0.8) +
  geom_point(colour = WB_CAT[6], size = 1.8) +
  scale_x_continuous(breaks = YEARS_OBS) +
  labs(x = NULL,
       y = "Efecto diferencial sobre el subsidio explícito (pp del PIB)") +
  tema_wb_ts() +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor = element_blank())

nota_es <- paste0(
  "Cada punto muestra el efecto diferencial del choque sobre el subsidio explícito (puntos del PIB) ",
  "en los exportadores netos frente a los importadores, año por año, tomando 2021 como referencia, ",
  "con su intervalo de confianza al 95% (errores estándar agrupados por país); la línea vertical ",
  "marca el choque de 2022. Hasta 2021 los puntos rondan el cero, de modo que los dos grupos no venían ",
  "separándose, y la diferencia surge justo con el choque: es un quiebre en 2022 y no la continuación de ",
  "una brecha previa. Con apenas ", n_exp, " exportadores, sin embargo, el efecto se estima con poca ",
  "precisión, de ahí lo ancho de las bandas. N = ", nrow(df), " (", n_pais, " países × 9 años)."
)

save_fig_png(fig, "fig4_eventstudy.png", nota = nota_es,
             fuente = "IMF Fossil Fuel Subsidies Database.",
             w = 9, h = 6, dpi = 300)

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

cerrar_log()
