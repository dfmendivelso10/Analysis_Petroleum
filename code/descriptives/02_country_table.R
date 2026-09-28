# Table 2 - Explicit subsidy by country and year (% of GDP)
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Country-by-year breakdown of the explicit subsidy as % of GDP (2015-2023),
#   with the shock change (2022 vs pre-shock average 2015-2021) in the last
#   column. Two panels:
#     Panel A: net oil exporters (7)
#     Panel B: net oil importers (27)
#   Sorted by size of the change within each panel. Landscape orientation.
#
# Input:  data/processed/panel_country_year.xlsx
# Output: outputs/tables/tab2_countries.xlsx
#         outputs/results/02_country_table.rds (key numbers for the paper)

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
  mutate(cambio = y22 - pre, pais = country_en(iso))

# One table row per country: name + one value per year + change
fila_pais <- function(r) {
  serie <- r$serie[[1]]
  as_tibble(c(
    list(Pais = paste0("  ", r$pais)),
    # "n.a." marks a missing country-year (explained in the note)
    setNames(as.list(ifelse(is.na(serie), "n.a.", fmt_num(serie, 2))),
             as.character(anios)),
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
  list(Pais = paste0("  N (countries) = ", nrow(datos))), vacias))

exp <- filter(por_pais, exportador_neto)
imp <- filter(por_pais, !exportador_neto)

tabla <- bind_rows(
  fila_lbl("Panel A. Net oil exporters"),
  panel_pais(exp), fila_n(exp),
  fila_lbl("Panel B. Net oil importers"),
  panel_pais(imp), fila_n(imp)
)

names(tabla) <- c("Country", as.character(anios), "Change (pp)")

# Missing country-years (for the note): "Puerto Rico 2015\u20132017"-style list
faltantes <- por_pais |>
  mutate(anios_na = lapply(serie, function(v) as.integer(names(v)[is.na(v)]))) |>
  filter(lengths(anios_na) > 0) |>
  arrange(pais)
txt_na <- vapply(seq_len(nrow(faltantes)), function(i) {
  a <- faltantes$anios_na[[i]]
  rango <- if (length(a) > 1 && all(diff(a) == 1)) yr_range(min(a), max(a))
           else paste(a, collapse = ", ")
  paste(faltantes$pais[i], rango)
}, character(1))

pre_lbl <- yr_range(min(anios), 2021)
tabla_aer(
  tabla,
  name        = "tab2_countries.xlsx",
  titulo      = "Table 2. Explicit fossil fuel subsidy by country and year (% of GDP)",
  ancho_datos = 7,
  landscape   = TRUE,
  notas = c(
    "Explicit fossil fuel subsidy as a percentage of GDP, by country and year.",
    paste0("Change (pp): 2022 value minus the ", pre_lbl, " average, in percentage ",
           "points; countries are sorted by this change within each panel. A value of 0.00 ",
           "indicates a subsidy below 0.005% of GDP",
           if (length(txt_na) > 0) paste0("; n.a.: not available (", enum_en(txt_na), ")"),
           "."),
    paste0("Countries are classified by net oil trade position, not by production (",
           num_en(nrow(exp)), " net oil exporters and ", num_en(nrow(imp)),
           " net oil importers)."),
    "Source: IMF Fossil Fuel Subsidies Database."
  )
)

# ---------------------------------------------------------------------------
# Key numbers for the paper -> outputs/results/02_country_table.rds
# Elements:
#   classification : data frame, one row per country (sorted by group, then by
#                    descending change as in the table): iso, country, group
#                    ("Net exporter"/"Net importer"), explicit_pct_gdp_<year>
#                    for each year 2015-2023, pre_mean_2015_2021, y2022,
#                    change_pp (2022 minus 2015-2021 mean, pp of GDP)
#   net_exporters  : character vector of net exporter country names (sorted)
#   net_importers  : character vector of net importer country names (sorted)
# ---------------------------------------------------------------------------
clasif <- bind_rows(arrange(exp, desc(cambio)), arrange(imp, desc(cambio)))
serie_mat <- do.call(rbind, clasif$serie)
colnames(serie_mat) <- paste0("explicit_pct_gdp_", anios)
res <- list(
  classification = data.frame(
    iso     = clasif$iso,
    country = clasif$pais,
    group   = ifelse(clasif$exportador_neto, "Net exporter", "Net importer"),
    serie_mat,
    pre_mean_2015_2021 = clasif$pre,
    y2022              = clasif$y22,
    change_pp          = clasif$cambio,
    row.names = NULL, check.names = FALSE
  ),
  net_exporters = sort(country_en(exp$iso)),
  net_importers = sort(country_en(imp$iso))
)
saveRDS(res, file.path(PATH$res, "02_country_table.rds"))
message("Results saved: ", file.path(PATH$res, "02_country_table.rds"))
