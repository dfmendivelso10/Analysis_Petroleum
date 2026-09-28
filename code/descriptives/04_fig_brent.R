###############################################################
# 2022 oil shock - 04_fig_brent.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Figure 2. Co-movement between the international oil price (Brent, the
#   shock variable; treatment is net-exporter status x 2022) and the aggregate
#   LAC explicit subsidy (outcome variable), 2015-2023. Dual axis: Brent
#   (USD/barrel, triangles) on the left, explicit subsidy (% of regional GDP,
#   open circles) on the right; distinct shapes keep both series visible where
#   the rescaled points coincide. The vertical line marks the shock (2022).
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs)
# Output: outputs/figures/fig2_brent.png       (PNG 300 dpi)
#         outputs/results/04_fig_brent.rds    (key numbers for the paper)
###############################################################

source(here::here("code/config.R"))

log_file <- iniciar_log("04_fig_brent")

# ---------------------------------------------------------------------------
# 1. Load and check
# ---------------------------------------------------------------------------

df <- cargar_panel_anio()
stopifnot(nrow(df) == 306)

# ---------------------------------------------------------------------------
# 2. Definitions (labels) and aggregate series
# ---------------------------------------------------------------------------

agg <- df |>
  group_by(anio) |>
  summarise(
    brent   = mean(brent_usd, na.rm = TRUE),
    sub_pct = 100 * sum(expl_total, na.rm = TRUE) / sum(gdp, na.rm = TRUE),
    .groups = "drop"
  )

corr <- round(cor(agg$brent, agg$sub_pct), 2)
message("Correlation Brent vs subsidy (% GDP): ", corr)

# ---------------------------------------------------------------------------
# 3. Secondary-axis scaling
# ---------------------------------------------------------------------------

# Map the subsidy (% GDP) onto the Brent axis range to overlay them.
# Rescale: sub_pct -> Brent scale; the right axis undoes the transformation.
r_brent <- range(agg$brent)
r_sub   <- range(agg$sub_pct)
a <- diff(r_brent) / diff(r_sub)
b <- r_brent[1] - a * r_sub[1]
to_brent <- function(x) a * x + b      # subsidy -> Brent scale
to_sub   <- function(y) (y - b) / a    # Brent scale -> subsidy (right axis)

agg <- agg |> mutate(sub_en_brent = to_brent(sub_pct))

# ---------------------------------------------------------------------------
# 4. Figure
# ---------------------------------------------------------------------------

col_brent <- WB_CAT[6]        # WB dark blue: shock variable
col_sub   <- WB_CAT[2]        # WB orange: outcome

# Brent: solid triangles; subsidy: open circles drawn on top, so both series stay
# visible in the years where the rescaled points coincide (2020, 2022).
serie_lbl <- c("Brent" = "Brent price (left axis)",
               "Subsidy" = "Explicit subsidy (right axis)")
fig <- ggplot(agg, aes(x = anio)) +
  geom_vline(xintercept = YEAR_SHOCK, linetype = "dashed",
             colour = WB_SUBTLE, linewidth = 0.4) +
  geom_line(aes(y = brent, colour = "Brent"), linewidth = 0.8) +
  geom_line(aes(y = sub_en_brent, colour = "Subsidy"), linewidth = 0.8) +
  geom_point(aes(y = brent, colour = "Brent", shape = "Brent"), size = 2.2) +
  geom_point(aes(y = sub_en_brent, colour = "Subsidy", shape = "Subsidy"),
             size = 3.2, stroke = 1, fill = NA) +
  scale_colour_manual(values = c("Brent" = col_brent, "Subsidy" = col_sub),
                      labels = serie_lbl, breaks = c("Brent", "Subsidy")) +
  scale_shape_manual(values = c("Brent" = 17, "Subsidy" = 1),
                     labels = serie_lbl, breaks = c("Brent", "Subsidy")) +
  scale_x_continuous(breaks = YEARS_OBS) +
  scale_y_continuous(
    name     = "Brent price (USD per barrel)",
    sec.axis = sec_axis(~ to_sub(.), name = "Explicit subsidy (% of GDP)")
  ) +
  labs(x = NULL, colour = NULL, shape = NULL) +
  tema_wb_ts() +
  theme(
    panel.grid.major.y   = element_blank(),   # no background grid
    panel.grid.minor     = element_blank(),
    axis.title.y.left    = element_text(colour = col_brent),
    axis.title.y.right   = element_text(colour = WB_TEXT),
    legend.position      = "bottom"
  )

# ---------------------------------------------------------------------------
# 5. Note and save
# ---------------------------------------------------------------------------

nota <- paste0(
  "Brent: annual average Europe Brent spot price (USD per barrel; left axis, triangles), ",
  "the shock variable. Explicit subsidy: gap between the supply cost and the consumer ",
  "price, LAC total as a percentage of regional GDP (right axis, circles). The dashed line ",
  "marks the ", YEAR_SHOCK, " shock. The correlation between the two series over ",
  yr_range(min(agg$anio), max(agg$anio)), " is ", fmt_num(corr, 2), ". The two axes have ",
  "different scales, so the figure shows co-movement, not comparable levels."
)

save_fig_png(fig, "fig2_brent.png", nota = nota,
             fuente = "IMF Fossil Fuel Subsidies Database; U.S. Energy Information Administration (EIA).",
             w = 6.5, h = 4.3, dpi = 300)

# ---------------------------------------------------------------------------
# 6. Verification
# ---------------------------------------------------------------------------

out <- file.path(PATH$fig, "fig2_brent.png")
stopifnot(file.exists(out), file.info(out)$size > 50000)
message("\nVERIFICATION PASS: ", out, " (",
        round(file.info(out)$size / 1024, 1), " KB)")

# ---------------------------------------------------------------------------
# 7. Key numbers for the paper -> outputs/results/04_fig_brent.rds
# Elements:
#   series            : data frame (year 2015-2023): brent_usd (annual average,
#                       USD/barrel), explicit_pct_gdp (LAC aggregate, % of GDP)
#   brent_2021, brent_2022 : Brent annual averages (USD/barrel)
#   brent_pct_change_2021_2022 : % change in Brent 2021 -> 2022
#   corr_brent_explicit : correlation Brent vs aggregate explicit subsidy
#                         (% of GDP), unrounded; corr_rounded = value in the note
# ---------------------------------------------------------------------------
b21 <- agg$brent[agg$anio == 2021]
b22 <- agg$brent[agg$anio == 2022]
res <- list(
  series = data.frame(year = agg$anio, brent_usd = agg$brent,
                      explicit_pct_gdp = agg$sub_pct),
  brent_2021                 = b21,
  brent_2022                 = b22,
  brent_pct_change_2021_2022 = 100 * (b22 - b21) / b21,
  corr_brent_explicit        = cor(agg$brent, agg$sub_pct),
  corr_rounded               = corr
)
saveRDS(res, file.path(PATH$res, "04_fig_brent.rds"))
message("Results saved: ", file.path(PATH$res, "04_fig_brent.rds"))

cerrar_log()
