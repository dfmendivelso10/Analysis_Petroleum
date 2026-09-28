###############################################################
# 2022 oil shock - 04_fig_brent.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Figure 2. Co-movement between the international oil price (Brent,
#   treatment variable) and the aggregate LATAM explicit subsidy
#   (outcome variable), 2015-2023. Dual axis: Brent (USD/barrel) on the
#   left, explicit subsidy (% of regional GDP) on the right. The vertical line
#   marks the shock (2022). Presents the treatment, sets it against the
#   outcome and visually motivates the causal question: the two series move
#   together (corr = 0.75), and the model quantifies that relationship by group.
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs)
# Output: outputs/figures/fig2_brent.png       (PNG 300 dpi)
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

labels_vars <- c(
  "Brent: precio internacional del petroleo (USD por barril), promedio anual; es la variable de tratamiento",
  "Subsidio explicito: brecha entre el precio al consumidor y el costo de suministro, suma de LATAM como % del PIB",
  "Co-movimiento: las dos series se mueven juntas (correlacion 0.75); el modelo lo cuantifica por grupo"
)

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

col_brent <- WB_CAT[6]        # WB dark blue: treatment
col_sub   <- WB_CAT[2]        # WB orange: outcome

fig <- ggplot(agg, aes(x = anio)) +
  geom_vline(xintercept = YEAR_SHOCK, linetype = "dashed",
             colour = WB_SUBTLE, linewidth = 0.4) +
  geom_line(aes(y = brent, colour = "Brent"), linewidth = 0.9) +
  geom_point(aes(y = brent, colour = "Brent"), size = 1.8) +
  geom_line(aes(y = sub_en_brent, colour = "Subsidio"), linewidth = 0.9) +
  geom_point(aes(y = sub_en_brent, colour = "Subsidio"), size = 1.8) +
  scale_colour_manual(
    values = c("Brent" = col_brent, "Subsidio" = col_sub),
    labels = c("Brent" = "Precio del Brent",
               "Subsidio" = "Subsidio explícito"),
    breaks = c("Brent", "Subsidio")
  ) +
  scale_x_continuous(breaks = YEARS_OBS) +
  scale_y_continuous(
    name     = "Precio del Brent (USD por barril)",
    sec.axis = sec_axis(~ to_sub(.), name = "Subsidio explícito (% del PIB)")
  ) +
  labs(x = NULL, colour = NULL) +
  tema_wb_ts() +
  theme(
    panel.grid.major     = element_blank(),   # no background grid
    panel.grid.minor     = element_blank(),
    axis.title.y.left    = element_text(colour = col_brent),
    axis.title.y.right   = element_text(colour = col_sub),
    axis.text.y.right    = element_text(colour = col_sub),
    axis.text.y.left     = element_text(colour = col_brent),
    legend.position      = "bottom"
  )

# ---------------------------------------------------------------------------
# 5. Note and save
# ---------------------------------------------------------------------------

nota <- paste0(
  "Co-movimiento entre el precio internacional del petroleo (Brent, linea azul, eje izquierdo) ",
  "y el subsidio explicito a combustibles fosiles agregado de America Latina y el Caribe ",
  "(linea naranja, eje derecho), 2015-2023. La linea vertical marca el ano del choque (2022). ",
  "La correlacion entre ambas series es de ", corr, ". El subsidio explicito reacciona al precio ",
  "internacional porque el alza del costo de suministro, si no se traslada al precio al consumidor, ",
  "amplia el subsidio. El doble eje superpone dos escalas distintas; la lectura es del co-movimiento ",
  "(direccion y giros comunes), no de niveles comparables entre las dos series. ",
  "Variables: ", paste(labels_vars, collapse = ". "), "."
)

save_fig_png(fig, "fig2_brent.png", nota = nota,
             fuente = "IMF Fossil Fuel Subsidies Database; precio Brent: EIA.",
             w = 9, h = 6, dpi = 300)

# ---------------------------------------------------------------------------
# 6. Verification
# ---------------------------------------------------------------------------

out <- file.path(PATH$fig, "fig2_brent.png")
stopifnot(file.exists(out), file.info(out)$size > 50000)
message("\nVERIFICATION PASS: ", out, " (",
        round(file.info(out)$size / 1024, 1), " KB)")

cerrar_log()
