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
#         outputs/results/05_fig_impact.rds   (key numbers for the paper)
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

# Change in the explicit subsidy (pp of GDP): 2022 vs pre-shock average.
# Pre = 2015-2019 ("normal" period, excludes the 2020-21 COVID distortion).
# Keeps countries with subsidy > 0.05% of GDP in some year of the period.
PISO <- 0.05  # % of GDP

dat <- df |>
  group_by(iso, exportador_neto) |>
  summarise(
    pre  = mean(expl_pctgdp[anio %in% YEARS_PRE] * 100, na.rm = TRUE),
    y22  = expl_pctgdp[anio == 2022][1] * 100,
    maxv = max(expl_pctgdp * 100, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(maxv > PISO) |>
  mutate(
    cambio = y22 - pre,
    grupo  = ifelse(exportador_neto, "Net exporter", "Net importer"),
    pais   = country_en(iso),
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

# Value annotated next to each point (pp of GDP, explicit sign, true minus;
# values that round to zero print as "0.00", without a sign).
dat <- dat |>
  mutate(lbl = fmt_signed(cambio, 2),
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
            size = 3, colour = WB_TEXT) +
  scale_x_continuous(
    breaks = scales::breaks_pretty(6),
    labels = function(x) ifelse(is.na(x), NA_character_,
                                paste0(ifelse(x > 0, "+", ""), lab_minus(x))),
    expand = expansion(mult = c(0.08, 0.10))
  ) +
  scale_colour_manual(values = COLORES_EXPOSICION, breaks = GRUPO_LEVELS) +
  labs(x = paste0("Change in explicit subsidy (pp of GDP, 2022 vs. ",
                  yr_range(min(YEARS_PRE), max(YEARS_PRE)), " average)"),
       y = NULL, colour = NULL) +
  tema_wb_ts() +
  theme(
    panel.grid.major.y = element_blank(),   # no horizontal gridlines per country
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.text.y        = element_text(size = 9, family = "Times New Roman"),
    axis.text.x        = element_text(size = 9),
    legend.position    = "bottom"
  )

# ---------------------------------------------------------------------------
# 5. Note and save
# ---------------------------------------------------------------------------

pre_lbl <- yr_range(min(YEARS_PRE), max(YEARS_PRE))
nota <- paste0(
  "Change in the explicit fossil fuel subsidy between the ", pre_lbl, " average and ",
  YEAR_SHOCK, ", in percentage points of GDP; the base period excludes the pandemic years ",
  yr_range(2020, 2021), ". The subsidy rose in ", n_subio, " of the ", n_pais,
  " countries. The measure is descriptive, not a causal estimate. Countries with an ",
  "explicit subsidy above ", PISO, "% of GDP in at least one year of ",
  yr_range(min(df$anio), max(df$anio)), " (", num_en(n_exp), " net oil exporters and ",
  num_en(n_imp), " net oil importers, classified by net oil trade position, not by ",
  "production)."
)

save_fig_png(fig, "fig3_impact.png", nota = nota,
             fuente = "IMF Fossil Fuel Subsidies Database.",
             w = 6.5, h = 7.5, dpi = 300)

# ---------------------------------------------------------------------------
# 6. Verification
# ---------------------------------------------------------------------------

out <- file.path(PATH$fig, "fig3_impact.png")
stopifnot(file.exists(out), file.info(out)$size > 50000)
message("\nVERIFICATION PASS: ", out, " (",
        round(file.info(out)$size / 1024, 1), " KB)")

# ---------------------------------------------------------------------------
# 7. Key numbers for the paper -> outputs/results/05_fig_impact.rds
# Elements:
#   impact      : data frame, one row per plotted country, sorted by change_pp
#                 (descending, largest impact first): iso, country, group
#                 ("Net exporter"/"Net importer"), pre_mean_2015_2019, y2022,
#                 change_pp (pp of GDP)
#   floor_pct_gdp : inclusion threshold (max explicit subsidy > floor, % of GDP)
#   n_countries, n_exporters, n_importers, n_increased, n_decreased
# ---------------------------------------------------------------------------
impact <- dat |>
  arrange(desc(cambio)) |>
  transmute(iso, country = as.character(pais), group = grupo,
            pre_mean_2015_2019 = pre, y2022 = y22, change_pp = cambio)
res <- list(
  impact        = as.data.frame(impact),
  floor_pct_gdp = PISO,
  n_countries   = n_pais,
  n_exporters   = n_exp,
  n_importers   = n_imp,
  n_increased   = n_subio,
  n_decreased   = n_pais - n_subio
)
saveRDS(res, file.path(PATH$res, "05_fig_impact.rds"))
message("Results saved: ", file.path(PATH$res, "05_fig_impact.rds"))

cerrar_log()
