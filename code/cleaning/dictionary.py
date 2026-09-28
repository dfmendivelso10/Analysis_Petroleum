# Variable dictionary - two-sheet Excel workbook
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Generates the data dictionary in Excel:
#     Sheet "Paneles":      variables in the processed panels (the ones used)
#     Sheet "Catalogo IMF": the 234 raw variables from the `data` sheet of the .xlsb
#   Fields: variable, meaning, unit, source, original MTCode.
#
# Input:  data/raw/imffossilfuelsubsidiesdata.xlsb
# Output: docs/variable_dictionary.xlsx

import os
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
XLSB = os.path.join(ROOT, "data", "raw", "imffossilfuelsubsidiesdata.xlsb")
OUT = os.path.join(ROOT, "docs", "variable_dictionary.xlsx")
FUENTE = "IMF - Fossil Fuel Subsidies Database"

# Sheet 1: read from the actual processed panels and annotate each column.
# Annotation per variable: (meaning, unit, source, mtcode/origin). Reading the columns
# from the .xlsx instead of listing them by hand keeps the dictionary in sync with the panel.
PROC = os.path.join(ROOT, "data", "processed")
WB = "World Bank (WDI)"
GLOSA = {
    "iso": ("Código ISO3 del país", "", FUENTE, ""),
    "pais": ("Nombre del país", "", FUENTE, ""),
    "region": ("Región (clasificación Banco Mundial)", "", FUENTE, ""),
    "incomelevel": ("Nivel de ingreso del país", "", FUENTE, ""),
    "anio": ("Año (datos observados 2015-2023)", "año", FUENTE, ""),
    "exportador_neto": ("Indicador: exportador neto de hidrocarburos (VEN, ECU, COL, MEX, TTO, BOL, GUY)", "TRUE/FALSE", "Clasificación propia (EIA/BP)", "derivada"),
    "expl_total": ("Subsidio explícito total a combustibles fósiles", "USD miles de millones", FUENTE, "mit.expsub.con.all.all.1"),
    "impl_total": ("Subsidio implícito total (externalidades + IVA no aplicado)", "USD miles de millones", FUENTE, "mit.impsub.con.all.all.1"),
    "tot_total": ("Subsidio total (explícito + implícito)", "USD miles de millones", FUENTE, "mit.allsub.con.all.all.1"),
    "expl_pctgdp": ("Subsidio explícito como fracción del PIB", "fracción (×100 = %)", FUENTE, "mit.expsubgdp.con.all.all.1"),
    "impl_pctgdp": ("Subsidio implícito como fracción del PIB", "fracción (×100 = %)", FUENTE, "mit.impsubgdp.con.all.all.1"),
    "tot_pctgdp": ("Subsidio total como fracción del PIB", "fracción (×100 = %)", FUENTE, "mit.allsubgdp.con.all.all.1"),
    "expl_oil": ("Subsidio explícito - petróleo", "USD miles de millones", FUENTE, "mit.expsub.con.oil.all.1"),
    "expl_nga": ("Subsidio explícito - gas natural", "USD miles de millones", FUENTE, "mit.expsub.con.nga.all.1"),
    "expl_ecy": ("Subsidio explícito - electricidad", "USD miles de millones", FUENTE, "mit.expsub.con.ecy.all.1"),
    "impl_oil": ("Subsidio implícito - petróleo", "USD miles de millones", FUENTE, "mit.impsub.con.oil.all.1"),
    "impl_nga": ("Subsidio implícito - gas natural", "USD miles de millones", FUENTE, "mit.impsub.con.nga.all.1"),
    "gdp": ("PIB (línea base)", "USD miles de millones", FUENTE, "mit.gdp.pre.lvl.1"),
    "pop": ("Población", "millones de habitantes", FUENTE, "mit.pop.mn"),
    "rev_usd": ("Ingreso fiscal por remover subsidios", "USD miles de millones", FUENTE, "mit.rev.new.usd.1"),
    "rev_pctgdp": ("Ingreso fiscal por remover subsidios", "fracción (×100 = %)", FUENTE, "mit.rev.new.pct.1"),
    "eff_cost_usd": ("Costo de eficiencia (peso muerto)", "USD miles de millones", FUENTE, "mit.wel.eco.dwl.usd"),
    "eff_cost_pctgdp": ("Costo de eficiencia (peso muerto)", "fracción (×100 = %)", FUENTE, "mit.wel.eco.dwl.pct"),
    "precio_gso": ("Precio al consumidor - gasolina", "USD por litro", FUENTE, "mit.rp.gso.all.1"),
    "precio_die": ("Precio al consumidor - diésel", "USD por litro", FUENTE, "mit.rp.die.all.1"),
    "precio_nga": ("Precio al consumidor - gas natural (residencial)", "USD por GJ", FUENTE, "mit.rp.nga.res.1"),
    "costo_gso": ("Costo de suministro - gasolina", "USD por litro", FUENTE, "mit.sup.cost.gso.all.1"),
    "costo_die": ("Costo de suministro - diésel", "USD por litro", FUENTE, "mit.sup.cost.die.all.1"),
    "costo_nga": ("Costo de suministro - gas natural (residencial)", "USD por GJ", FUENTE, "mit.sup.cost.nga.res.1"),
    "brent_usd": ("Precio internacional del petróleo Brent (promedio anual)", "USD por barril", "EIA", "brent_annual.csv"),
    "balance_fiscal": ("Balance fiscal del gobierno central", "% del PIB", WB, "GC.NLD.TOTL.GD.ZS"),
    "deuda_publica": ("Deuda del gobierno central", "% del PIB", WB, "GC.DOD.TOTL.GD.ZS"),
    "ingreso_publico": ("Ingreso público", "% del PIB", WB, "GC.REV.XGRT.GD.ZS"),
    "subsidio_pc_usd": ("Subsidio total per cápita (tot_total / pop)", "USD por habitante", "Derivada", "derivada"),
    "expl_share": ("Participación del componente explícito en el total", "fracción", "Derivada", "derivada"),
    "brecha_gso": ("Brecha de precio - gasolina (precio - costo): subsidio explícito unitario", "USD por litro", "Derivada", "derivada"),
    "brecha_die": ("Brecha de precio - diésel (precio - costo)", "USD por litro", "Derivada", "derivada"),
    "brecha_nga": ("Brecha de precio - gas natural (precio - costo)", "USD por GJ", "Derivada", "derivada"),
    "combustible": ("Tipo de combustible", "", FUENTE, ""),
    "explicito": ("Subsidio explícito del combustible", "USD miles de millones", FUENTE, "mit.expsub.con.<fuel>.all.1"),
    "implicito": ("Subsidio implícito del combustible", "USD miles de millones", FUENTE, "mit.impsub.con.<fuel>.all.1"),
    "total": ("Subsidio total del combustible (explícito + implícito)", "USD miles de millones", "Derivada", "derivada"),
}

filas = []
for etiqueta, archivo in [("Panel país×año", "panel_country_year.xlsx"),
                          ("Panel combustible", "panel_country_year_fuel.xlsx")]:
    for col in pd.read_excel(os.path.join(PROC, archivo), nrows=0).columns:
        sig, uni, fte, mt = GLOSA.get(col, ("[PENDIENTE glosar]", "", "", ""))
        filas.append((etiqueta, col, sig, uni, fte, mt))
df_paneles = pd.DataFrame(filas, columns=["panel", "variable", "significado", "unidad", "fuente", "mtcode_imf"])
faltan = df_paneles[df_paneles.significado == "[PENDIENTE glosar]"]["variable"].tolist()
if faltan:
    print(f"  Warning: columns without an annotation in GLOSA: {faltan}")

# Sheet 2: full catalog of the 234 raw variables (mtcode + description from the .xlsb)
# Legends to decode the code mit.<concept>.<fuel>.<use>.<scenario>
CONCEPTO = {"expsub": "Subsidio explícito", "impsub": "Subsidio implícito",
            "allsub": "Subsidio total (explícito + implícito)", "psu": "Subsidio al productor",
            "drivingsub": "Subsidio asociado a la conducción",
            "sup.cost": "Costo de suministro", "sp": "Costo de suministro", "eff.price": "Precio eficiente",
            "rp": "Precio al consumidor", "vat": "IVA / impuesto al consumo", "vatrate": "Tasa de IVA",
            "airpol": "Costo por contaminación del aire", "extcost": "Externalidades",
            "cc": "Costo por cambio climático", "scc": "Daño climático", "co2": "Emisiones de CO2",
            "ghg": "Emisiones de gases de efecto invernadero", "rev": "Ingreso fiscal",
            "gdp": "PIB", "pop": "Población", "wel": "Bienestar / eficiencia económica", "con": "Consumo",
            "rescon": "Porción de consumo residencial", "trs": "Porción usada en transporte",
            "ener": "Consumo total de energía", "renshare": "Participación de renovables",
            "env": "Beneficios ambientales (reforma)",
            "acc": "Costo por accidentes viales", "rodd": "Costo por daño vial", "rdm": "Costo por daño vial",
            "roda": "Costo por accidentes viales", "veh": "Externalidades vehiculares"}
COMBUSTIBLE = {"gso": "Gasolina", "die": "Diésel", "lpg": "GLP", "ker": "Keroseno",
               "oop": "Otros derivados de petróleo", "oil": "Petróleo", "nga": "Gas natural",
               "coa": "Carbón", "ecy": "Electricidad", "all": "Todos los combustibles"}
USO = {"ind": "Industria", "res": "Residencial", "pow": "Generación eléctrica",
       "trs": "Transporte", "other": "Otros usos", "all": "Todos los usos"}
ESCENARIO = {"1": "Línea base", "2": "Con reforma de política"}

# Special codes without the usual mit.<...> structure
ESPECIALES = {"vat": "Tasa de IVA", "vsl": "Valor estadístico de una vida",
              "enda": "Tipo de cambio", "index": "Índice de inflación (2024 = 100)",
              "air.mort.1": "Muertes por contaminación del aire (línea base)",
              "air.mort.2": "Muertes por contaminación del aire (con reforma)",
              "ffs.deaths.1": "Muertes atribuibles a combustibles fósiles (línea base)",
              "other.deaths.1": "Muertes por otras causas (línea base)",
              "air.ef.cost.so2.coa": "Externalidad por tonelada de SO2 (planta de carbón)"}


def descomponer(code):
    if code in ESPECIALES:
        return pd.Series({"concepto": ESPECIALES[code], "combustible": "", "uso_final": "",
                          "escenario": "", "descripcion": ESPECIALES[code]})
    p = code.split(".")
    claves = [".".join(p[1:3])] + p[1:]                      # try 'sup.cost' and the individual parts
    concepto = next((CONCEPTO[k] for k in claves if k in CONCEPTO), "")
    fuel = next((COMBUSTIBLE[x] for x in p if x in COMBUSTIBLE), "")
    uso = next((USO[x] for x in p if x in USO), "")
    esc = ESCENARIO.get(p[-1], "")
    desc = " · ".join(x for x in [concepto, fuel, uso] if x)
    return pd.Series({"concepto": concepto, "combustible": fuel, "uso_final": uso,
                      "escenario": esc, "descripcion": desc or "(ver código)"})


raw = pd.read_excel(XLSB, sheet_name="data", engine="pyxlsb", usecols=[2, 7])
raw.columns = ["desc_imf", "mtcode_imf"]
catalogo = raw.dropna(subset=["mtcode_imf"]).drop_duplicates("mtcode_imf").sort_values("mtcode_imf")
catalogo = pd.concat([catalogo.reset_index(drop=True),
                      catalogo["mtcode_imf"].apply(descomponer).reset_index(drop=True)], axis=1)
catalogo["fuente"] = FUENTE
catalogo = catalogo[["mtcode_imf", "descripcion", "concepto", "combustible",
                     "uso_final", "escenario", "desc_imf", "fuente"]]

# Save both sheets
df_paneles = df_paneles[["panel", "variable", "significado", "unidad", "fuente", "mtcode_imf"]]
with pd.ExcelWriter(OUT) as xl:
    df_paneles.to_excel(xl, sheet_name="Paneles", index=False)
    catalogo.to_excel(xl, sheet_name="Catalogo IMF", index=False)

print(f"Dictionary: {len(df_paneles)} panel variables, {len(catalogo)} in the IMF catalog")
print(f"Saved to {OUT}")
