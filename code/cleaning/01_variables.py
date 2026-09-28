# Construction of derived variables
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Takes the base panel and builds the analysis indicators:
#     per capita, explicit share, and price gaps
#     (consumer price minus supply cost) by fuel.
#   The gap is the explicit subsidy per unit: the transmission channel of the shock.
#
# Input:  data/processed/panel_base.xlsx
# Output: data/processed/panel_country_year.xlsx

import os
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROC = os.path.join(ROOT, "data", "processed")

df = pd.read_excel(os.path.join(PROC, "panel_base.xlsx"))

# Per capita subsidy and weight of the explicit component
df["subsidio_pc_usd"] = df["tot_total"] / df["pop"]
df["expl_share"] = (df["expl_total"] / df["tot_total"]).where(df["tot_total"] > 0)

# Price gaps: consumer price - supply cost (unit explicit subsidy)
df["brecha_gso"] = df["precio_gso"] - df["costo_gso"]
df["brecha_die"] = df["precio_die"] - df["costo_die"]
df["brecha_nga"] = df["precio_nga"] - df["costo_nga"]

# Net oil exporter: the heterogeneity axis of the shock. The criterion is
# NOT "produces oil" but NET FISCAL EXPOSURE to the crude price:
#   - Net exporter: a Brent rise inflates the state's oil rents, which
#     finance/cushion the subsidy (subsidy = redistribution of rents).
#   - Net importer: a Brent rise raises the supply cost and widens the
#     gap the state subsidizes (subsidy = spending that the shock aggravates).
# Hence Argentina (net energy importer in 2015-23, Vaca Muerta did not yet
# offset it) and Brazil (exports crude but imports the refined PRODUCTS that are
# subsidized to consumers) enter as importers: the shock raises their bill,
# not their rents. Net exporters with a clear, sustained oil trade surplus:
# crude (VEN, ECU, COL, MEX, TTO), gas (BOL) and newcomer GUY (Stabroek since 2019).
EXPORTADORES = {"VEN", "ECU", "COL", "MEX", "TTO", "BOL", "GUY"}
df["exportador_neto"] = df["iso"].isin(EXPORTADORES)

print(f"Analysis panel: {df.shape[0]} rows × {df.shape[1]} columns")
print(f"Net exporters: {df[df.exportador_neto].iso.nunique()} countries | "
      f"importers: {df[~df.exportador_neto].iso.nunique()}")
print(df[["iso", "anio", "exportador_neto", "subsidio_pc_usd", "expl_share",
          "brecha_gso", "brecha_die"]].head(), "\n")

df.to_excel(os.path.join(PROC, "panel_country_year.xlsx"), index=False)
print("Panel saved to data/processed/panel_country_year.xlsx")
