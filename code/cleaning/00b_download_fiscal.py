# Download of IMF fiscal indicators (WEO, via the IMF DataMapper API)
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Downloads three fiscal indicators from the IMF World Economic Outlook for
#   the 34 LATAM countries, 2015-2023, via the IMF DataMapper API:
#     fiscal balance (net lending/borrowing), gross public debt and public
#     revenue (all for general government, in % of GDP).
#   WEO is used instead of the World Bank because WEO covers all 34 countries
#   without gaps (the WB left 50-79% NA, mostly in the Caribbean), which allows
#   the fiscal variables to enter the quantitative analysis, not just the prose.
#   The challenge explicitly suggests complementing with WEO.
#
# Output: data/raw/fiscal_weo.xlsx
#
# WEO indicators (DataMapper):
#   GGXCNL_NGDP     fiscal balance = general gov. net lending/borrowing, % GDP
#   GGXWDG_NGDP     general gov. gross public debt, % GDP
#   GGR_G01_GDP_PT  general gov. revenue, % GDP

import os
import requests
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data", "raw", "fiscal_weo.xlsx")

LAC_ISO = ["ATG","ARG","ABW","BHS","BRB","BLZ","BOL","BRA","CHL","COL","CRI",
           "DMA","DOM","ECU","SLV","GRD","GTM","GUY","HTI","HND","JAM","MEX",
           "NIC","PAN","PRY","PER","PRI","KNA","LCA","VCT","SUR","TTO","URY","VEN"]

INDICADORES = {
    "balance_fiscal": "GGXCNL_NGDP",     # net lending/borrowing, % GDP
    "deuda_publica": "GGXWDG_NGDP",      # general gov. gross debt, % GDP
    "ingreso_publico": "GGR_G01_GDP_PT", # general gov. revenue, % GDP
}
API = "https://www.imf.org/external/datamapper/api/v1/{ind}"
ANIOS = range(2015, 2024)


def descargar(indicador):
    r = requests.get(API.format(ind=indicador), timeout=30)
    valores = r.json().get("values", {}).get(indicador, {})
    filas = []
    for iso in LAC_ISO:
        serie = valores.get(iso, {})
        for anio in ANIOS:
            v = serie.get(str(anio))
            if v is not None:
                filas.append({"iso": iso, "anio": anio, "valor": float(v)})
    return pd.DataFrame(filas)


# One column per indicator, joined by country-year
fiscal = None
for nombre, codigo in INDICADORES.items():
    serie = descargar(codigo).rename(columns={"valor": nombre})
    fiscal = serie if fiscal is None else fiscal.merge(serie, on=["iso", "anio"], how="outer")

fiscal = fiscal.sort_values(["iso", "anio"])
fiscal.to_excel(OUT, index=False)

n_obs = len(fiscal)
print(f"Downloaded {n_obs} country-year records for {fiscal.iso.nunique()} countries")
for c in INDICADORES:
    print(f"  {c}: {fiscal[c].notna().sum()}/{n_obs} non-NA")
print(fiscal.query("iso == 'COL' and anio >= 2021"))
print(f"Saved to {OUT}")
