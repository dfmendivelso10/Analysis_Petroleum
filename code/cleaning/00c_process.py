# IMF data processing - Fossil fuel subsidies
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Extracts the raw variables from the IMF .xlsb (baseline scenario U1)
#   and builds two base panels (no derived variables; those are in 01_variables.py):
#     Base panel: country × year with the variables as provided by the IMF
#     Fuel panel: country × year × fuel (explicit/implicit/total)
#
# Input:  data/raw/imffossilfuelsubsidiesdata.xlsb
#         brent_annual.csv, fiscal_weo.xlsx, country_risk.csv (complementary sources)
# Output: data/processed/panel_base.xlsx
#         data/processed/panel_country_year_fuel.xlsx

import os
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
XLSB = os.path.join(ROOT, "data", "raw", "imffossilfuelsubsidiesdata.xlsb")
PROC = os.path.join(ROOT, "data", "processed")
os.makedirs(PROC, exist_ok=True)

LAC_ISO = {"ATG","ARG","ABW","BHS","BRB","BLZ","BOL","BRA","CHL","COL","CRI",
           "DMA","DOM","ECU","SLV","GRD","GTM","GUY","HTI","HND","JAM","MEX",
           "NIC","PAN","PRY","PER","PRI","KNA","LCA","VCT","SUR","TTO","URY","VEN"}

# Variables to extract: readable name -> IMF code (see docs/ dictionary)
VARS = {
    "expl_total": "mit.expsub.con.all.all.1", "impl_total": "mit.impsub.con.all.all.1",
    "tot_total": "mit.allsub.con.all.all.1", "expl_pctgdp": "mit.expsubgdp.con.all.all.1",
    "impl_pctgdp": "mit.impsubgdp.con.all.all.1", "tot_pctgdp": "mit.allsubgdp.con.all.all.1",
    "gdp": "mit.gdp.pre.lvl.1", "pop": "mit.pop.mn",
    "rev_usd": "mit.rev.new.usd.1", "rev_pctgdp": "mit.rev.new.pct.1",
    "eff_cost_usd": "mit.wel.eco.dwl.usd", "eff_cost_pctgdp": "mit.wel.eco.dwl.pct",
    "expl_oil": "mit.expsub.con.oil.all.1", "expl_nga": "mit.expsub.con.nga.all.1",
    "expl_ecy": "mit.expsub.con.ecy.all.1", "impl_oil": "mit.impsub.con.oil.all.1",
    "impl_nga": "mit.impsub.con.nga.all.1",
    "precio_gso": "mit.rp.gso.all.1", "precio_die": "mit.rp.die.all.1",
    "precio_nga": "mit.rp.nga.res.1", "costo_gso": "mit.sup.cost.gso.all.1",
    "costo_die": "mit.sup.cost.die.all.1", "costo_nga": "mit.sup.cost.nga.res.1",
}

# Fuels for the long panel, with their explicit and implicit codes
# (electricity has no implicit subsidy in the IMF database)
FUELS = [
    {"nombre": "Petróleo",     "explicito": "mit.expsub.con.oil.all.1", "implicito": "mit.impsub.con.oil.all.1"},
    {"nombre": "Gas natural",  "explicito": "mit.expsub.con.nga.all.1", "implicito": "mit.impsub.con.nga.all.1"},
    {"nombre": "Electricidad", "explicito": "mit.expsub.con.ecy.all.1", "implicito": None},
    {"nombre": "Carbón",       "explicito": "mit.expsub.con.coa.all.1", "implicito": "mit.impsub.con.coa.all.1"},
]

# Read the sheet: the .xlsb header is shifted, so columns are renamed by position
raw = pd.read_excel(XLSB, sheet_name="data", engine="pyxlsb")
raw.columns = ["pais", "scenario", "_d", "_c", "iso", "incomelevel", "region",
               "mtcode", "_s"] + list(raw.columns[9:])
anios = {2015: 24, 2016: 25, 2017: 26, 2018: 27, 2019: 28, 2020: 29,
         2021: 9, 2022: 10, 2023: 11}

# The mapping is positional; verify by content so it fails if the IMF reorders columns
assert raw.scenario.dropna().isin(["U1", "U2", "U3", "U4"]).all(), "col 'scenario' does not contain U1..U4"
assert raw.iso.str.match(r"^[A-Z]{3}$").any(), "col 'iso' does not contain ISO3 codes"
assert raw.mtcode.str.startswith("mit.").any(), "col 'mtcode' does not contain mit.* codes"
assert all(raw.columns[c] == a for a, c in anios.items()), "year columns do not match their header"

# Warn if any requested code is missing from the file, but continue
codigos_archivo = set(raw.mtcode.dropna())
for cod in VARS.values():
    if cod not in codigos_archivo:
        print(f"  Warning: code {cod} is not in the IMF file")

# Reshape to long format (country-variable-year), baseline scenario and LATAM only
ids = ["pais", "iso", "region", "incomelevel", "mtcode"]
df = (raw[(raw.scenario == "U1") & raw.iso.isin(LAC_ISO)]
      .melt(id_vars=ids, value_vars=[raw.columns[c] for c in anios.values()],
            var_name="col", value_name="valor"))
df["anio"] = df["col"].map({raw.columns[c]: a for a, c in anios.items()})
df["valor"] = pd.to_numeric(df["valor"], errors="coerce")   # IMF "0x2a" -> NA

# Base panel: one column per variable, identifiers + year
sub = df[df.mtcode.isin(VARS.values())].assign(var=lambda x: x.mtcode.map({v: k for k, v in VARS.items()}))
base = sub.pivot_table(index=["iso", "pais", "region", "incomelevel", "anio"],
                       columns="var", values="valor", aggfunc="first").reset_index()

# Add the international oil price (Brent), a source complementary to the IMF
brent = pd.read_csv(os.path.join(ROOT, "data", "raw", "brent_annual.csv"))
base = base.merge(brent, on="anio", how="left")

# Add IMF/WEO fiscal indicators (balance, debt, public revenue).
# WEO is used instead of the World Bank: it covers all 34 countries without gaps
# (the WB left 50-79% NA), which allows using them in the quantitative analysis.
fiscal = pd.read_excel(os.path.join(ROOT, "data", "raw", "fiscal_weo.xlsx"))
base = base.merge(fiscal, on=["iso", "anio"], how="left")

# Note: country risk (EMBIG, data/raw/country_risk.csv) is excluded from the panel:
# it only covers 8 countries that issue USD debt (70/306), which would bias the sample.

# Fuel panel: map each code to its fuel and component
filas_mapa = []
for fuel in FUELS:
    for componente in ["explicito", "implicito"]:
        codigo = fuel[componente]
        if codigo:
            filas_mapa.append({"mtcode": codigo, "combustible": fuel["nombre"],
                               "componente": componente})
mapa = pd.DataFrame(filas_mapa)

pf = df.merge(mapa, on="mtcode").pivot_table(
    index=["iso", "anio", "combustible"], columns="componente",
    values="valor", aggfunc="first").reset_index()
pf["total"] = pf[["explicito", "implicito"]].sum(axis=1, min_count=1)

# Summary and save
print(f"Base panel: {base.shape[0]} rows × {base.shape[1]} columns")
print(base.head(), "\n")
print(f"Fuel panel: {pf.shape[0]} rows × {pf.shape[1]} columns")
print(pf.head(), "\n")
col22 = base.query("iso == 'COL' and anio == 2022")["expl_total"].iloc[0]
assert abs(col22 - 8.29) < 0.1, "Colombia 2022 check failed"

base.to_excel(os.path.join(PROC, "panel_base.xlsx"), index=False)
pf.to_excel(os.path.join(PROC, "panel_country_year_fuel.xlsx"), index=False)
print("Panels saved to data/processed/")
