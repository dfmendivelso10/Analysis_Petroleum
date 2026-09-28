###############################################################
# 2022 oil shock - 03_fig_break.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Figure of the 2022 shock break in the explicit fossil fuel subsidy
#   in LAC (2015-2023). 2x2 grid (in color, World Bank
#   palette):
#     (a) LAC total, USD billion            -> size of the shock
#     (b) By exposure group, USD bn         -> who drives it
#     (c) LAC total, % of GDP               -> aggregate fiscal effort
#     (d) By group, % of GDP                -> fiscal effort by group
#   The shock year (2022) is marked with a dashed line and only the 2021 and
#   2022 values are annotated (2021 above-left, 2022 above-right of its point,
#   clear of the lines and of the 2022 marker, with a white halo). The note is
#   stored in outputs/results/figure_notes.rds and printed by the report.
#
#   Pattern: series and plot helpers defined above; inline figure below.
#   PNG output at 300 dpi (embeddable in LaTeX) with the note attached below.
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs = 34 countries x 9 years)
# Output: outputs/figures/fig1_break.png     (PNG 300 dpi, note included)
#         outputs/results/03_fig_break.rds    (key numbers for the paper)
###############################################################

source(here::here("code/config.R"))

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

labels_exp <- country_en(sort(unique(df$iso[df$exportador_neto])))

# Aggregate series (LAC total): explicit subsidy in USD bn and % of GDP
serie_total <- function(d) {
  d |> group_by(anio) |>
    summarise(usd = sum(expl_total, na.rm = TRUE),
              pct = 100 * sum(expl_total, na.rm = TRUE) / sum(gdp, na.rm = TRUE),
              .groups = "drop") |>
    mutate(grupo = "LAC total")
}

# Series by shock-exposure group
serie_grupo <- function(d) {
  d |> mutate(grupo = ifelse(exportador_neto, "Net exporter", "Net importer")) |>
    group_by(grupo, anio) |>
    summarise(usd = sum(expl_total, na.rm = TRUE),
              pct = 100 * sum(expl_total, na.rm = TRUE) / sum(gdp, na.rm = TRUE),
              .groups = "drop")
}

agg_total <- serie_total(df)
agg_grupo <- serie_grupo(df)

# Shock jump (2021 -> 2022, LAC total) for the note. The % change is computed
# from the unrounded values (one decimal, as in the text).
u21 <- agg_total$usd[agg_total$anio == 2021]
u22 <- agg_total$usd[agg_total$anio == 2022]
v21 <- round(u21, 1)
v22 <- round(u22, 1)
jump_pct <- round(100 * (u22 - u21) / u21, 1)
message("LAC total jump 2021->2022: ", v21, " -> ", v22, " USD billion (+",
        jump_pct, "%)")

# ---------------------------------------------------------------------------
# 3. Figure helpers (World Bank palette, color)
# ---------------------------------------------------------------------------

# Shock marker (2022): vertical reference line, the event-study convention
# for a one-off event (more precise than a band, which marks periods).
linea_2022 <- geom_vline(xintercept = YEAR_SHOCK, linetype = "dashed",
                         colour = WB_SUBTLE, linewidth = 0.4)

# Annotate only the 2021 (pre-shock) and 2022 (shock) values. Each label is placed
# at one of four corners around its point (above/below x left/right), choosing the
# corner whose (approximate) text box is crossed by the fewest line segments, the
# dashed 2022 marker included. A white box (geom_label, no border) acts as a halo.
ANIOS_CLAVE <- c(2021, YEAR_SHOCK)
LBL_W <- 0.18     # label width per character, in years (6.5-in figure, 2 panels)
LBL_H <- 0.09     # label height, as a share of the series range

#' Choose label corners that avoid lines. Returns `d` with x/y/hjust/vjust columns.
ubicar_etiquetas <- function(datos, y, d) {
  dy   <- diff(range(datos[[y]]))
  segs <- datos |> arrange(grupo, anio) |> group_by(grupo) |>
    transmute(x1 = anio, y1 = .data[[y]], x2 = lead(anio), y2 = lead(.data[[y]])) |>
    ungroup() |> filter(!is.na(x2))
  segs <- bind_rows(segs, tibble(x1 = YEAR_SHOCK, x2 = YEAR_SHOCK,
                                 y1 = min(datos[[y]]) - dy, y2 = max(datos[[y]]) + dy))
  t <- seq(0, 1, length.out = 60)
  cruces <- function(xa, xb, ya, yb) {
    sum(vapply(seq_len(nrow(segs)), function(k) {
      xs <- segs$x1[k] + t * (segs$x2[k] - segs$x1[k])
      ys <- segs$y1[k] + t * (segs$y2[k] - segs$y1[k])
      any(xs > xa & xs < xb & ys > ya & ys < yb)
    }, logical(1)))
  }
  # Candidate corners, in order of preference: above-right, below-right,
  # above-left, below-left
  cand <- tibble(sx = c(1, 1, -1, -1), sy = c(1, -1, 1, -1))
  out <- lapply(seq_len(nrow(d)), function(i) {
    w <- LBL_W * nchar(d$lbl[i]); h <- LBL_H * dy
    x0 <- d$anio[i] + 0.12 * cand$sx; y0 <- d[[y]][i] + 0.03 * dy * cand$sy
    n <- vapply(seq_len(nrow(cand)), function(j) cruces(
      min(x0[j], x0[j] + cand$sx[j] * w), max(x0[j], x0[j] + cand$sx[j] * w),
      min(y0[j], y0[j] + cand$sy[j] * h), max(y0[j], y0[j] + cand$sy[j] * h)),
      numeric(1))
    j <- which.min(n)
    tibble(x = x0[j], y = y0[j], hjust = ifelse(cand$sx[j] > 0, 0, 1),
           vjust = ifelse(cand$sy[j] > 0, 0, 1))
  })
  bind_cols(d, bind_rows(out) |> rename(lx = x, ly = y))
}

capa_valores <- function(datos, y) {
  dec <- ifelse(max(datos[[y]]) > 10, 1, 2)
  d <- datos[datos$anio %in% ANIOS_CLAVE, ] |>
    mutate(lbl = formatC(.data[[y]], format = "f", digits = dec))
  d <- ubicar_etiquetas(datos, y, d)
  geom_label(data = d, aes(x = lx, y = ly, label = lbl, hjust = hjust, vjust = vjust),
             family = "Times New Roman", size = 2.9, fill = "white",
             label.size = 0, label.padding = unit(0.08, "lines"),
             show.legend = FALSE)
}

panel_ts <- function(datos, y, color_map, ylab, leyenda = FALSE) {
  ggplot(datos, aes(anio, .data[[y]], colour = grupo)) +
    linea_2022 +
    geom_line(linewidth = 0.9) +
    geom_point(size = 1.6) +
    capa_valores(datos, y) +
    scale_x_continuous(breaks = YEARS_OBS,
                       expand = expansion(add = 0.4)) +
    scale_y_continuous(expand = expansion(mult = c(0.05, 0.15))) +
    scale_colour_manual(values = color_map, breaks = names(color_map)) +
    labs(x = NULL, y = ylab) +
    tema_wb_ts() +
    theme(panel.grid.major.y = element_blank(),   # no horizontal gridlines
          legend.position = if (leyenda) "bottom" else "none")
}

col_total <- c("LAC total" = WB_CAT[6])        # WB dark blue

# ---------------------------------------------------------------------------
# 4. Figure (inline panels) and PNG composition
# ---------------------------------------------------------------------------

message("--- Panels a-d ---")
# Total panels (a, c): fixed color, not contributing to the collected legend.
# Group panels (b, d): provide the only legend (Exporter/Importer).
pa <- panel_ts(agg_total, "usd", col_total, "USD billion") +
  guides(colour = "none")
pb <- panel_ts(agg_grupo, "usd", COLORES_EXPOSICION, "USD billion", leyenda = TRUE)
pc <- panel_ts(agg_total, "pct", col_total, "% of GDP") +
  guides(colour = "none")
pd <- panel_ts(agg_grupo, "pct", COLORES_EXPOSICION, "% of GDP", leyenda = TRUE)

fig <- (pa | pb) / (pc | pd) +
  plot_layout(guides = "collect") +              # single legend
  plot_annotation(tag_levels = "a", tag_prefix = "(", tag_suffix = ")") &
  theme(plot.tag = element_text(family = "Times New Roman", size = 10,
                                face = "bold"),
        legend.position = "bottom")              # legend centered at the bottom

# Note: definitions, groups, N and the shock jump (all computed)
nota <- paste0(
  "Explicit fossil fuel subsidy (gap between the supply cost and the consumer price), ",
  "annual group totals: USD billion in panels (a)\u2013(b) and percentage of the group's ",
  "aggregate GDP in panels (c)\u2013(d). The dashed line marks the ", YEAR_SHOCK,
  " shock, when the LAC total rose from USD ", fmt_num(v21, 1), " billion to USD ",
  fmt_num(v22, 1), " billion (+", fmt_num(jump_pct, 1), "%). ",
  "Countries are classified by net oil trade position (average 2015\u20132019 net exports of crude oil and refined products, UN Comtrade), not by production. ",
  "Net oil exporters (", num_en(n_exp), "): ", enum_en(labels_exp),
  "; the other ", num_en(n_pais - n_exp), " countries are net oil importers. N = ",
  n_pais, " countries, ", yr_range(min(df$anio), max(df$anio)), "."
)

save_fig_png(fig, "fig1_break.png", nota = nota,
             fuente = "IMF Fossil Fuel Subsidies Database; UN Comtrade.",
             w = 6.5, h = 5.2, dpi = 300)
message("  Saved: fig1_break.png")

# ---------------------------------------------------------------------------
# 5. Verification
# ---------------------------------------------------------------------------

out <- file.path(PATH$fig, "fig1_break.png")
stopifnot(file.exists(out), file.info(out)$size > 50000)
message("\nVERIFICATION PASS: ", out, " (",
        round(file.info(out)$size / 1024, 1), " KB)")

# ---------------------------------------------------------------------------
# 6. Key numbers for the paper -> outputs/results/03_fig_break.rds
# Elements:
#   series        : data frame (group x year) of the plotted series: group
#                   ("LAC total"/"Net exporter"/"Net importer"), year,
#                   explicit_usd_bn, explicit_pct_gdp
#   change_2021_2022 : data frame by group: usd_2021, usd_2022, change_usd_bn,
#                   change_usd_pct, pct_gdp_2021, pct_gdp_2022, change_pp
#   lac_jump      : values quoted in the note (usd_2021, usd_2022 rounded to 1 dp;
#                   pct_change from unrounded values, 1 dp)
#   net_exporters : names of the net exporter countries; n_countries, n_exporters
# ---------------------------------------------------------------------------
series <- bind_rows(agg_total, agg_grupo) |>
  transmute(group = grupo, year = anio,
            explicit_usd_bn = usd, explicit_pct_gdp = pct)
cambios <- series |>
  group_by(group) |>
  summarise(usd_2021     = explicit_usd_bn[year == 2021],
            usd_2022     = explicit_usd_bn[year == 2022],
            pct_gdp_2021 = explicit_pct_gdp[year == 2021],
            pct_gdp_2022 = explicit_pct_gdp[year == 2022],
            .groups = "drop") |>
  mutate(change_usd_bn  = usd_2022 - usd_2021,
         change_usd_pct = 100 * (usd_2022 - usd_2021) / usd_2021,
         change_pp      = pct_gdp_2022 - pct_gdp_2021)
res <- list(
  series           = as.data.frame(series),
  change_2021_2022 = as.data.frame(cambios),
  lac_jump         = c(usd_2021 = v21, usd_2022 = v22, pct_change = jump_pct),
  net_exporters    = labels_exp,
  n_countries      = n_pais,
  n_exporters      = n_exp
)
saveRDS(res, file.path(PATH$res, "03_fig_break.rds"))
message("Results saved: ", file.path(PATH$res, "03_fig_break.rds"))

cerrar_log()
