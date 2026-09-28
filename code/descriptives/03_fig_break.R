###############################################################
# 2022 oil shock - 03_fig_break.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Figure of the 2022 shock break in the explicit fossil fuel subsidy
#   in LATAM (2015-2023). 2x2 grid (in color, World Bank
#   palette):
#     (a) Total LATAM, USD billions         -> size of the shock
#     (b) By exposure group, USD bn         -> who drives it
#     (c) Total LATAM, % of GDP             -> aggregate fiscal effort
#     (d) By group, % of GDP                -> fiscal effort by group
#   The shock year (2022) is shaded and 2021-2022 values are annotated
#   above the points. The footnote is composed INSIDE the PNG (via magick,
#   AER/PACES style) and includes the definition of each variable.
#
#   Pattern: series and plot helpers defined above; inline figure below.
#   PNG output at 300 dpi (embeddable in LaTeX) with the note attached below.
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs = 34 countries x 9 years)
# Output: outputs/figures/fig1_break.png     (PNG 300 dpi, note included)
###############################################################

source(here::here("code/config.R"))
suppressMessages(library(ggrepel))

log_file <- iniciar_log("03_fig_break")

# ---------------------------------------------------------------------------
# 1. Load and check
# ---------------------------------------------------------------------------

df <- cargar_panel_anio()
stopifnot(nrow(df) == 306)                       # 34 countries x 9 years
n_pais <- dplyr::n_distinct(df$iso)
n_exp  <- dplyr::n_distinct(df$iso[df$exportador_neto])
message("N panel: ", nrow(df), " | ", n_pais, " countries (",
        n_exp, " exporters, ", n_pais - n_exp, " importers)")

# ---------------------------------------------------------------------------
# 2. Definitions (labels) and series
# ---------------------------------------------------------------------------

# Full definition of each concept in the figure (goes in the footnote)
labels_vars <- c(
  "Subsidio explicito: brecha entre el precio al consumidor y el costo de suministro",
  "USD bn: suma anual del grupo en miles de millones de dolares corrientes",
  "% del PIB: suma del subsidio del grupo sobre la suma del PIB del grupo",
  "Exportador neto: el alza del Brent infla la renta petrolera que financia el subsidio",
  "Importador neto: el alza del Brent encarece el costo de suministro y agrava el gasto"
)
labels_exp <- pais_es(sort(unique(df$iso[df$exportador_neto])))

# Aggregate series (Total LATAM): explicit subsidy in USD bn and % of GDP
serie_total <- function(d) {
  d |> group_by(anio) |>
    summarise(usd = sum(expl_total, na.rm = TRUE),
              pct = 100 * sum(expl_total, na.rm = TRUE) / sum(gdp, na.rm = TRUE),
              .groups = "drop") |>
    mutate(grupo = "Total LATAM")
}

# Series by shock-exposure group
serie_grupo <- function(d) {
  d |> mutate(grupo = ifelse(exportador_neto, "Exportador neto", "Importador neto")) |>
    group_by(grupo, anio) |>
    summarise(usd = sum(expl_total, na.rm = TRUE),
              pct = 100 * sum(expl_total, na.rm = TRUE) / sum(gdp, na.rm = TRUE),
              .groups = "drop")
}

agg_total <- serie_total(df)
agg_grupo <- serie_grupo(df)

# Shock jump (2021 -> 2022, Total LATAM) for the note and annotations
v21 <- round(agg_total$usd[agg_total$anio == 2021], 1)
v22 <- round(agg_total$usd[agg_total$anio == 2022], 1)
message("Total LATAM jump 2021->2022: ", v21, " -> ", v22, " USD bn (+",
        round(100 * (v22 - v21) / v21), "%)")

# ---------------------------------------------------------------------------
# 3. Figure helpers (World Bank palette, color)
# ---------------------------------------------------------------------------

# Shock marker (2022): vertical reference line, the event-study convention
# for a one-off event (more precise than a band, which marks periods).
linea_2022 <- geom_vline(xintercept = YEAR_SHOCK, linetype = "dashed",
                         colour = WB_SUBTLE, linewidth = 0.4)

# Annotate values only in key years: start (2015), COVID trough (2020),
# pre-shock (2021), shock (2022) and end (2023). Tells the story without clutter.
ANIOS_CLAVE <- c(2015, 2020, 2021, 2022, 2023)
capa_valores <- function(datos, y) {
  d <- datos[datos$anio %in% ANIOS_CLAVE, ]
  geom_text_repel(data = d, aes(label = formatC(.data[[y]], format = "f",
                  digits = ifelse(max(datos[[y]]) > 10, 1, 2))),
                  family = "Times New Roman", size = 2.8, seed = 42,
                  segment.color = NA, min.segment.length = 0,
                  nudge_y = diff(range(datos[[y]])) * 0.05, show.legend = FALSE)
}

panel_ts <- function(datos, y, color_map, ylab, leyenda = FALSE) {
  ggplot(datos, aes(anio, .data[[y]], colour = grupo)) +
    linea_2022 +
    geom_line(linewidth = 0.9) +
    geom_point(size = 1.6) +
    capa_valores(datos, y) +
    scale_x_continuous(breaks = YEARS_OBS) +
    scale_colour_manual(values = color_map) +
    labs(x = NULL, y = ylab) +
    tema_wb_ts() +
    theme(panel.grid.major.y = element_blank(),   # no horizontal gridlines
          legend.position = if (leyenda) "bottom" else "none")
}

col_total <- c("Total LATAM" = WB_CAT[6])        # WB dark blue

# ---------------------------------------------------------------------------
# 4. Figure (inline panels) and PNG composition
# ---------------------------------------------------------------------------

message("--- Panels a-d ---")
# Total panels (a, c): fixed color, not contributing to the collected legend.
# Group panels (b, d): provide the only legend (Exporter/Importer).
pa <- panel_ts(agg_total, "usd", col_total, "USD miles de millones") +
  guides(colour = "none")
pb <- panel_ts(agg_grupo, "usd", COLORES_EXPOSICION, NULL, leyenda = TRUE)
pc <- panel_ts(agg_total, "pct", col_total, "% del PIB") +
  guides(colour = "none")
pd <- panel_ts(agg_grupo, "pct", COLORES_EXPOSICION, NULL, leyenda = TRUE)

fig <- (pa | pb) / (pc | pd) +
  plot_layout(guides = "collect") +              # single legend
  plot_annotation(tag_levels = "a", tag_prefix = "(", tag_suffix = ")") &
  theme(plot.tag = element_text(family = "Times New Roman", size = 10,
                                face = "bold"),
        legend.position = "bottom")              # legend centered at the bottom

# Full footnote: variable definitions + groups + N + shock jump
nota <- paste0(
  "Subsidio explicito a combustibles fosiles, suma anual de cada grupo. ",
  "La linea vertical marca el ano del choque (2022), cuando el total de LATAM ",
  "paso de ", v21, " a ", v22, " USD miles de millones (+",
  round(100 * (v22 - v21) / v21), "%). ",
  "Variables: ", paste(labels_vars, collapse = ". "), ". ",
  "Exportadores netos (", n_exp, "): ", paste(labels_exp, collapse = ", "),
  "; el resto (", n_pais - n_exp, ") son importadores netos. ",
  "N = ", n_pais, " paises, 2015-2023."
)

save_fig_png(fig, "fig1_break.png", nota = nota,
             fuente = "IMF Fossil Fuel Subsidies Database; precio Brent: EIA.",
             w = 9, h = 7, dpi = 300)
message("  Saved: fig1_break.png")

# ---------------------------------------------------------------------------
# 5. Verification
# ---------------------------------------------------------------------------

out <- file.path(PATH$fig, "fig1_break.png")
stopifnot(file.exists(out), file.info(out)$size > 50000)
message("\nVERIFICATION PASS: ", out, " (",
        round(file.info(out)$size / 1024, 1), " KB)")

cerrar_log()
