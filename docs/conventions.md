# Table and figure conventions

Visual conventions of the project. They apply to **every** table and figure and are
implemented centrally in `code/config.R` (helpers `tabla_aer()`, `tema_wb_*()`,
`caption_wb()`, `save_fig()`).

> The tables, figures and slide deck are in Spanish; these conventions describe how
> they are built.

## Tables (AER style)

- Exported to Excel (`.xlsx`) with `openxlsx`, and to vector PDF for LaTeX with
  `code/descriptives/tables_pdf.R`.
- Portrait orientation; at most 9 columns including the variable column.
- Consecutive numbering (Table 1, Table 2, ...).
- Horizontal rules and white space only; no vertical rules or shading.
- Column headers are not abbreviated.
- Thematic panels (Panel A, Panel B, ...).
- Leading zero before decimals (0.357, not .357).

### Typography
- Times New Roman throughout.
- Title 13 pt bold; headers 11 pt bold, centered; column-number subheader (1), (2), ...
  10 pt centered; data 10 pt centered; variable names 10 pt bold, left-aligned;
  notes 9 pt.

### Layout (Excel)
- Column A left empty as a margin (width 2).
- Variable column width 22; data columns width 14.
- Borders: headers #888888, body #CCCCCC; always horizontal.

### Footnotes
- **Written as a single running paragraph** (one merged cell spanning the table width,
  with text wrapping), prefixed with `Notas.`. Not one row per point.
- Lowercase letter keys (a, b, c) for entry-specific notes.
- Sentence order: description of the content → value format (e.g. mean (SD)) →
  group definitions → sample restrictions → source (always last).
- **Significance:** regression tables report stars based on the clustered p-value
  (`† p<0.10, * p<0.05, ** p<0.01, *** p<0.001`); the legend goes in the notes.
  Descriptive tables report point estimates only (no between-group tests).

## Figures (World Bank palette)

- Style based on the World Bank Data Visualization Style Guide
  (https://wbg-vis-design.vercel.app/, packages `wbpyplot` / `wbplot`).
- Times New Roman (via `cairo_pdf`); white background; no title or subtitle.
- Size 7.5 × 5.2 inches (forest plots 8.5 × 5.5).
- Official WB categorical palette; text #111111, axes #666666, grid #EBEEF4.
- The shock year (2022) is shaded in time-series charts.
- Caption limited to "Notes:" and "Source:".
