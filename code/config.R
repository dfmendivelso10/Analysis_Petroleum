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

# Country names in Spanish (ISO3 -> label), for tables and figures.
# The panel carries IMF country names in English; they are translated when reporting.
PAIS_ES <- c(
  ATG="Antigua y Barbuda", ARG="Argentina", ABW="Aruba", BHS="Bahamas",
  BRB="Barbados", BLZ="Belice", BOL="Bolivia", BRA="Brasil", CHL="Chile",
  COL="Colombia", CRI="Costa Rica", DMA="Dominica", DOM="República Dominicana",
  ECU="Ecuador", SLV="El Salvador", GRD="Granada", GTM="Guatemala", GUY="Guyana",
  HTI="Haití", HND="Honduras", JAM="Jamaica", MEX="México", NIC="Nicaragua",
  PAN="Panamá", PRY="Paraguay", PER="Perú", PRI="Puerto Rico",
  KNA="San Cristóbal y Nieves", LCA="Santa Lucía",
  VCT="San Vicente y las Granadinas", SUR="Surinam",
  TTO="Trinidad y Tobago", URY="Uruguay", VEN="Venezuela"
)
#' Translate ISO3 codes to Spanish country names
pais_es <- function(iso) unname(PAIS_ES[iso])

# Fuels (IMF code -> label)
FUELS <- tribble(
  ~code,  ~label,
  "gso",  "Gasolina",
  "die",  "Diésel",
  "lpg",  "GLP",
  "ker",  "Keroseno",
  "oop",  "Otros derivados de petróleo",
  "oil",  "Petróleo (agregado)",
  "nga",  "Gas natural",
  "coa",  "Carbón",
  "ecy",  "Electricidad"
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
COLORES_COMPONENTE <- c("Explícito" = WB_CAT[2], "Implícito" = WB_CAT[1])

# Net oil importers vs net exporters (blue vs orange, WB default)
COLORES_EXPOSICION <- c("Importador neto" = WB_CAT[1],
                        "Exportador neto" = WB_CAT[2])

# World Bank base theme: white background, Times New Roman, no minor grid or border
tema_wb_base <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      text             = element_text(family = "Times New Roman", colour = WB_TEXT),
      plot.title       = element_blank(),
      axis.text        = element_text(colour = WB_SUBTLE),
      axis.title       = element_text(colour = WB_TEXT),
      strip.background = element_blank(),
      strip.text       = element_text(face = "bold"),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border     = element_blank(),
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

FIG_W <- 7.5; FIG_H <- 5.2          # standard (inches)
FIG_W_FOREST <- 8.5; FIG_H_FOREST <- 5.5

#' Standard caption: only "Notas:" + "Fuente:"
#' @param notas text after "Notas:"; fuente text after "Fuente:"
caption_wb <- function(notas = NULL, fuente = NULL) {
  partes <- c(if (!is.null(notas))  paste0("Notas: ", notas),
              if (!is.null(fuente)) paste0("Fuente: ", fuente))
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

#' Save figure as 300 dpi PNG with the footnote composited INSIDE the
#' image (PACES style). The ggplot is rendered to a temp PNG and magick
#' appends a white block below with the note (wrapped to width). Keeps color.
#'   plot:   ggplot/patchwork (no caption; the note goes separately).
#'   name:   output file (.png) in outputs/figures.
#'   nota:   footnote text, running prose. Prefixed with "Notas. " plus the source.
#'   fuente: text after "Fuente: " (appended at the end of the note).
#'   w, h:   figure panel size in inches (excluding the note).
save_fig_png <- function(plot, name, nota, fuente = NULL,
                         w = 9, h = 7, dpi = 300) {
  stopifnot(requireNamespace("magick", quietly = TRUE))
  path <- file.path(PATH$fig, name)
  tmp  <- tempfile(fileext = ".png")
  # bg = "white": theme_minimal leaves the background NA; without this the cairo
  # PNG comes out transparent, which renders black when viewed or composited.
  ggsave(tmp, plot, width = w, height = h, dpi = dpi,
         device = grDevices::png, type = "cairo", bg = "white")

  img  <- magick::image_read(tmp)
  w_px <- magick::image_info(img)$width

  # Running-prose footnote. Font size is PROPORTIONAL to the chart
  # (~8pt = dpi*0.11 px). The wrap width is not guessed with a factor: it is
  # MEASURED. Actual px width per character is computed by rendering a sample
  # with magick (image_trim), then we find the largest `por_linea` whose longest
  # line after strwrap still fits the available width. So the text fills edge
  # to edge without overflowing, for any figure format (wide or narrow).
  texto     <- paste0("Notas. ", nota,
                      if (!is.null(fuente)) paste0(" Fuente: ", fuente))
  margen     <- as.integer(round(dpi * 0.12))     # vertical padding of the note
  margen_lat <- as.integer(round(dpi * 0.05))     # side padding (smaller: the
                                                  # text reaches closer to edges)
  ancho_txt  <- w_px - 2 * margen_lat
  fs         <- as.integer(round(dpi * 0.11))     # ~33px = 8pt at 300dpi

  # Actual px width of a Times string at size fs (measured, not estimated)
  ancho_px <- function(s) {
    if (nchar(s) == 0L) return(0L)
    m <- magick::image_blank(w_px * 2L, fs * 3L, "white")
    m <- magick::image_annotate(m, s, font = "Times", size = fs,
                                location = "+0+0", gravity = "northwest")
    magick::image_info(magick::image_trim(m))$width
  }
  # Widest line after wrapping at `cols` characters
  max_ancho <- function(cols) {
    ls <- strwrap(texto, width = cols)
    max(vapply(ls, ancho_px, integer(1L)))
  }
  # Find the largest cols whose longest line still fits in ancho_txt
  cols <- 40L
  while (max_ancho(cols + 5L) <= ancho_txt) cols <- cols + 5L
  while (cols > 10L && max_ancho(cols) > ancho_txt) cols <- cols - 2L

  envuelto  <- paste(strwrap(texto, width = cols), collapse = "\n")
  n_lineas  <- length(strsplit(envuelto, "\n")[[1L]])

  # Render the note on a roomy canvas and TRIM to the text's actual height
  # (image_trim), so no leftover white band remains under the last line.
  # Then re-pad with uniform padding above and below (= margen / 2).
  pad     <- as.integer(round(margen / 2))
  alto_max <- n_lineas * round(fs * 1.6) + 4L * margen
  bloque  <- magick::image_blank(w_px, alto_max, "white")
  bloque  <- magick::image_annotate(bloque, envuelto, font = "Times",
             size = fs, color = WB_TEXT,
             location = paste0("+", margen_lat, "+", pad),
             gravity = "northwest")
  bloque  <- magick::image_trim(bloque)                  # trim to the text
  lienzo  <- magick::image_border(bloque, "white",
             paste0(margen_lat, "x", pad))               # smaller side padding
  lienzo  <- magick::image_extent(lienzo, paste0(w_px, "x",
             magick::image_info(lienzo)$height),
             gravity = "west", color = "white")          # restore full width
  final  <- magick::image_append(c(img, lienzo), stack = TRUE)
  magick::image_write(final, path, format = "png", density = dpi)
  message("Figure saved: ", path, " (PNG ", dpi, " dpi)")
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
guardar_tabla <- function(df, name, sheet_name = "Datos") {
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
                      sheet_name = "Tabla") {
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
    texto <- paste0("Notas. ", paste(notas, collapse = " "))
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

#' Add a leading zero to decimal fractions and fix decimals (0.357, not .357)
fmt_num <- function(x, dec = 2) {
  x <- round(x, dec)
  x[x == 0] <- 0                       # avoids "-0.00" from rounding
  ifelse(is.na(x), "", formatC(x, format = "f", digits = dec))
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
