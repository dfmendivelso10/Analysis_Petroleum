# Table 1 - Annual evolution of subsidies by group (2015-2023)
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Main descriptive table, in landscape orientation.
#   Years in columns (2015-2023), subsidies in rows, in three panels by
#   shock-exposure group:
#     Panel A: Total LATAM
#     Panel B: Net hydrocarbon exporters
#     Panel C: Net importers
#   Each panel reports the explicit, implicit and total subsidy (regional sum
#   in USD bn and % of group GDP). Shows both the trajectory of the shock and
#   the heterogeneity between exporters and importers.
#
# Input:  data/processed/panel_country_year.xlsx
# Output: outputs/tables/tab1_descriptive.xlsx

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
  as_tibble(c(list(Variable = "  N (países)"),
              setNames(as.list(rep(as.character(n), length(anios))),
                       as.character(anios))))
}

# Block for one group: label + explicit/implicit/total (USD bn and % GDP) +
# number of countries. Order within each section: the two components, then their sum.
bloque <- function(etiqueta, d) {
  bind_rows(
    fila_lbl(etiqueta),
    fila("Explícito (USD bn)", serie_suma(d, "expl_total")),
    fila("Implícito (USD bn)", serie_suma(d, "impl_total")),
    fila("Total (USD bn)",     serie_suma(d, "tot_total")),
    fila("Explícito (% PIB)",  serie_pctpib(d, "expl_total"), dec = 2),
    fila("Implícito (% PIB)",  serie_pctpib(d, "impl_total"), dec = 2),
    fila("Total (% PIB)",      serie_pctpib(d, "tot_total"),  dec = 2),
    fila_n(d)
  )
}

tabla <- bind_rows(
  bloque("Panel A. Total LATAM", df),
  bloque("Panel B. Exportadores netos de hidrocarburos", filter(df, exportador_neto)),
  bloque("Panel C. Importadores netos", filter(df, !exportador_neto))
)

# Number of countries per panel (for the notes)
n_tot <- n_distinct(df$iso)
n_exp <- n_distinct(df$iso[df$exportador_neto])
n_imp <- n_distinct(df$iso[!df$exportador_neto])

tabla_aer(
  tabla,
  name        = "tab1_descriptive.xlsx",
  titulo      = "Tabla 1. Evolución anual de los subsidios a combustibles fósiles (2015-2023)",
  ancho_datos = 8,
  landscape   = TRUE,
  notas = c(
    paste("Subsidios a combustibles fósiles en América Latina y el Caribe,",
          "por año y grupo de exposición, alrededor del choque petrolero de 2022."),
    paste("Cada celda es la suma del grupo en el año: en USD miles de millones (USD bn) y",
          "como porcentaje del PIB agregado del grupo."),
    paste("El subsidio explícito mide la brecha entre el precio al consumidor y el costo de",
          "suministro; el implícito recoge las externalidades no internalizadas y el IVA no",
          "aplicado; el total es la suma de ambos. El explícito es el componente que reacciona",
          "al choque en el corto plazo; el implícito depende del volumen consumido y de",
          "parámetros de daño ambiental, no del precio internacional. El implícito (y, por",
          "tanto, el total) no está estimado para todos los país-año."),
    paste("La clasificación es por exposición fiscal neta al precio del petróleo, no",
          "por producción: en los exportadores netos el alza del Brent infla la renta",
          "petrolera que financia el subsidio, mientras que en los importadores netos",
          "encarece el costo de suministro y agrava el gasto en subsidios. Argentina",
          "(importador neto de energía en el período) y Brasil (importa los derivados",
          "refinados que se subsidian) se clasifican como importadores."),
    paste0("Panel A, Total LATAM (N = ", n_tot, " países). ",
           "Panel B, exportadores netos de hidrocarburos (N = ", n_exp, "): ",
           "Bolivia, Colombia, Ecuador, Guyana, México, Trinidad y Tobago y Venezuela. ",
           "Panel C, importadores netos (N = ", n_imp, "): ",
           paste(sort(pais_es(unique(df$iso[!df$exportador_neto]))),
                 collapse = ", "), "."),
    "Fuente: IMF Fossil Fuel Subsidies Database."
  )
)
