###############################################################
# 2022 oil shock - 07_fiscal_analysis.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Fiscal implications of the shock and policy recommendation. Takes the effect
#   already estimated in 06_model.R (beta3 = +1.79 pp of GDP for net exporters)
#   and crosses it with each country's fiscal space to turn the coefficient into
#   an actionable recommendation. Nothing is re-estimated: this is
#   post-estimation. WEO fiscal variables (debt, balance) are used here, not in
#   the model (they would be "bad controls": a consequence of the subsidy, not
#   a cause).
#
#   Figure 5: policy matrix. Explicit subsidy (% of GDP, X axis) against public
#     debt (% of GDP, Y axis), 2022 cross-section; colour by exposure group;
#     size = increase in the subsidy in USD bn between 2021 and 2022. The medians
#     split the plane into four quadrants (urgent / gradual reform / etc.).
#   Table 5: country-level backup (subsidy, observed change, cost attributable to
#     the shock via beta3, debt, fiscal balance, quadrant), one panel per group.
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs)
# Output: outputs/figures/fig5_fiscal_matrix.png  (PNG 300 dpi)
#         outputs/tables/tab5_fiscal.xlsx         (AER table)
# N matrix: 26 countries with explicit subsidy > 0.05% of GDP in 2022
#           (7 net exporters, 19 importers)
###############################################################

source(here::here("code/config.R"))

log_file <- iniciar_log("07_fiscal_analysis")

# ---------------------------------------------------------------------------
# 1. Load, check and parameters
# ---------------------------------------------------------------------------

df <- cargar_panel_anio()
stopifnot(nrow(df) == 306)

# Average model effect (06_model.R, explicit TWFE): the shock raises the explicit
# subsidy by 1.79 pp of GDP in net exporters. It is the AVERAGE effect, not
# country-specific; here it is used only to size the cost.
BETA3 <- 0.0179        # share of GDP (1.79 pp)
PISO  <- 0.05          # % of GDP: subsidy floor to enter the figure

# ---------------------------------------------------------------------------
# 2. Data: 2022 cross-section, subsidy vs fiscal space
# ---------------------------------------------------------------------------

# Observed 2021->2022 change (raw, not causal) in pp of GDP and in USD bn, and
# levels of subsidy, debt and balance in the shock year.
dat <- df |>
  filter(anio %in% c(2021, YEAR_SHOCK)) |>
  group_by(iso, exportador_neto) |>
  summarise(
    subsidio  = expl_pctgdp[anio == YEAR_SHOCK][1] * 100,            # % GDP
    cambio_pp = (expl_pctgdp[anio == YEAR_SHOCK][1] -
                 expl_pctgdp[anio == 2021][1]) * 100,                # pp GDP
    cambio_usd = expl_total[anio == YEAR_SHOCK][1] -
                 expl_total[anio == 2021][1],                        # USD bn
    deuda     = deuda_publica[anio == YEAR_SHOCK][1],                # % GDP
    balance   = balance_fiscal[anio == YEAR_SHOCK][1],               # % GDP
    gdp       = gdp[anio == YEAR_SHOCK][1],                          # USD bn
    .groups = "drop"
  ) |>
  filter(subsidio > PISO) |>
  mutate(
    grupo      = ifelse(exportador_neto, "Exportador neto", "Importador neto"),
    pais       = pais_es(iso),
    # Cost attributable to the shock (1.79% of GDP). Only for exporters whose
    # subsidy actually ROSE with the shock: beta3 values a price increase, so
    # applying it to an exporter that cut its subsidy (Guyana, observed change
    # < 0) would contradict its own data. NA in that case and for importers.
    costo_beta = ifelse(exportador_neto & cambio_pp > 0, BETA3 * gdp, NA_real_)
  )

# gdp in USD bn (mit.gdp.pre.lvl.1): LATAM range ~0.7 (DMA) to ~1500 (MEX).
# If a data refresh changes the scale, costo_beta would be off by 1000x.
stopifnot(all(dat$gdp > 0.1 & dat$gdp < 5000))
# Point size is cambio_usd; an NA would leave it without a bubble (invisible).
if (anyNA(dat$cambio_usd))
  warning(sum(is.na(dat$cambio_usd)), " country(ies) without cambio_usd: point has no size")

# Medians: matrix cut-offs (relative to the sample, not absolute thresholds)
med_sub <- median(dat$subsidio)
med_deu <- median(dat$deuda)

n_pais <- nrow(dat)
n_exp  <- sum(dat$exportador_neto)
n_imp  <- n_pais - n_exp

cat("Countries in the matrix:", n_pais, "(", n_exp, "exporters,", n_imp, "importers)\n")
cat("Cut-offs: median subsidy =", fmt_num(med_sub, 2), "% GDP |",
    "median debt =", fmt_num(med_deu, 1), "% GDP\n")

# Policy quadrant for each country
dat <- dat |>
  mutate(cuadrante = dplyr::case_when(
    subsidio >= med_sub & deuda >= med_deu ~ "Reforma urgente",
    subsidio >= med_sub & deuda <  med_deu ~ "Reforma gradual",
    subsidio <  med_sub & deuda >= med_deu ~ "Vigilar",
    TRUE                                   ~ "Sin presión"
  ))

cat("\n--- Quadrant 'Reforma urgente' (high subsidy and high debt) ---\n")
urg <- dat |> filter(cuadrante == "Reforma urgente") |> arrange(desc(subsidio))
for (i in seq_len(nrow(urg))) cat(sprintf("  %-20s subsidy %.1f | debt %.1f | balance %+.1f\n",
    urg$pais[i], urg$subsidio[i], urg$deuda[i], urg$balance[i]))

# ---------------------------------------------------------------------------
# 3. Figure 5: policy matrix (subsidy x debt)
# ---------------------------------------------------------------------------

# Quadrant labels, anchored to the four corners of the plane (outside the point
# cloud): top/bottom at the actual data ceiling/floor, right at the extreme and
# left at the edge, so they line up and do not collide with countries.
lim_x  <- max(dat$subsidio) * 1.08
techo  <- max(dat$deuda) * 1.05
piso   <- min(dat$deuda) - (max(dat$deuda) - min(dat$deuda)) * 0.04
borde_izq <- min(dat$subsidio) * 0.5
etq <- tibble::tibble(
  x   = c(lim_x, borde_izq, lim_x, borde_izq),
  y   = c(techo, techo, piso, piso),
  txt = c("Reforma urgente", "Vigilar", "Reforma gradual", "Sin presión"),
  hj  = c(1, 0, 1, 0),
  vj  = c(1, 1, 0, 0)
)

fig <- ggplot(dat, aes(subsidio, deuda)) +
  geom_hline(yintercept = med_deu, colour = WB_SUBTLE,
             linetype = "dashed", linewidth = 0.35) +
  geom_vline(xintercept = med_sub, colour = WB_SUBTLE,
             linetype = "dashed", linewidth = 0.35) +
  geom_text(data = etq, aes(x, y, label = txt, hjust = hj, vjust = vj),
            inherit.aes = FALSE, family = "Times New Roman",
            fontface = "italic", size = 2.8, colour = WB_SUBTLE) +
  geom_point(aes(colour = grupo, size = cambio_usd), alpha = 0.75) +
  ggrepel::geom_text_repel(aes(label = pais, colour = grupo),
                           family = "Times New Roman", size = 2.6,
                           seed = 42, max.overlaps = Inf,
                           force = 4, force_pull = 0.4,
                           box.padding = 0.45, point.padding = 0.25,
                           min.segment.length = 0, segment.size = 0.25,
                           segment.colour = WB_SUBTLE, show.legend = FALSE) +
  scale_x_continuous(breaks = scales::breaks_pretty(6),
                     expand = expansion(mult = c(0.06, 0.10))) +
  scale_y_continuous(breaks = scales::breaks_pretty(6),
                     expand = expansion(mult = c(0.06, 0.08))) +
  scale_colour_manual(values = COLORES_EXPOSICION,
                      guide = guide_legend(reverse = TRUE, order = 1)) +
  scale_size_area(max_size = 6, breaks = c(1, 3, 5, 10),
                  labels = function(b) paste0(b, " mil mill. USD")) +
  labs(x = "Subsidio explícito en 2022 (% del PIB)",
       y = "Deuda pública en 2022 (% del PIB)",
       colour = NULL,
       size = "Aumento del subsidio\nentre 2021 y 2022") +
  tema_wb_base() +
  theme(legend.position = "right",
        legend.box = "vertical",
        panel.grid = element_blank())   # no grid: the quadrants are the reference

# ---------------------------------------------------------------------------
# 4. Figure note and saving
# ---------------------------------------------------------------------------

nota_fig <- paste0(
  "Cada punto es un país con subsidio explícito superior a ", PISO, "% del PIB en 2022 (",
  n_pais, " países: ", n_exp, " exportadores netos y ", n_imp, " importadores). El eje horizontal ",
  "mide el peso del subsidio explícito y el vertical la deuda pública bruta, ambos como porcentaje ",
  "del PIB en 2022 (FMI, World Economic Outlook); el tamaño del punto es el aumento del subsidio en ",
  "dólares (miles de millones) entre 2021 y 2022. Las líneas discontinuas marcan la mediana de subsidio (",
  fmt_num(med_sub, 2), "% del PIB) y de deuda (", fmt_num(med_deu, 1), "% del PIB) de esta muestra, ",
  "que parten el plano en cuatro cuadrantes de política: arriba a la derecha (subsidio alto y deuda ",
  "alta) están los países donde la reforma es más urgente, porque el choque encarece un subsidio que ",
  "ya pesa y el margen fiscal para sostenerlo es estrecho; abajo a la derecha, los que subsidian caro ",
  "pero con deuda baja pueden permitirse una transición gradual. El choque de 2022 elevó el subsidio ",
  "explícito de los exportadores netos en torno a 1.8 puntos del PIB (efecto medio estimado en la ",
  "Tabla 4; robusto en signo y magnitud, en un rango de 1.1 a 2.2 puntos al excluir cualquier país, ",
  "Tabla 6), lo que desplaza a varios de ellos hacia la derecha del plano. La deuda y la posición ",
  "fiscal no entran en el modelo del efecto (serían consecuencia del subsidio, no causa) y se usan ",
  "aquí solo para situar ese efecto en el espacio fiscal de cada país. El nivel del subsidio no es ",
  "exclusivo de los exportadores: importadores como Surinam o Argentina aparecen entre los más ",
  "expuestos, de modo que el choque agravó una presión que ya existía."
)

save_fig_png(fig, "fig5_fiscal_matrix.png", nota = nota_fig,
             fuente = "IMF Fossil Fuel Subsidies Database; FMI, World Economic Outlook.",
             w = 8, h = 6.5, dpi = 300)

# ---------------------------------------------------------------------------
# 5. Table 5: country-level backup (one panel per group)
# ---------------------------------------------------------------------------

# One row per country; "n.a." for the beta3 cost of importers (not applicable)
fila_pais <- function(d) {
  data.frame(
    Variable = paste0("  ", d$pais),
    subs     = fmt_num(d$subsidio, 2),
    camb_pp  = paste0(ifelse(d$cambio_pp >= 0, "+", "−"), fmt_num(abs(d$cambio_pp), 2)),
    costo    = ifelse(is.na(d$costo_beta), "n.a.", fmt_num(d$costo_beta, 2)),
    deuda    = fmt_num(d$deuda, 1),
    balance  = paste0(ifelse(d$balance >= 0, "+", "−"), fmt_num(abs(d$balance), 1)),
    cuad     = d$cuadrante,
    stringsAsFactors = FALSE
  )
}

# Panel label row and N row (tabla_aer detects them by their prefix)
fila_lbl <- function(txt) data.frame(Variable = txt, subs = "", camb_pp = "",
                                     costo = "", deuda = "", balance = "", cuad = "")
fila_n   <- function(d) data.frame(Variable = "  N (países)",
                                   subs = as.character(nrow(d)), camb_pp = "",
                                   costo = "", deuda = "", balance = "", cuad = "")

bloque <- function(etiqueta, d) {
  d <- d[order(-d$subsidio), ]
  do.call(rbind, c(list(fila_lbl(etiqueta)),
                   lapply(seq_len(nrow(d)), function(i) fila_pais(d[i, ])),
                   list(fila_n(d))))
}

tabla5 <- rbind(
  bloque("Panel A. Exportadores netos", dat[dat$exportador_neto, ]),
  bloque("Panel B. Importadores netos", dat[!dat$exportador_neto, ])
)
names(tabla5) <- c("País", "Subsidio\n(% PIB)", "Cambio\n2021-22 (pp)",
                   "Costo choque\n(USD mil mill.)", "Deuda\n(% PIB)",
                   "Balance\n(% PIB)", "Cuadrante")

tab_path <- file.path(PATH$tab, "tab5_fiscal.xlsx")
tabla_aer(
  tabla5,
  name        = "tab5_fiscal.xlsx",
  titulo      = "Tabla 5. Subsidio, costo del choque y espacio fiscal por país (2022)",
  ancho_datos = 13,
  landscape   = TRUE,
  notas = c(
    paste("Situación fiscal de cada país con subsidio explícito relevante en 2022, ordenada",
          "por el peso del subsidio dentro de cada grupo. Sirve de respaldo a la matriz de la",
          "Figura 5: cruza cuánto pesa el subsidio con cuánto margen fiscal hay para sostenerlo."),
    paste("Subsidio: subsidio explícito a combustibles fósiles como porcentaje del PIB en 2022.",
          "Cambio 2021 a 2022: variación observada del subsidio de cada país entre ambos años (puntos",
          "del PIB), una medida bruta, no causal, que sí difiere entre países. Costo del choque: el",
          "efecto medio estimado para el grupo (1.79 puntos del PIB, Tabla 4) aplicado por igual al PIB",
          "de cada exportador, en miles de millones de dólares; es una valoración contrafactual del",
          "costo (cuánto representaría ese efecto promedio para cada economía), no el costo observado",
          "país por país, que es heterogéneo y se lee en la columna de cambio. Solo aplica a los",
          "exportadores netos, que es donde el modelo identifica el efecto diferencial; figura como n.a.",
          "en los importadores y en el único exportador cuyo subsidio no subió con el choque (Guyana),",
          "porque valorar un encarecimiento promedio sobre quien lo redujo contradiría su propio dato.",
          "Deuda: deuda pública bruta (% PIB). Balance: resultado fiscal del gobierno general",
          "(% PIB; signo negativo es déficit)."),
    paste0("Cuadrante: posición en la Figura 5 según las medianas de subsidio (",
           fmt_num(med_sub, 2), "% del PIB) y deuda (", fmt_num(med_deu, 1),
           "% del PIB) de la muestra. Reforma urgente reúne a los países por encima de ambas medianas;",
           " sin presión, a los que están por debajo de ambas."),
    paste("Las variables fiscales (deuda, balance) provienen del WEO del FMI y no entran en el",
          "modelo del efecto: se usan ex post para interpretar, no como controles."),
    "Fuente: IMF Fossil Fuel Subsidies Database; FMI, World Economic Outlook."
  )
)
message("\nTabla guardada: ", tab_path)

# ---------------------------------------------------------------------------
# 6. Verification
# ---------------------------------------------------------------------------

fig_path <- file.path(PATH$fig, "fig5_fiscal_matrix.png")
# Colombia's beta3 cost must reproduce 0.0179 * its GDP (~6.8 USD bn)
costo_col <- dat$costo_beta[dat$iso == "COL"]
stopifnot(
  file.exists(fig_path), file.info(fig_path)$size > 50000,
  file.exists(tab_path),
  n_pais == 26, n_exp == 7,
  abs(costo_col - 0.0179 * dat$gdp[dat$iso == "COL"]) < 1e-6
)
cat("\n--- Verification ---\n")
cat("Figure and table generated: OK\n")
cat("Exporters in the matrix:", n_exp, "(expected 7): OK\n")
cat("Shock cost Colombia:", fmt_num(costo_col, 2), "USD bn (= 1.79% x GDP): OK\n")
cat("VERIFICATION PASS\n")

cerrar_log()
