###############################################################
# 2022 oil shock and fossil fuel subsidies in LAC
# config.R — global project configuration
# Author: Daniel Mendivelso
#
# Description:
#   Centralizes libraries, paths, catalogs (LAC countries, fuels,
#   IMF variables), helpers (logging, saving tables/figures) and figure
#   themes (World Bank palette, AER-style tables).
#
# Usage: source(here::here("code/config.R")) at the top of every script.
# Input/Output: none (only defines objects in the environment).
###############################################################

# =============================================================
# 1. Base libraries
# =============================================================
suppressPackageStartupMessages({
  library(here)       # project-relative paths
  library(readxl)     # read Excel
  library(writexl)    # write Excel (lightweight)
  library(openxlsx)   # write formatted Excel
  library(dplyr)      # data manipulation
  library(tidyr)      # reshape
  library(purrr)      # functional programming
  library(stringr)    # strings
  library(ggplot2)    # plots
  library(patchwork)  # combine plots
})

# =============================================================
# 2. Project paths
# =============================================================
PROJ_DIR <- here()

PATH <- list(
  raw       = here("data", "raw"),
  processed = here("data", "processed"),
  fig       = here("outputs", "figures"),
  tab       = here("outputs", "tables"),
  res       = here("outputs", "results"),   # key estimates (.rds) read by the report
  docs      = here("docs"),
  logs      = here("logs")
)
for (p in PATH) dir.create(p, showWarnings = FALSE, recursive = TRUE)

# Main files
FILE_PANEL_ANIO <- file.path(PATH$processed, "panel_country_year.xlsx")
FILE_PANEL_FUEL <- file.path(PATH$processed, "panel_country_year_fuel.xlsx")
# Both panels are produced by code/cleaning/00c_process.py (extraction + cleaning).

# =============================================================
# 3. Time window and scenario
# =============================================================
# Observed data 2015-2023 (2024+ are projections). Shock = 2022.
YEARS_OBS  <- 2015:2023
YEAR_SHOCK <- 2022
YEARS_PRE  <- 2015:2019   # "normal" pre-shock (excludes 2020-21 COVID/recovery)

# Baseline scenario (no reform). The mapping of raw columns from the
# `data` sheet lives in code/cleaning/00c_process.py (extraction + cleaning in Python).
SCENARIO_BASELINE <- "U1"

# =============================================================
# 4. Catalogs
# =============================================================
# Latin America and Caribbean countries (ISO3)
LAC_ISO <- c("ATG","ARG","ABW","BHS","BRB","BLZ","BOL","BRA","CHL","COL","CRI",
             "DMA","DOM","ECU","SLV","GRD","GTM","GUY","HTI","HND","JAM","MEX",
             "NIC","PAN","PRY","PER","PRI","KNA","LCA","VCT","SUR","TTO","URY","VEN")

# Country names in English (ISO3 -> label), for tables and figures.
# Short common names are used instead of the IMF's official names.
COUNTRY_EN <- c(
  ATG="Antigua and Barbuda", ARG="Argentina", ABW="Aruba", BHS="Bahamas",
  BRB="Barbados", BLZ="Belize", BOL="Bolivia", BRA="Brazil", CHL="Chile",
  COL="Colombia", CRI="Costa Rica", DMA="Dominica", DOM="Dominican Republic",
  ECU="Ecuador", SLV="El Salvador", GRD="Grenada", GTM="Guatemala", GUY="Guyana",
  HTI="Haiti", HND="Honduras", JAM="Jamaica", MEX="Mexico", NIC="Nicaragua",
  PAN="Panama", PRY="Paraguay", PER="Peru", PRI="Puerto Rico",
  KNA="St. Kitts and Nevis", LCA="St. Lucia",
  VCT="St. Vincent and the Grenadines", SUR="Suriname",
  TTO="Trinidad and Tobago", URY="Uruguay", VEN="Venezuela"
)
#' Translate ISO3 codes to English country names
country_en <- function(iso) unname(COUNTRY_EN[iso])

# Fuels (IMF code -> label)
FUELS <- tribble(
  ~code,  ~label,
  "gso",  "Gasoline",
  "die",  "Diesel",
  "lpg",  "LPG",
  "ker",  "Kerosene",
  "oop",  "Other oil products",
  "oil",  "Oil (aggregate)",
  "nga",  "Natural gas",
  "coa",  "Coal",
  "ecy",  "Electricity"
)

# Aggregate subsidy variables (MTCode -> short name)
MT_AGG <- c(
  expl_total  = "mit.expsub.con.all.all.1",    # explicit total (USD bn)
  impl_total  = "mit.impsub.con.all.all.1",    # implicit total (USD bn)
  tot_total   = "mit.allsub.con.all.all.1",    # total expl+impl (USD bn)
  expl_pctgdp = "mit.expsubgdp.con.all.all.1", # explicit % GDP (fraction)
  impl_pctgdp = "mit.impsubgdp.con.all.all.1", # implicit % GDP (fraction)
  tot_pctgdp  = "mit.allsubgdp.con.all.all.1"  # total % GDP (fraction)
)
# Macro/fiscal context (MTCode -> short name)
MT_MACRO <- c(
  gdp      = "mit.gdp.pre.lvl.1",   # baseline GDP
  pop      = "mit.pop.mn",          # population (millions)
  rev_usd  = "mit.rev.new.usd.1",   # net fiscal revenue from subsidies (USD bn)
  eff_cost = "mit.wel.eco.dwl.usd"  # efficiency cost (USD bn)
)

# NOTE: the *pctgdp variables come as a FRACTION (0.093 = 9.3% of GDP).
# Multiply by 100 when reporting as a percentage.

# =============================================================
# 5. Figure themes (World Bank palette, Times New Roman typeface)
# =============================================================
# Visual style based on the World Bank Data Visualization Style Guide.
#   Guide:     https://wbg-vis-design.vercel.app/  (Colors section)
#   Palettes:  official packages wbpyplot (Python) / wbplot (R)
#              https://worldbank.github.io/wbpyplot/
#   Accessed:  2026-06-13.
# The WB palette is adopted; the typeface stays Times New Roman
# (project convention) instead of the WB's Open Sans.

# Official categorical palette (9 colors)
WB_CAT <- c("#34A7F2", "#FF9800", "#664AB6", "#4EC2C0", "#F3578E",
            "#081079", "#0C7C68", "#AA0000", "#DDDA21")
# Monochromatic sequential (to emphasize the shock)
WB_SEQ_YELLOW <- c("#FDF7DB", "#ECB63A", "#BE792B", "#8D4117", "#5C0000")
WB_SEQ_BLUE   <- c("#E3F6FD", "#75CCEC", "#089BD4", "#0169A1", "#023B6F")
# Chart elements (text, axes, grid, background)
WB_TEXT   <- "#111111"   # main text
WB_SUBTLE <- "#666666"   # axes / secondary text
WB_GRID   <- "#EBEEF4"   # guide lines (Grey100)
WB_SHADE  <- "#EBEEF4"   # shading for the shock year

# Explicit vs implicit (explicit is the one that reacts to the shock -> orange)
COLORES_COMPONENTE <- c("Explicit" = WB_CAT[2], "Implicit" = WB_CAT[1])

# Net oil importers vs net exporters (blue vs orange, WB default).
# GRUPO_LEVELS fixes the legend order in every figure (Net importer, Net exporter):
# pass it as `breaks` to the colour scales.
GRUPO_LEVELS <- c("Net importer", "Net exporter")
COLORES_EXPOSICION <- c("Net importer" = WB_CAT[1],
                        "Net exporter" = WB_CAT[2])

# World Bank base theme: white background, Times New Roman, no minor grid or border
tema_wb_base <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      text             = element_text(family = "Times New Roman", colour = WB_TEXT),
      plot.title       = element_blank(),
      axis.text        = element_text(colour = WB_TEXT),   # dark ticks: legible in print
      axis.title       = element_text(colour = WB_TEXT),
      legend.text      = element_text(colour = WB_TEXT),
      strip.background = element_blank(),
      strip.text       = element_text(face = "bold"),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border     = element_blank(),
      # Pure white background (no off-white panel when the PNG sits on the page)
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      legend.background = element_rect(fill = "white", colour = NA),
      legend.key       = element_rect(fill = "white", colour = NA),
      plot.caption     = element_text(size = 8, hjust = 0, colour = WB_SUBTLE,
                                      family = "Times New Roman",
                                      margin = margin(t = 10))
    )
}

# Time-series variant: visible X axis, Y guide grid
tema_wb_ts <- function(base_size = 11) {
  tema_wb_base(base_size) +
    theme(
      axis.line.x        = element_line(colour = WB_SUBTLE, linewidth = 0.3),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(colour = WB_GRID, linewidth = 0.5)
    )
}

# Ranking/horizontal-bar variant: X guide grid
tema_wb_barras <- function(base_size = 11) {
  tema_wb_base(base_size) +
    theme(
      axis.title.y       = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.grid.major.x = element_line(colour = WB_GRID, linewidth = 0.5),
      axis.line.x        = element_line(colour = WB_SUBTLE, linewidth = 0.3)
    )
}

# Compatibility aliases (scripts may use the previous AER name)
tema_aer_base <- tema_wb_base; tema_aer_ts <- tema_wb_ts; tema_aer_barras <- tema_wb_barras

# Figures are saved at the paper's text width (6.5 in) so that they are included
# at ~100% scale and text prints at >= 7-8 pt.
FIG_W <- 6.5; FIG_H <- 4.3          # standard (inches)
FIG_W_FOREST <- 8.5; FIG_H_FOREST <- 5.5

#' Standard caption: only "Notes:" + "Source:"
#' @param notas text after "Notes:"; fuente text after "Source:"
caption_wb <- function(notas = NULL, fuente = NULL) {
  partes <- c(if (!is.null(notas))  paste0("Notes: ", notas),
              if (!is.null(fuente)) paste0("Source: ", fuente))
  paste(partes, collapse = "\n")
}

#' Save figure to outputs/figures (cairo PDF, no title). If pdfcrop is
#' available on the system, it trims the PDF's excess margins.
save_fig <- function(plot, name, w = FIG_W, h = FIG_H) {
  path <- file.path(PATH$fig, name)
  ggsave(path, plot, width = w, height = h, device = grDevices::cairo_pdf)
  if (nchar(Sys.which("pdfcrop")) > 0) {
    system2("pdfcrop", args = c(shQuote(path), shQuote(path)),
            stdout = FALSE, stderr = FALSE)
  }
  message("Figure saved: ", path)
}

#' Save a figure as an 8-bit PNG (300 dpi) WITHOUT an embedded footnote, and
#' register its note in outputs/results/figure_notes.rds. The report prints the
#' note as text under the figure (legible at any size) instead of burning it
#' into the image.
#'   plot:   ggplot/patchwork (no caption; the note is stored separately).
#'   name:   output file (.png) in outputs/figures.
#'   nota:   footnote text, running prose (stored without the "Notes." prefix).
#'   fuente: source text (stored separately; the report prefixes "Source:").
#'   w, h:   figure size in inches.
save_fig_png <- function(plot, name, nota, fuente = NULL,
                         w = FIG_W, h = FIG_H, dpi = 300) {
  stopifnot(requireNamespace("magick", quietly = TRUE))
  path <- file.path(PATH$fig, name)
  tmp  <- tempfile(fileext = ".png")
  # bg = "white": theme_minimal leaves the background NA; without this the cairo
  # PNG comes out transparent, which renders black when viewed or composited.
  ggsave(tmp, plot, width = w, height = h, dpi = dpi,
         device = grDevices::png, type = "cairo", bg = "white")
  # Flatten to 8-bit RGB: 16-bit PNGs do not render under XeLaTeX/xdvipdfmx.
  img <- magick::image_read(tmp)
  img <- magick::image_flatten(magick::image_background(img, "white"))
  magick::image_write(img, path, format = "png", depth = 8, density = dpi)

  # Register the note (one entry per figure file; re-running a script overwrites it)
  notes_file <- file.path(PATH$res, "figure_notes.rds")
  notes <- if (file.exists(notes_file)) readRDS(notes_file) else list()
  notes[[name]] <- list(note = nota, source = fuente)
  saveRDS(notes[order(names(notes))], notes_file)

  message("Figure saved: ", path, " (PNG ", dpi, " dpi, 8-bit)")
  invisible(path)
}

# =============================================================
# 6. Data / table / logging helpers
# =============================================================
options(openxlsx.dateFormat = "yyyy-mm-dd")
set.seed(42)

#' Load the country×year panel
cargar_panel_anio <- function() read_excel(FILE_PANEL_ANIO)

#' Load the country×year×fuel panel
cargar_panel_fuel <- function() read_excel(FILE_PANEL_FUEL)

#' Save table to Excel with header formatting
guardar_tabla <- function(df, name, sheet_name = "Data") {
  path <- file.path(PATH$tab, name)
  wb <- createWorkbook()
  addWorksheet(wb, sheet_name)
  writeData(wb, sheet_name, df)
  headerStyle <- createStyle(
    fontSize = 11, fontName = "Times New Roman", halign = "center",
    border = "Bottom", borderColour = "#888888", textDecoration = "Bold"
  )
  addStyle(wb, sheet_name, headerStyle, rows = 1, cols = 1:ncol(df), gridExpand = TRUE)
  setColWidths(wb, sheet_name, cols = 1:ncol(df), widths = "auto")
  saveWorkbook(wb, path, overwrite = TRUE)
  message("Table saved: ", path)
}

#' AER-format table (see .claude/rules/table-standards.md)
#'   df:     data.frame; the 1st column is the variable name (text, left-aligned).
#'   titulo: table title (13pt bold).
#'   subheader: optional, vector of column labels (e.g. c("","(1)","(2)"))
#'              placed under the header; 10pt centered.
#'   notas:  vector of footnotes; the 1st is italic (description), the rest normal.
#'   paneles: optional, vector with each panel's starting row and its label
#'            as c("Panel A. ..." = 1, "Panel B. ..." = 5) (row relative to the data).
#' Layout: empty column A (margin), horizontal lines, no verticals or shading.
tabla_aer <- function(df, name, titulo, subheader = NULL, notas = NULL,
                      paneles = NULL, ancho_datos = 14, landscape = FALSE,
                      sheet_name = "Table") {
  TNR <- "Times New Roman"

  wb <- createWorkbook()
  addWorksheet(wb, sheet_name, gridLines = FALSE,
               orientation = if (landscape) "landscape" else "portrait")

  off_col <- 2L                       # empty column A (left margin)
  off_row <- 1L                       # row 1 = title
  ncol_df <- ncol(df)
  cols    <- off_col:(off_col + ncol_df - 1L)

  # Title (row 1)
  writeData(wb, sheet_name, titulo, startCol = off_col, startRow = off_row)
  addStyle(wb, sheet_name, createStyle(fontName = TNR, fontSize = 13,
           textDecoration = "Bold"), rows = off_row, cols = off_col)

  # Header (row 2): 11pt bold centered, top and bottom border #888888.
  # Only the names row is written (data goes separately so it does not clash with
  # the optional subheader).
  hdr_row <- off_row + 1L
  writeData(wb, sheet_name, as.data.frame(t(names(df))), startCol = off_col,
            startRow = hdr_row, colNames = FALSE)
  addStyle(wb, sheet_name, createStyle(fontName = TNR, fontSize = 11,
           textDecoration = "Bold", halign = "center", numFmt = "@",
           border = "TopBottom", borderColour = "#888888"),
           rows = hdr_row, cols = cols, gridExpand = TRUE)

  # Optional subheader with column numbers (1), (2): 10pt centered
  sub_row <- hdr_row
  if (!is.null(subheader)) {
    sub_row <- hdr_row + 1L
    for (j in seq_along(subheader)) {
      writeData(wb, sheet_name, subheader[j], startCol = off_col + j - 1L,
                startRow = sub_row)
    }
    addStyle(wb, sheet_name, createStyle(fontName = TNR, fontSize = 10,
             halign = "center"), rows = sub_row, cols = cols, gridExpand = TRUE)
  }

  # Body: variable names (col 1) 10pt bold left; data 10pt centered.
  dat_row0 <- sub_row + 1L
  n        <- nrow(df)
  writeData(wb, sheet_name, df, startCol = off_col, startRow = dat_row0,
            colNames = FALSE)
  addStyle(wb, sheet_name, createStyle(fontName = TNR, fontSize = 10,
           textDecoration = "Bold", halign = "left"),
           rows = dat_row0:(dat_row0 + n - 1L), cols = off_col, gridExpand = TRUE)
  if (ncol_df > 1) {
    # Centered data, NO row borders (blank body). numFmt "@" deliberately marks
    # the cells as text and suppresses Excel's green warning.
    addStyle(wb, sheet_name, createStyle(fontName = TNR, fontSize = 10,
             halign = "center", numFmt = "@"),
             rows = dat_row0:(dat_row0 + n - 1L),
             cols = (off_col + 1L):(off_col + ncol_df - 1L), gridExpand = TRUE)
  }

  # N rows (label starts with "N "): written as actual integers
  # (numFmt "0") so Excel's green "number stored as text" triangle does not appear.
  # The N row is boxed in: top border (separates it from the data) and the
  # bottom border comes from the panel closing line (further below).
  idx_n <- which(grepl("^\\s*N\\b", as.character(df[[1]])))
  for (k in idx_n) {
    r <- dat_row0 + k - 1L
    # Top border of the N row, full width (includes the label)
    addStyle(wb, sheet_name, createStyle(border = "Top", borderColour = "#888888"),
             rows = r, cols = cols, gridExpand = TRUE, stack = TRUE)
    vals <- suppressWarnings(as.numeric(df[k, -1]))
    if (any(!is.na(vals))) {
      for (j in which(!is.na(vals)))
        writeData(wb, sheet_name, vals[j], startCol = off_col + j, startRow = r)
      addStyle(wb, sheet_name, createStyle(fontName = TNR, fontSize = 10,
               halign = "center", numFmt = "0", border = "Top",
               borderColour = "#888888"), rows = r,
               cols = (off_col + 1L):(off_col + ncol_df - 1L),
               gridExpand = TRUE, stack = TRUE)
    }
  }

  # Closing line under the last data row (medium, same as each panel's
  # closing line, so all three close with the same weight)
  addStyle(wb, sheet_name, createStyle(border = "Bottom", borderColour = "#888888",
           borderStyle = "medium"),
           rows = dat_row0 + n - 1L, cols = cols, gridExpand = TRUE, stack = TRUE)

  # Panel labels: detected by a 1st column starting with "Panel ".
  # (the `paneles` parameter is also accepted for compatibility.) The label row
  # is BOXED IN just like the N row: medium line ABOVE and BELOW the label
  # itself. And at the close of the previous panel, a medium line under its
  # N row.
  idx_panel <- which(grepl("^Panel ", trimws(as.character(df[[1]]))))
  if (!is.null(paneles)) idx_panel <- as.integer(paneles)
  for (k in idx_panel) {
    r <- dat_row0 + k - 1L
    # Panel label in bold, boxed in: medium above and below across the full
    # width (the label cell also keeps the bold).
    addStyle(wb, sheet_name, createStyle(fontName = TNR, fontSize = 10,
             textDecoration = "Bold", border = "TopBottom",
             borderColour = "#888888", borderStyle = "medium"),
             rows = r, cols = off_col, stack = TRUE)
    addStyle(wb, sheet_name, createStyle(border = "TopBottom",
             borderColour = "#888888", borderStyle = "medium"),
             rows = r, cols = (off_col + 1L):(off_col + ncol_df - 1L),
             gridExpand = TRUE, stack = TRUE)
    # Medium bottom line closing the previous panel: the row right above
    # this panel's opening (it is the previous panel's N row).
    if (k > 1L)
      addStyle(wb, sheet_name, createStyle(border = "Bottom",
               borderColour = "#888888", borderStyle = "medium"),
               rows = r - 1L, cols = cols, gridExpand = TRUE, stack = TRUE)
  }

  # Footnotes: 9pt, running prose in a single cell (merged across the table
  # width) with text wrap. The vector's parts are joined with a space.
  if (!is.null(notas)) {
    nr <- dat_row0 + n
    texto <- paste0("Notes. ", paste(notas, collapse = " "))
    writeData(wb, sheet_name, texto, startCol = off_col, startRow = nr)
    mergeCells(wb, sheet_name, cols = cols, rows = nr)
    addStyle(wb, sheet_name, createStyle(fontName = TNR, fontSize = 9,
             valign = "top", wrapText = TRUE), rows = nr, cols = off_col)
    # Notes row height fitted to the actual text. The 1.7 factor converts
    # column-width units to Times 9pt characters: the notes font is smaller
    # than the default, so ~1.7 characters fit per width unit. Each line
    # takes ~12.5 pt (9pt + leading) with no extra cushion, so no blank
    # space is left under the notes.
    ancho_chars <- (22 + ancho_datos * max(ncol_df - 1L, 0)) * 1.7
    n_lineas    <- ceiling(nchar(texto) / ancho_chars)
    setRowHeights(wb, sheet_name, rows = nr, heights = 12.5 * n_lineas)
  }

  # Widths (col A margin=2; variable name=22; data=14) and heights
  setColWidths(wb, sheet_name, cols = 1, widths = 2)
  setColWidths(wb, sheet_name, cols = off_col, widths = 22)
  if (ncol_df > 1) setColWidths(wb, sheet_name,
                                cols = (off_col + 1L):(off_col + ncol_df - 1L),
                                widths = ancho_datos)
  setRowHeights(wb, sheet_name, rows = off_row, heights = 22)
  setRowHeights(wb, sheet_name, rows = hdr_row, heights = 18)

  saveWorkbook(wb, file.path(PATH$tab, name), overwrite = TRUE)
  message("Table saved: ", file.path(PATH$tab, name))
}

# Typography for notes and table cells: true minus sign (U+2212) and en dash
# (U+2013) for ranges.
MINUS <- "\u2212"
NDASH <- "\u2013"

#' Fixed decimals with leading zero (0.357, not .357) and a true minus sign.
#' Values that round to zero print as an unsigned "0.00" (no "-0.00").
fmt_num <- function(x, dec = 2) {
  x <- round(x, dec)
  x[!is.na(x) & x == 0] <- 0           # avoids "-0.00" from rounding
  out <- sub("^-", MINUS, formatC(x, format = "f", digits = dec))
  ifelse(is.na(x), "", out)
}

#' Signed number: "+1.79", "\u22120.32"; exact or rounded zeros print as "0.00"
fmt_signed <- function(x, dec = 2) {
  v <- round(x, dec)
  ifelse(is.na(v), "",
         ifelse(v == 0, formatC(0, format = "f", digits = dec),
                paste0(ifelse(v > 0, "+", MINUS),
                       formatC(abs(v), format = "f", digits = dec))))
}

#' Year range with an en dash: yr_range(2015, 2021) -> "2015\u20132021"
yr_range <- function(a, b) paste0(a, NDASH, b)

#' Axis labels with a true minus sign (for ggplot scale `labels =`)
lab_minus <- function(x) {
  out <- sub("^-", MINUS, format(x, trim = TRUE, drop0trailing = TRUE))
  ifelse(is.na(x), NA_character_, out)
}

#' p-value for notes: "p = 0.004" or "p < 0.001"
fmt_p <- function(p, dec = 3) {
  if (p < 10^-dec) paste0("p < ", formatC(10^-dec, format = "f", digits = dec))
  else paste0("p = ", formatC(p, format = "f", digits = dec))
}

#' Spell out integers below 10 ("seven"), digits otherwise ("27")
num_en <- function(n) {
  w <- c("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine")
  ifelse(n >= 0 & n < 10, w[n + 1], as.character(n))
}

#' English list with serial comma: "A, B, and C"
enum_en <- function(x) {
  x <- as.character(x)
  if (length(x) <= 1) return(paste(x, collapse = ""))
  if (length(x) == 2) return(paste(x, collapse = " and "))
  paste0(paste(x[-length(x)], collapse = ", "), ", and ", x[length(x)])
}

#' Start script log (sink to logs/)
iniciar_log <- function(script_name) {
  log_file <- file.path(PATH$logs, paste0("log_", script_name, "_", Sys.Date(), ".txt"))
  sink(log_file, split = TRUE)
  cat("========================================\n")
  cat("Script:", script_name, "\n")
  cat("Start:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  cat("========================================\n\n")
  invisible(log_file)
}

#' Close script log
cerrar_log <- function() {
  cat("\n========================================\n")
  cat("End:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  cat("========================================\n")
  sink()
}

# =============================================================
# 7. Confirmation
# =============================================================
message("config.R loaded — 2022 oil shock × fossil fuel subsidies in LAC")
message("Project: ", PROJ_DIR)
