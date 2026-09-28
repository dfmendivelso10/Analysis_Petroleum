###############################################################
# 2022 oil shock - 07_fiscal_analysis.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Fiscal implications of the shock and policy recommendation. Takes the
#   differential effect already estimated in 06_model.R (beta3, read from
#   outputs/results/06_model.rds) and sets it against each country's fiscal space. Nothing is re-estimated: this is
#   post-estimation. WEO fiscal variables (debt, balance) are used here, not in
#   the model (they would be "bad controls": a consequence of the subsidy, not
#   a cause).
#
#   Figure 5: policy matrix. Explicit subsidy (% of GDP, X axis) against public
#     debt (% of GDP, Y axis), 2022 cross-section; X on a square-root scale;
#     colour by exposure group; size = absolute 2021-2022 change in the subsidy
#     (USD bn), hollow points for decreases. The medians split the plane into four
#     quadrants (urgent / gradual reform / etc.).
#   Table 6: country-level backup (subsidy, observed change, illustrative
#     differential cost = beta3 x 2022 GDP for ALL net exporters, debt, fiscal
#     balance, quadrant), one panel per group.
#
# Input:  data/processed/panel_country_year.xlsx  (306 obs)
#         outputs/results/06_model.rds    (beta3 and its 95% CI; run 06_model.R first)
#         outputs/results/08_robustness.rds (leave-one-out range for the Fig. 5 note;
#                                            08 depends only on the panel)
# Output: outputs/figures/fig5_fiscal_matrix.png  (PNG 300 dpi)
#         outputs/tables/tab6_fiscal.xlsx         (AER table)
# N matrix: 26 countries with explicit subsidy > 0.05% of GDP in 2022
#           (exporter/importer split from the classification in 01_variables.py)
###############################################################

source(here::here("code/config.R"))

log_file <- iniciar_log("07_fiscal_analysis")

# ---------------------------------------------------------------------------
# 1. Load, check and parameters
# ---------------------------------------------------------------------------

df <- cargar_panel_anio()
stopifnot(nrow(df) == 306)

# Average differential effect (06_model.R, main TWFE "twfe_explicit"), in pp of GDP,
# with its 95% CI. It is the AVERAGE differential (exporters vs importers), not
# country-specific and not the total effect of the shock; here it only sizes an
# illustrative cost.
res06 <- readRDS(file.path(PATH$res, "06_model.rds"))
tw    <- res06$twfe[res06$twfe$model == "twfe_explicit", ]
stopifnot(nrow(tw) == 1)
beta3 <- list(coef = tw$coef, ci_low = tw$ci_low, ci_high = tw$ci_high)   # pp of GDP
BETA3 <- beta3$coef / 100                                                  # share of GDP

# Leave-one-out range (08_robustness.R). Guard: its full-sample column must match
# the TWFE read above (same data vintage).
res08 <- readRDS(file.path(PATH$res, "08_robustness.rds"))
stopifnot(abs(res08$exclusions$coef[res08$exclusions$sample == "full"] - beta3$coef) < 1e-8)

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
    grupo      = ifelse(exportador_neto, "Net exporter", "Net importer"),
    pais       = country_en(iso),
    # Illustrative DIFFERENTIAL cost: beta3 (point, CI low, CI high) x 2022 GDP, for
    # ALL net exporters (no selection on the observed change). NA for importers,
    # the comparison group (their differential is zero by construction).
    costo_beta = ifelse(exportador_neto, beta3$coef    / 100 * gdp, NA_real_),
    costo_low  = ifelse(exportador_neto, beta3$ci_low  / 100 * gdp, NA_real_),
    costo_high = ifelse(exportador_neto, beta3$ci_high / 100 * gdp, NA_real_),
    # Figure 5 point size and shape: absolute USD change, hollow if it decreased
    tam_usd    = abs(cambio_usd),
    direccion  = ifelse(cambio_usd < 0, "Decrease", "Increase")
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
    subsidio >= med_sub & deuda >= med_deu ~ "Urgent reform",
    subsidio >= med_sub & deuda <  med_deu ~ "Gradual reform",
    subsidio <  med_sub & deuda >= med_deu ~ "Monitor",
    TRUE                                   ~ "No immediate pressure"
  ))

cat("\n--- Quadrant 'Urgent reform' (high subsidy and high debt) ---\n")
urg <- dat |> filter(cuadrante == "Urgent reform") |> arrange(desc(subsidio))
for (i in seq_len(nrow(urg))) cat(sprintf("  %-20s subsidy %.1f | debt %.1f | balance %+.1f\n",
    urg$pais[i], urg$subsidio[i], urg$deuda[i], urg$balance[i]))

# ---------------------------------------------------------------------------
# 3. Figure 5: policy matrix (subsidy x debt)
# ---------------------------------------------------------------------------

# Quadrant labels in the corners of each quadrant, never crossing the median lines:
# right-hand labels right-aligned at the right edge; left-hand labels right-aligned
# just LEFT of the vertical median line (two lines if needed). The x axis is on a
# square-root scale, so positions are chosen in data units and transformed by ggplot.
lim_x  <- max(dat$subsidio) * 1.02
techo  <- max(dat$deuda) * 1.05
piso   <- min(dat$deuda) - (max(dat$deuda) - min(dat$deuda)) * 0.10
banda  <- (max(dat$deuda) - min(dat$deuda)) * 0.08   # height reserved for those labels
x_izq  <- (sqrt(med_sub) * 0.96)^2                    # just left of the median line
etq <- tibble::tibble(
  x   = c(lim_x, x_izq, lim_x, x_izq),
  y   = c(techo, techo, piso, piso),
  txt = c("Urgent reform", "Monitor", "Gradual reform", "No immediate\npressure"),
  hj  = c(1, 1, 1, 1),
  vj  = c(1, 1, 0, 0)
)

# Legend titles: tema_wb_base() blanks them, so they are re-enabled here.
# SIZE_RANGE is shared by the points (scale_size, area-proportional) and by the
# approximate point diameter passed to ggrepel, so labels keep clear of bubbles.
SIZE_RANGE <- c(1.6, 8)
dat <- dat |> mutate(grupo = factor(grupo, levels = GRUPO_LEVELS),
                     direccion = factor(direccion, levels = c("Increase", "Decrease")),
                     pt_rep = SIZE_RANGE[1] + diff(SIZE_RANGE) *
                       sqrt((tam_usd - min(tam_usd)) / diff(range(tam_usd))))
brk_x <- c(0.1, 0.5, 1, 2, 5, 10, 20)
brk_x <- brk_x[brk_x <= max(dat$subsidio) * 1.1]

fig <- ggplot(dat, aes(subsidio, deuda)) +
  geom_hline(yintercept = med_deu, colour = WB_SUBTLE,
             linetype = "dashed", linewidth = 0.35) +
  geom_vline(xintercept = med_sub, colour = WB_SUBTLE,
             linetype = "dashed", linewidth = 0.35) +
  geom_text(data = etq, aes(x, y, label = txt, hjust = hj, vjust = vj),
            inherit.aes = FALSE, family = "Times New Roman", lineheight = 0.9,
            fontface = "italic", size = 3, colour = WB_TEXT) +
  geom_point(aes(colour = grupo, size = tam_usd, shape = direccion),
             alpha = 0.8, stroke = 0.9) +
  ggrepel::geom_text_repel(aes(label = pais, colour = grupo, point.size = pt_rep),
                           family = "Times New Roman", size = 2.9,
                           seed = 42, max.overlaps = Inf,
                           force = 4, force_pull = 0.4,
                           box.padding = 0.4, point.padding = 0.25,
                           min.segment.length = 0, segment.size = 0.25,
                           segment.colour = WB_SUBTLE, show.legend = FALSE,
                           bg.color = "white", bg.r = 0.12,
                           # keep country labels out of the quadrant-label bands
                           ylim = c(piso + banda, techo - banda)) +
  scale_x_sqrt(breaks = brk_x, labels = function(b) paste0(b, "%"),
               expand = expansion(mult = c(0.02, 0.04))) +
  scale_y_continuous(breaks = scales::breaks_pretty(6),
                     expand = expansion(mult = c(0.04, 0.05))) +
  scale_colour_manual(values = COLORES_EXPOSICION, breaks = GRUPO_LEVELS,
                      name = "Group", guide = guide_legend(order = 1)) +
  scale_shape_manual(values = c("Increase" = 16, "Decrease" = 1),
                     name = "Change 2021\u201322", drop = FALSE,
                     guide = guide_legend(order = 2,
                                          override.aes = list(size = 3, colour = WB_SUBTLE))) +
  scale_size(range = SIZE_RANGE, breaks = c(0.1, 1, 5, 10),
             labels = function(b) paste0(b),
             name = "Absolute change,\nUSD billion",
             guide = guide_legend(order = 3,
                                  override.aes = list(colour = WB_SUBTLE, shape = 16))) +
  labs(x = "Explicit subsidy in 2022 (% of GDP, square-root scale)",
       y = "Public debt in 2022 (% of GDP)") +
  tema_wb_base() +
  theme(legend.position = "bottom",
        legend.box = "vertical",
        legend.box.just = "left",
        legend.spacing.y = unit(0, "pt"),
        legend.margin = margin(0, 0, 0, 0),
        legend.title = element_text(size = 9, colour = WB_TEXT),
        panel.grid = element_blank())   # no grid: the quadrants are the reference

# ---------------------------------------------------------------------------
# 4. Figure note and saving
# ---------------------------------------------------------------------------

# Urgent-quadrant importers named in the note (top two by subsidy), computed
imp_urg <- dat |> filter(cuadrante == "Urgent reform", !exportador_neto) |>
  arrange(desc(subsidio)) |> pull(pais)
lr <- res08$loo_range

nota_fig <- paste0(
  "Countries with an explicit subsidy above ", PISO, "% of GDP in ", YEAR_SHOCK, " (",
  n_pais, ": ", num_en(n_exp), " net oil exporters and ", num_en(n_imp),
  " net oil importers). Horizontal axis on a square-root scale. Point size is the absolute ",
  yr_range(2021, YEAR_SHOCK), " change in the explicit subsidy (USD billion); hollow points ",
  "are decreases. Dashed lines: sample medians of the subsidy (", fmt_num(med_sub, 2),
  "% of GDP) and of gross public debt (", fmt_num(med_deu, 1), "% of GDP). The estimated ",
  "differential effect for net oil exporters is ", fmt_num(beta3$coef, 2),
  " pp of GDP (Table 3), between ", fmt_num(lr$min, 2), " and ", fmt_num(lr$max, 2),
  " when each exporter is excluded in turn (Section 7). ",
  if (length(imp_urg) > 0) paste0("Net oil importers such as ",
                                   enum_en(utils::head(imp_urg, 2)),
                                   " are also in the urgent reform quadrant. "),
  "Debt and the fiscal balance are not included in the estimation."
)

save_fig_png(fig, "fig5_fiscal_matrix.png", nota = nota_fig,
             fuente = "IMF Fossil Fuel Subsidies Database; IMF, World Economic Outlook.",
             w = 6.5, h = 6.6, dpi = 300)

# ---------------------------------------------------------------------------
# 5. Table 6: country-level backup (one panel per group)
# ---------------------------------------------------------------------------

# One row per country; "n.a." for the illustrative cost of importers (comparison group)
fila_pais <- function(d) {
  data.frame(
    Variable = paste0("  ", d$pais),
    subs     = fmt_num(d$subsidio, 2),
    camb_pp  = fmt_signed(d$cambio_pp, 2),
    costo    = ifelse(is.na(d$costo_beta), "n.a.", fmt_num(d$costo_beta, 2)),
    deuda    = fmt_num(d$deuda, 1),
    balance  = fmt_signed(d$balance, 1),
    cuad     = d$cuadrante,
    stringsAsFactors = FALSE
  )
}

# Panel label row and N row (tabla_aer detects them by their prefix)
fila_lbl <- function(txt) data.frame(Variable = txt, subs = "", camb_pp = "",
                                     costo = "", deuda = "", balance = "", cuad = "")
fila_n   <- function(d) data.frame(Variable = "  N (countries)",
                                   subs = as.character(nrow(d)), camb_pp = "",
                                   costo = "", deuda = "", balance = "", cuad = "")

bloque <- function(etiqueta, d) {
  d <- d[order(-d$subsidio), ]
  do.call(rbind, c(list(fila_lbl(etiqueta)),
                   lapply(seq_len(nrow(d)), function(i) fila_pais(d[i, ])),
                   list(fila_n(d))))
}

tabla5 <- rbind(
  bloque("Panel A. Net oil exporters", dat[dat$exportador_neto, ]),
  bloque("Panel B. Net oil importers", dat[!dat$exportador_neto, ])
)
names(tabla5) <- c("Country", "Subsidy\n(% of GDP)", "Change\n2021\u201322 (pp)",
                   "Illustrative cost\n(USD billion)", "Debt\n(% of GDP)",
                   "Balance\n(% of GDP)", "Quadrant")

tab_path <- file.path(PATH$tab, "tab6_fiscal.xlsx")
tabla_aer(
  tabla5,
  name        = "tab6_fiscal.xlsx",
  titulo      = paste0("Table 6. Subsidy, illustrative shock cost, and fiscal space ",
                       "by country (", YEAR_SHOCK, ")"),
  ancho_datos = 13,
  landscape   = TRUE,
  notas = c(
    paste0("Countries with an explicit subsidy above ", PISO, "% of GDP in ", YEAR_SHOCK,
           ", sorted by subsidy within each group."),
    paste0("Change ", yr_range(2021, 22), ": observed change in the explicit subsidy ",
           "(pp of GDP), descriptive. Illustrative cost: \u03b2\u2083 (", fmt_num(beta3$coef, 2),
           " pp of GDP, Table 3) times each net oil exporter's ", YEAR_SHOCK, " GDP (USD ",
           "billion), an illustrative differential cost (exporters' subsidy increase beyond ",
           "importers'), not the total cost of the shock; ",
           "the 95% confidence interval of \u03b2\u2083 (", fmt_num(beta3$ci_low, 2), " to ",
           fmt_num(beta3$ci_high, 2), ") ",
           if (beta3$ci_low <= 0 && beta3$ci_high >= 0) "includes" else "excludes",
           " zero. n.a.: net oil importers, the ",
           "comparison group."),
    paste0("Debt: gross public debt; Balance: general government fiscal balance (negative = ",
           "deficit); both % of GDP. Quadrant: position relative to the sample medians of the subsidy (", fmt_num(med_sub, 2), "% of GDP) and ",
           "debt (", fmt_num(med_deu, 1), "% of GDP)."),
    "Source: IMF Fossil Fuel Subsidies Database; IMF, World Economic Outlook."
  )
)
message("\nTable saved: ", tab_path)

# ---------------------------------------------------------------------------
# 6. Verification
# ---------------------------------------------------------------------------

fig_path <- file.path(PATH$fig, "fig5_fiscal_matrix.png")
# Every exporter in the matrix has a cost equal to beta3 x its GDP (checked on the
# first one); the exporter count must match the panel classification
iso_chk   <- dat$iso[dat$exportador_neto][1]
costo_col <- dat$costo_beta[dat$iso == iso_chk]
n_exp_panel <- dplyr::n_distinct(df$iso[df$exportador_neto & df$anio == YEAR_SHOCK &
                                        100 * df$expl_pctgdp > PISO])
stopifnot(
  file.exists(fig_path), file.info(fig_path)$size > 50000,
  file.exists(tab_path),
  n_pais == 26, n_exp == n_exp_panel,
  abs(costo_col - BETA3 * dat$gdp[dat$iso == iso_chk]) < 1e-6,
  all(!is.na(dat$costo_beta[dat$exportador_neto])),
  all(is.na(dat$costo_beta[!dat$exportador_neto])),
  all(dat$costo_low <= dat$costo_beta & dat$costo_beta <= dat$costo_high, na.rm = TRUE)
)
cat("\n--- Verification ---\n")
cat("Figure and table generated: OK\n")
cat("Exporters in the matrix:", n_exp, "(matches the panel classification): OK\n")
cat("Illustrative cost", country_en(iso_chk), ":", fmt_num(costo_col, 2),
    "USD bn (= beta3 x GDP): OK\n")
cat("VERIFICATION PASS\n")

# ---------------------------------------------------------------------------
# 7. Key results for the paper (outputs/results/07_fiscal_analysis.rds)
# ---------------------------------------------------------------------------
# Elements:
#   median_subsidy_pct_gdp  median explicit subsidy 2022 (% of GDP): X cut-off
#   median_debt_pct_gdp     median public debt 2022 (% of GDP): Y cut-off
#   countries        data frame, one row per country in the matrix: iso, country, group,
#                    explicit_subsidy_pct_gdp_2022, change_pp_2021_2022,
#                    change_usd_bn_2021_2022, debt_pct_gdp_2022,
#                    fiscal_balance_pct_gdp_2022, gdp_usd_bn_2022, quadrant,
#                    shock_cost_usd_bn, shock_cost_low_usd_bn, shock_cost_high_usd_bn
#                    (illustrative DIFFERENTIAL cost: beta3 point / 95% CI low / CI high
#                    x 2022 GDP, USD bn; all net exporters; NA for importers)
#   quadrant_countries  named list (Urgent reform, Gradual reform, Monitor,
#                    No immediate pressure): country names, sorted by subsidy
#   n_countries, n_exporters, n_importers  counts in the matrix
#   beta3            list(coef, ci_low, ci_high): main TWFE beta3, pp of GDP (06_model.rds)
#   beta3_used       beta3$coef as a share of GDP (kept for backward compatibility)
#   subsidy_floor_pct_gdp  inclusion floor (% of GDP)

countries <- dat |>
  arrange(desc(subsidio)) |>
  transmute(iso, country = pais, group = as.character(grupo),
            explicit_subsidy_pct_gdp_2022 = subsidio,
            change_pp_2021_2022          = cambio_pp,
            change_usd_bn_2021_2022      = cambio_usd,
            debt_pct_gdp_2022            = deuda,
            fiscal_balance_pct_gdp_2022  = balance,
            gdp_usd_bn_2022              = gdp,
            quadrant                     = cuadrante,
            shock_cost_usd_bn            = costo_beta,
            shock_cost_low_usd_bn        = costo_low,
            shock_cost_high_usd_bn       = costo_high) |>
  as.data.frame()

quad_levels <- c("Urgent reform", "Gradual reform", "Monitor", "No immediate pressure")
quadrant_countries <- setNames(
  lapply(quad_levels, function(q) countries$country[countries$quadrant == q]),
  quad_levels)

res_07 <- list(
  median_subsidy_pct_gdp = med_sub,
  median_debt_pct_gdp    = med_deu,
  countries              = countries,
  quadrant_countries     = quadrant_countries,
  n_countries            = n_pais,
  n_exporters            = n_exp,
  n_importers            = n_imp,
  beta3                  = beta3,
  beta3_used             = BETA3,
  subsidy_floor_pct_gdp  = PISO
)
saveRDS(res_07, file.path(PATH$res, "07_fiscal_analysis.rds"))
message("Results saved: ", file.path(PATH$res, "07_fiscal_analysis.rds"))

cerrar_log()
