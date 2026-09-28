# Table 1 - Annual evolution of subsidies by group (2015-2023)
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Main descriptive table, in landscape orientation.
#   Years in columns (2015-2023), subsidies in rows, in three panels by
#   shock-exposure group:
#     Panel A: LAC total
#     Panel B: Net oil exporters
#     Panel C: Net oil importers
#   Each panel reports the explicit, implicit and total subsidy (regional sum
#   in USD bn and % of group GDP). Shows both the trajectory of the shock and
#   the heterogeneity between exporters and importers.
#
# Input:  data/processed/panel_country_year.xlsx
# Output: outputs/tables/tab1_descriptive.xlsx
#         outputs/results/01_summary_table.rds (key numbers for the paper)

source(here::here("code/config.R"))

df <- cargar_panel_anio()
anios <- sort(unique(df$anio))

# Sum of a variable by year within a subset of rows
serie_suma <- function(d, var) {
  sapply(anios, function(a) sum(d[[var]][d$anio == a], na.rm = TRUE))
}
# Subsidy as % of group GDP = sum of subsidy / sum of GDP, by year
serie_pctpib <- function(d, var) {
  sapply(anios, function(a) {
    s <- d$anio == a
    100 * sum(d[[var]][s], na.rm = TRUE) / sum(d$gdp[s], na.rm = TRUE)
  })
}

# One row: label + one value per year
fila <- function(label, valores, dec = 1) {
  as_tibble(c(list(Variable = paste0("  ", label)),
              setNames(as.list(fmt_num(valores, dec)), as.character(anios))))
}
fila_lbl <- function(txt) {
  as_tibble(c(list(Variable = txt),
              setNames(as.list(rep("", length(anios))), as.character(anios))))
}

# N row (countries in the group), same value in every year column
fila_n <- function(d) {
  n <- n_distinct(d$iso)
  as_tibble(c(list(Variable = "  N (countries)"),
              setNames(as.list(rep(as.character(n), length(anios))),
                       as.character(anios))))
}

# Block for one group: label + explicit/implicit/total (USD bn and % GDP) +
# number of countries. Order within each section: the two components, then the IMF
# total (its own aggregate, which need not equal their sum).
bloque <- function(etiqueta, d) {
  bind_rows(
    fila_lbl(etiqueta),
    fila("Explicit (USD billion)", serie_suma(d, "expl_total")),
    fila("Implicit (USD billion)", serie_suma(d, "impl_total")),
    fila("Total (USD billion)",    serie_suma(d, "tot_total")),
    fila("Explicit (% of GDP)",   serie_pctpib(d, "expl_total"), dec = 2),
    fila("Implicit (% of GDP)",   serie_pctpib(d, "impl_total"), dec = 2),
    fila("Total (% of GDP)",      serie_pctpib(d, "tot_total"),  dec = 2),
    fila_n(d)
  )
}

tabla <- bind_rows(
  bloque("Panel A. LAC total", df),
  bloque("Panel B. Net oil exporters", filter(df, exportador_neto)),
  bloque("Panel C. Net oil importers", filter(df, !exportador_neto))
)

# Number of countries per panel (for the notes)
n_tot <- n_distinct(df$iso)
n_exp <- n_distinct(df$iso[df$exportador_neto])
n_imp <- n_distinct(df$iso[!df$exportador_neto])

tabla_aer(
  tabla,
  name        = "tab1_descriptive.xlsx",
  titulo      = paste0("Table 1. Annual evolution of fossil fuel subsidies (",
                       yr_range(min(anios), max(anios)), ")"),
  ancho_datos = 8,
  landscape   = TRUE,
  notas = c(
    paste("Group totals by year, in USD billion and as a percentage of the group's",
          "aggregate GDP."),
    paste("Explicit: gap between the supply cost and the consumer price. Implicit:",
          "uninternalized externalities and forgone VAT, driven mainly by volumes and damage",
          "parameters but not independent of the price (its forgone-VAT part scales with it);",
          "not estimated for every country-year. Total: the IMF's own aggregate, which need",
          "not equal explicit plus implicit."),
    paste0("Countries are classified by net oil trade position, not by production. ",
           "Net oil exporters (", num_en(n_exp), "): ",
           enum_en(sort(country_en(unique(df$iso[df$exportador_neto])))),
           "; the other ", num_en(n_imp), " countries are net oil importers."),
    "Source: IMF Fossil Fuel Subsidies Database."
  )
)

# ---------------------------------------------------------------------------
# Key numbers for the paper -> outputs/results/01_summary_table.rds
# Elements:
#   by_group_year : data frame (group x year) with n_countries,
#                   explicit_usd_bn, implicit_usd_bn, total_usd_bn,
#                   explicit_pct_gdp, implicit_pct_gdp, total_pct_gdp
#                   (group = "LAC total" / "Net exporters" / "Net importers")
#   n_countries   : named integer vector (lac_total, net_exporters, net_importers)
# ---------------------------------------------------------------------------
serie_grupo <- function(etiqueta, d) {
  tibble(
    group            = etiqueta,
    year             = anios,
    n_countries      = n_distinct(d$iso),
    explicit_usd_bn  = serie_suma(d, "expl_total"),
    implicit_usd_bn  = serie_suma(d, "impl_total"),
    total_usd_bn     = serie_suma(d, "tot_total"),
    explicit_pct_gdp = serie_pctpib(d, "expl_total"),
    implicit_pct_gdp = serie_pctpib(d, "impl_total"),
    total_pct_gdp    = serie_pctpib(d, "tot_total")
  )
}
res <- list(
  by_group_year = as.data.frame(bind_rows(
    serie_grupo("LAC total", df),
    serie_grupo("Net exporters", filter(df, exportador_neto)),
    serie_grupo("Net importers", filter(df, !exportador_neto))
  )),
  n_countries = c(lac_total = n_tot, net_exporters = n_exp, net_importers = n_imp)
)
saveRDS(res, file.path(PATH$res, "01_summary_table.rds"))
message("Results saved: ", file.path(PATH$res, "01_summary_table.rds"))
