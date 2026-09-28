# Table and figure conventions

Visual conventions of the project. They apply to **every** table and figure and are
implemented centrally in `code/config.R` (helpers `tabla_aer()`, `tema_wb_*()`,
`caption_wb()`, `save_fig()`).

> These conventions describe how the pipeline builds tables and figures; the working
> paper (`report/`) prints figure and table notes as text below each float.

## Tables (AER style)

- Exported to Excel (`.xlsx`) with `openxlsx`; the working paper typesets them natively
  in LaTeX (booktabs) from those files.
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
- Times New Roman; 8-bit PNG at 300 dpi; pure white background; no title or subtitle.
- Width 6.5 inches (the text width of the paper), so text prints at native size.
- Official WB categorical palette; text and axis labels #111111, grid #EBEEF4.
- The shock year (2022) is shaded in time-series charts.
- No note is burned into the image: each figure's note and source are stored in
  `outputs/results/figure_notes.rds` and printed below the figure in the paper.
