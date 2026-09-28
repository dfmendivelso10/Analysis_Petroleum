# Table 2 - Explicit subsidy by country and year (% of GDP)
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Country-by-year breakdown of the explicit subsidy as % of GDP (2015-2023),
#   with the shock change (2022 vs pre-shock average 2015-2021) in the last
#   column. Two panels:
#     Panel A: net hydrocarbon exporters (7)
#     Panel B: net importers (27)
#   Sorted by size of the change within each panel. Landscape orientation.
#
# Input:  data/processed/panel_country_year.xlsx
# Output: outputs/tables/tab2_countries.xlsx

source(here::here("code/config.R"))

df    <- cargar_panel_anio()
anios <- sort(unique(df$anio))

# Explicit subsidy (% GDP) by country and year + shock change (2022 - pre)
por_pais <- df |>
  group_by(iso, exportador_neto) |>
  summarise(
    serie  = list(setNames(100 * expl_pctgdp[match(anios, anio)], anios)),
    pre    = 100 * mean(expl_pctgdp[anio <= 2021], na.rm = TRUE),
    y22    = 100 * expl_pctgdp[anio == 2022][1],
    .groups = "drop"
  ) |>
  mutate(cambio = y22 - pre, pais = pais_es(iso))

# One table row per country: name + one value per year + change
fila_pais <- function(r) {
  serie <- r$serie[[1]]
  as_tibble(c(
    list(Pais = paste0("  ", r$pais)),
    setNames(as.list(fmt_num(serie, 2)), as.character(anios)),
    list(Cambio = fmt_num(r$cambio, 2))
  ))
}

# Build one panel (rows sorted by descending change)
panel_pais <- function(datos) {
  datos <- datos |> arrange(desc(cambio))
  bind_rows(lapply(seq_len(nrow(datos)), function(i) fila_pais(datos[i, ])))
}

# Panel label row and N row (empty in the data columns)
vacias <- setNames(as.list(rep("", length(anios) + 1L)),
                   c(as.character(anios), "Cambio"))
fila_lbl <- function(txt) as_tibble(c(list(Pais = txt), vacias))
fila_n   <- function(datos) as_tibble(c(
  list(Pais = paste0("  N (países) = ", nrow(datos))), vacias))

exp <- filter(por_pais, exportador_neto)
imp <- filter(por_pais, !exportador_neto)

tabla <- bind_rows(
  fila_lbl("Panel A. Exportadores netos de hidrocarburos"),
  panel_pais(exp), fila_n(exp),
  fila_lbl("Panel B. Importadores netos"),
  panel_pais(imp), fila_n(imp)
)

names(tabla) <- c("País", as.character(anios), "Cambio (pp)")

tabla_aer(
  tabla,
  name        = "tab2_countries.xlsx",
  titulo      = "Tabla 2. Subsidio explícito a combustibles fósiles por país y año (% del PIB)",
  ancho_datos = 7,
  landscape   = TRUE,
  notas = c(
    paste("Subsidio explícito a los combustibles fósiles como porcentaje del PIB, por país y",
          "año, alrededor del choque petrolero de 2022."),
    paste("La última columna es el cambio del choque en puntos porcentuales: el valor de 2022",
          "menos el promedio del período pre-choque (2015-2021)."),
    paste("Los países se ordenan por la magnitud del cambio dentro de cada panel. Un valor de",
          "0.00 indica que el país no aplica subsidio explícito (precio al consumidor por",
          "encima del costo de suministro)."),
    paste("La clasificación es por exposición fiscal neta al precio del petróleo, no por",
          "producción: en los exportadores netos el alza del Brent infla la renta petrolera",
          "que financia el subsidio, mientras que en los importadores netos encarece el costo",
          "de suministro y agrava el gasto. Argentina (importador neto de energía en el",
          "período) y Brasil (importa los derivados refinados que se subsidian) se clasifican",
          "como importadores."),
    paste0("Panel A, exportadores netos de hidrocarburos (N = ", nrow(exp), "): ",
           paste(sort(pais_es(exp$iso)), collapse = ", "), ". ",
           "Panel B, importadores netos (N = ", nrow(imp), "): ",
           paste(sort(pais_es(imp$iso)), collapse = ", "), "."),
    "Fuente: IMF Fossil Fuel Subsidies Database."
  )
)
