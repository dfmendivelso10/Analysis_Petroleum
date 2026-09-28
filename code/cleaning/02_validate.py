# Validation of the IMF data extraction
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Checks that the processed panels are correct before the analysis:
#   structure (years, countries, duplicates), coherence of the derived
#   variables, and consistency between the annual panel and the fuel panel.
#   Writes a markdown report.
#
# Input:  data/processed/panel_country_year.xlsx
#         data/processed/panel_country_year_fuel.xlsx
# Output: logs/validation.md

import os
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROC = os.path.join(ROOT, "data", "processed")
OUT = os.path.join(ROOT, "logs", "validation.md")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

pa = pd.read_excel(os.path.join(PROC, "panel_country_year.xlsx"))
pf = pd.read_excel(os.path.join(PROC, "panel_country_year_fuel.xlsx"))

# The subsidy by fuel must match between the annual panel and the fuel panel
def cruza(col, combustible):
    a = pa[["iso", "anio", col]]
    b = pf.query("combustible == @combustible")[["iso", "anio", "explicito"]]
    m = a.merge(b, on=["iso", "anio"])
    return (m[col] - m.explicito).abs().max()

pruebas = {
    "Years 2015-2023 (no projections)": set(pa.anio) == set(range(2015, 2024)),
    "34 LATAM countries": pa.iso.nunique() == 34,
    "No country-year duplicates": not pa.duplicated(["iso", "anio"]).any(),
    "No country-year-fuel duplicates": not pf.duplicated(["iso", "anio", "combustible"]).any(),
    "Gasoline gap = price - cost": (pa.brecha_gso - (pa.precio_gso - pa.costo_gso)).abs().max() < 1e-9,
    "Explicit oil subsidy matches across panels": cruza("expl_oil", "Petróleo") < 1e-9,
    "Explicit natural gas subsidy matches across panels": cruza("expl_nga", "Gas natural") < 1e-9,
}

# Report
ok = sum(pruebas.values())
filas = [f"| {nombre} | {'PASS' if v else 'FAIL'} |" for nombre, v in pruebas.items()]
reporte = (
    f"# Validation of the IMF data extraction\n\n"
    f"**{ok} of {len(pruebas)} tests passed.**\n\n"
    f"Checks the structure of the panels, the coherence of the derived "
    f"variables, and that the subsidy by fuel is consistent between the "
    f"annual panel and the fuel panel.\n\n"
    f"| Test | Result |\n|---|---|\n" + "\n".join(filas) + "\n\n"
    f"## Note\n"
    f"The IMF aggregate `tot_total` is not exactly equal to "
    f"`expl_total + impl_total` (they differ for some countries), because the IMF "
    f"computes its `all.all` totals independently. The official IMF "
    f"aggregate is kept.\n")
open(OUT, "w").write(reporte)

print(f"{ok}/{len(pruebas)} tests passed. Report at {OUT}")
assert ok == len(pruebas), "Check: some tests do not pass"
