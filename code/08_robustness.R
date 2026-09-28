###############################################################
# 2022 oil shock - 08_robustness.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Robustness of the main effect (beta3, 06_model.R) to extreme countries.
#   The main sample (34 countries) is NOT changed: it is the pre-registered
#   specification. Here the TWFE is re-estimated dropping the outliers by hand
#   to show that the effect survives in sign and order of magnitude:
#     (1) full sample (replicates Table 4)
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
# Output: outputs/tables/tab6_robustness.xlsx
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

# Main TWFE (same as column (2) of Table 4). post2022 is equivalent to the 2022
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
pais_min <- pais_es(exps[which.min(loo)])

cat("\n--- Leave-one-out exporters (", length(exps), ") ---\n")
for (i in seq_along(exps))
  cat(sprintf("  w/o %-4s (%-18s) beta3 = %s\n",
              exps[i], pais_es(exps[i]), fmt_num(loo[i], 3)))
cat(sprintf("LOO range: [%s, %s] | minimum when dropping %s\n",
            fmt_num(loo_min, 2), fmt_num(loo_max, 2), pais_min))

# ---------------------------------------------------------------------------
# 4. Table 6 (AER style) — helpers identical to 06_model.R
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
fila_coef <- c("Post2022 × Exportador neto", vapply(cs, `[[`, "", "coef"))
fila_se   <- c("",                           vapply(cs, `[[`, "", "se"))
ef_pais   <- c("Efectos fijos de país", rep("Sí", length(mods)))
ef_anio   <- c("Efectos fijos de año",  rep("Sí", length(mods)))
fila_n    <- c("N (país-año)", vapply(mods, function(m) as.character(nobs(m)), ""))

tabla6 <- as.data.frame(
  rbind(fila_coef, fila_se, ef_pais, ef_anio, fila_n),
  stringsAsFactors = FALSE
)
names(tabla6) <- c("Variable", "(1)", "(2)", "(3)", "(4)")

subhead <- c("", "Muestra\ncompleta", "Sin\nVenezuela",
             "Sin\nSurinam", "Sin\nambos")

# Maximum subsidy of VEN and SUR (2022), to avoid hardcoding it in the note
ven_max <- fmt_num(max(df_est$subsidio[df_est$iso == "VEN"], na.rm = TRUE), 1)
sur_max <- fmt_num(max(df_est$subsidio[df_est$iso == "SUR"], na.rm = TRUE), 1)

tab_path <- file.path(PATH$tab, "tab6_robustness.xlsx")
tabla_aer(
  tabla6,
  name        = "tab6_robustness.xlsx",
  titulo      = "Tabla 6. Robustez del efecto del choque a países extremos",
  subheader   = subhead,
  ancho_datos = 13,
  notas = c(
    paste("Chequeo de sensibilidad del coeficiente principal (β₃, Post2022 × Exportador neto)",
          "a la exclusión de los países con subsidio más extremo. Todas las columnas son la",
          "misma especificación TWFE de la Tabla 4 (efectos fijos de país y de año, errores",
          "estándar agrupados por país); solo cambia la muestra."),
    paste0("La columna (1) es la muestra completa pre-registrada (34 países) y reproduce la ",
           "Tabla 4. Las columnas (2)-(4) la re-estiman quitando a Venezuela (el exportador con ",
           "el subsidio más alto, ", ven_max, "% del PIB), a Surinam (el importador con el subsidio ",
           "más alto, ", sur_max, "% del PIB, que pesa en el grupo de control) y a ambos. El efecto se ",
           "mantiene positivo en todas: el choque no lo carga un país aislado. Quitar a Venezuela lo ",
           "reduce (de ", fmt_num(coef(m1)[b], 2), " a ", fmt_num(coef(m2)[b], 2), ") porque amplifica el ",
           "efecto, pero no lo crea; quitar a Surinam lo aumenta (", fmt_num(coef(m3)[b], 2),
           ") porque despeja el grupo de control de un subsidiador atípico."),
    paste0("Como prueba sistemática, al re-estimar β₃ excluyendo cada exportador por separado ",
           "(leave-one-out de los ", length(exps), " exportadores) la estimación puntual queda en el ",
           "rango [", fmt_num(loo_min, 2), ", ", fmt_num(loo_max, 2), "], siempre positiva; el valor más ",
           "bajo corresponde a la exclusión de ", pais_min, ". Es el rango de coeficientes, no un ",
           "intervalo de confianza."),
    paste("Entre paréntesis, los errores estándar agrupados por país.",
          "† p < 0.10, * p < 0.05, ** p < 0.01, *** p < 0.001."),
    "Fuente: IMF Fossil Fuel Subsidies Database; precio Brent: U.S. Energy Information Administration."
  )
)

# ---------------------------------------------------------------------------
# 5. Verification
# ---------------------------------------------------------------------------

stopifnot(
  file.exists(tab_path),
  abs(coef(m1)[b] - 1.790) < 0.05,        # col (1) replicates Table 4
  all(loo > 0),                            # effect positive across the whole LOO
  nobs(m1) == 269
)
cat("\n--- Verification ---\n")
cat("Table generated: OK\n")
cat("Column (1) replicates Table 4 (beta3 = 1.79): OK\n")
cat("Leave-one-out always positive [", fmt_num(loo_min, 2), ",",
    fmt_num(loo_max, 2), "]: OK\n")
cat("VERIFICATION PASS\n")

cerrar_log()
