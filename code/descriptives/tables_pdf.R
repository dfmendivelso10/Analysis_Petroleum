###############################################################
# 2022 oil shock - tables_pdf.R
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Exports the project tables to VECTOR PDF for insertion into LaTeX
#   via \includegraphics (no pixelation). Reads the content of each official .xlsx
#   and rebuilds it with flextable in AER style (Times New Roman, horizontal
#   rules only, boxed panels), without the title (LaTeX \caption{} provides it)
#   and with the footnotes. Renders to cairo_pdf (vector) and crops
#   with pdfcrop. Does not replace the .xlsx files: it is an extra output for LaTeX.
#
#   Handles two formats: descriptive (simple header, with panels) and
#   regression (header + column subheader (1)(2)(3), no panels).
#
# Input:  outputs/tables/{tab1,tab2,tab4,tab5,tab6}*.xlsx
# Output: outputs/tables/<same name>.pdf  (vector, cropped, no title)
###############################################################

source(here::here("code/config.R"))
suppressMessages({library(flextable); library(officer)})

TABLAS <- c("tab1_descriptive", "tab2_countries", "tab4_model",
            "tab5_fiscal", "tab6_robustness")

bdr <- fp_border(color = "black", width = 1)

# Convert a table .xlsx into a vector PDF without the title
xlsx_a_pdf <- function(stem) {
  xlsx <- file.path(PATH$tab, paste0(stem, ".xlsx"))
  pdf  <- file.path(PATH$tab, paste0(stem, ".pdf"))
  stopifnot(file.exists(xlsx))

  raw <- openxlsx::read.xlsx(xlsx, colNames = FALSE, skipEmptyRows = FALSE)
  raw[is.na(raw)] <- ""

  # flextable does not interpret Excel's \n inside a cell: it stacks the text
  # on top of itself. Replace it with a space so each header fits on one line.
  sin_salto <- function(x) gsub("[\r\n]+", " ", x)

  header <- sin_salto(as.character(raw[2, ]))     # row 2: main header
  fila_nota <- max(which(nzchar(raw[, 1])))       # last non-empty row in col 1
  nota   <- raw[fila_nota, 1]

  # Subheader: row 3 with empty col 1 (regression tables: (1)(2)(3) + DV)
  hay_sub <- nzchar(raw[3, 1]) == FALSE
  fila_ini <- if (hay_sub) 4 else 3
  subhead  <- if (hay_sub) sin_salto(as.character(raw[3, ])) else NULL

  cuerpo <- raw[fila_ini:(fila_nota - 1), , drop = FALSE]
  names(cuerpo) <- paste0("V", seq_len(ncol(cuerpo)))

  es_panel <- grepl("^Panel", cuerpo$V1)
  es_n     <- grepl("^\\s*N ", cuerpo$V1)

  ft <- flextable(cuerpo)
  ft <- set_header_labels(ft, values = setNames(as.list(header), names(cuerpo)))
  if (hay_sub) {                                  # subheader row below the header
    ft <- add_header_row(ft, values = subhead, top = FALSE)
  }
  ft <- font(ft, fontname = "Times New Roman", part = "all")
  ft <- fontsize(ft, size = 9, part = "all")
  ft <- fontsize(ft, size = 8, part = "footer")
  ft <- align(ft, j = seq(2, ncol(cuerpo)), align = "center", part = "all")
  ft <- align(ft, j = 1, align = "left", part = "all")
  ft <- bold(ft, part = "header")

  ft <- border_remove(ft)
  ft <- hline_top(ft, border = bdr, part = "header")
  ft <- hline_bottom(ft, border = bdr, part = "header")
  ft <- hline_bottom(ft, border = bdr, part = "body")
  for (i in which(es_panel)) {                    # panels: bold + rule above
    ft <- bold(ft, i = i, part = "body")
    ft <- hline(ft, i = i, border = bdr, part = "body")
  }
  for (i in which(es_n)) ft <- hline(ft, i = i, border = bdr, part = "body")

  ft <- add_footer_lines(ft, values = nota)       # notes (no title)
  ft <- italic(ft, part = "footer")
  ft <- autofit(ft)

  gr  <- gen_grob(ft, fit = "auto", just = "center")
  dm  <- dim(gr)
  grDevices::cairo_pdf(pdf, width = dm$width + 0.2, height = dm$height + 0.2)
  grid::grid.draw(gr)
  grDevices::dev.off()

  if (nchar(Sys.which("pdfcrop")) > 0) {
    system2("pdfcrop", args = c(shQuote(pdf), shQuote(pdf)),
            stdout = FALSE, stderr = FALSE)
  }
  stopifnot(file.exists(pdf), file.info(pdf)$size > 5000)
  message("  ", basename(pdf), " (", round(file.info(pdf)$size / 1024, 1), " KB)")
}

message("Tables to vector PDF (no title, for LaTeX):")
for (t in TABLAS) xlsx_a_pdf(t)
message("Done: ", length(TABLAS), " PDFs in ", PATH$tab)
