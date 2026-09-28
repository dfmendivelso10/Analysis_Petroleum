###############################################################
# 2022 oil shock - 05_fig_impact.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Figure 3. Dot plot: fiscal impact of the shock by country,
#   measured as the change in the explicit fossil fuel subsidy
#   between the pre-shock average (2015-2019, the "normal" period before
#   COVID) and the shock year (2022), in percentage points of GDP.
#   One dot per country, sorted from largest to smallest, colored by fiscal
#   exposure group. No time axis: collapses each country to its impact,
#   complementing Figure 1 (aggregate dynamics) with the cross-section
#   of the impact (who absorbed the shock the most).
#   Measured in pp of GDP rather than % change: for the fiscal discussion
#   what matters is the additional budgetary cost, not the relative change
#   (which rewards small pre-shock bases).
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs)
# Output: outputs/figures/fig3_impact.png     (PNG 300 dpi)
###############################################################

source(here::here("code/config.R"))

log_file <- iniciar_log("05_fig_impact")

# ---------------------------------------------------------------------------
# 1. Load and check
# ---------------------------------------------------------------------------

df <- cargar_panel_anio()
stopifnot(nrow(df) == 306)

# ---------------------------------------------------------------------------
# 2. Definitions (labels) and data
# ---------------------------------------------------------------------------

labels_vars <- c(
  "Subsidio explicito: brecha entre el precio al consumidor y el costo de suministro, como % del PIB",
  "Impacto del choque: subsidio en 2022 menos el promedio pre-choque (2015-2019), en puntos del PIB",
  "Periodo pre-choque 2015-2019: excluye 2020-2021 (valle y rebote de la pandemia)",
  "Exportador neto: el alza del Brent infla la renta petrolera que financia el subsidio",
  "Importador neto: el alza del Brent encarece el costo de suministro y agrava el gasto"
)

# Change in the explicit subsidy (pp of GDP): 2022 vs pre-shock average.
# Pre = 2015-2019 ("normal" period, excludes the 2020-21 COVID distortion).
# Keeps countries with subsidy > 0.05% of GDP in some year of the period.
PISO <- 0.05  # % of GDP

dat <- df |>
  group_by(iso, exportador_neto) |>
  summarise(
    pre  = mean(expl_pctgdp[anio >= 2015 & anio <= 2019] * 100, na.rm = TRUE),
    y22  = expl_pctgdp[anio == 2022][1] * 100,
    maxv = max(expl_pctgdp * 100, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(maxv > PISO) |>
  mutate(
    cambio = y22 - pre,
    grupo  = ifelse(exportador_neto, "Exportador neto", "Importador neto"),
    pais   = pais_es(iso),
    subio  = cambio >= 0
  ) |>
  arrange(cambio) |>
  mutate(pais = factor(pais, levels = pais))

n_pais  <- nrow(dat)
n_exp   <- sum(dat$exportador_neto)
n_imp   <- n_pais - n_exp
n_subio <- sum(dat$subio)
message("Countries (> ", PISO, "% GDP): ", n_pais,
        " | increased: ", n_subio, " | decreased: ", n_pais - n_subio)
message("Largest impact: ",
        paste(utils::head(rev(as.character(dat$pais)), 4), collapse = ", "))

# ---------------------------------------------------------------------------
# 3. Figure helpers
# ---------------------------------------------------------------------------

# Value annotated next to each point (pp of GDP, explicit sign).
dat <- dat |>
  mutate(lbl = paste0(ifelse(cambio >= 0, "+", "−"),
                      formatC(abs(cambio), format = "f", digits = 2)),
         hj  = ifelse(cambio >= 0, -0.25, 1.25))

# ---------------------------------------------------------------------------
# 4. Figure (dot plot)
# ---------------------------------------------------------------------------

fig <- ggplot(dat, aes(x = cambio, y = pais, colour = grupo)) +
  geom_vline(xintercept = 0, colour = WB_TEXT, linewidth = 0.4) +
  # Stem from the point to the zero line
  geom_segment(aes(x = 0, xend = cambio, y = pais, yend = pais),
               linewidth = 0.35, alpha = 0.5) +
  geom_point(size = 2.4) +
  geom_text(aes(label = lbl, hjust = hj), family = "Times New Roman",
            size = 2.4, colour = WB_TEXT) +
  scale_x_continuous(
    breaks = scales::breaks_pretty(6),
    labels = function(x) paste0(ifelse(x > 0, "+", ""),
                                formatC(x, format = "fg")),
    expand = expansion(mult = c(0.08, 0.10))
  ) +
  scale_colour_manual(values = COLORES_EXPOSICION,
                      guide = guide_legend(reverse = TRUE)) +
  labs(x = "Cambio del subsidio explícito (pp del PIB, 2022 vs. promedio 2015–2019)",
       y = NULL, colour = NULL) +
  tema_wb_ts() +
  theme(
    panel.grid.major.y = element_blank(),   # no horizontal gridlines per country
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.text.y        = element_text(size = 7.5, family = "Times New Roman"),
    axis.text.x        = element_text(size = 8),
    legend.position    = "bottom"
  )

# ---------------------------------------------------------------------------
# 5. Note and save
# ---------------------------------------------------------------------------

nota <- paste0(
  "Impacto fiscal del choque por pais: cambio del subsidio explicito a combustibles fosiles ",
  "(puntos porcentuales del PIB) entre el promedio del periodo pre-choque (2015-2019) y el ",
  "ano del choque (2022). Valores positivos indican mayor costo fiscal con el choque ",
  "(", n_subio, " de ", n_pais, " paises), negativos una reduccion. ",
  "El periodo base es 2015-2019, el ultimo tramo de comportamiento normal del subsidio antes ",
  "de la pandemia. Se excluyen 2020 (caida de demanda y precios) y 2021 (rebote de recuperacion) ",
  "porque reflejan la perturbacion de la COVID-19 y no el regimen habitual de la politica de ",
  "subsidios, de modo que tomarlos como base contaminaria la medida del choque con ruido pandemico. ",
  "La Figura 1 si muestra 2020-2021 como parte de la trayectoria completa (contexto temporal); ",
  "aqui no se usan como linea base (contrafactual): mostrar el periodo no equivale a usarlo como ",
  "referencia de comparacion. Se mide en puntos del PIB y no en variacion porcentual, porque ",
  "para la discusion fiscal importa el costo presupuestal adicional y no el cambio relativo, ",
  "que sobreponderaria a paises con un subsidio pre-choque muy pequeno. ",
  "La medida es descriptiva, no una estimacion causal del efecto del choque: cuantifica el ",
  "cambio observado entre ambos momentos, no aisla la contribucion del precio del petroleo ",
  "frente a otros factores. El conjunto de paises de mayor impacto es robusto, aunque el orden ",
  "preciso entre ellos es sensible a la definicion del periodo base. ",
  "Se incluyen los paises con subsidio explicito superior a ", PISO, "% del PIB en algun ano; ",
  "la Tabla 2 reporta el detalle por ano. ",
  "Variables: ", paste(labels_vars, collapse = ". "), ". ",
  "Clasificacion por exposicion fiscal neta: exportadores netos (N = ", n_exp,
  ") e importadores netos (N = ", n_imp, "). N = ", n_pais, " paises."
)

save_fig_png(fig, "fig3_impact.png", nota = nota,
             fuente = "IMF Fossil Fuel Subsidies Database.",
             w = 7, h = 9, dpi = 300)

# ---------------------------------------------------------------------------
# 6. Verification
# ---------------------------------------------------------------------------

out <- file.path(PATH$fig, "fig3_impact.png")
stopifnot(file.exists(out), file.info(out)$size > 50000)
message("\nVERIFICATION PASS: ", out, " (",
        round(file.info(out)$size / 1024, 1), " KB)")

cerrar_log()
