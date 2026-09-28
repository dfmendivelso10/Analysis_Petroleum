# Download of international reserves from the World Bank
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Downloads two international-reserves metrics from the World Bank API
#   for the 34 LATAM countries, 2015-2023:
#     reservas_usd:    total reserves (incl. gold) in current USD
#     reservas_meses:  reserves in months of imports (external buffer)
#   Reserves link the shock to the balance-of-payments dimension:
#   net importers lose foreign currency sustaining the subsidy under high Brent,
#   net exporters accumulate it.
#
# Output: data/raw/reserves_wb.csv

import os
import time
import requests
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data", "raw", "reserves_wb.csv")

LAC_ISO = ["ATG","ARG","ABW","BHS","BRB","BLZ","BOL","BRA","CHL","COL","CRI",
           "DMA","DOM","ECU","SLV","GRD","GTM","GUY","HTI","HND","JAM","MEX",
           "NIC","PAN","PRY","PER","PRI","KNA","LCA","VCT","SUR","TTO","URY","VEN"]

INDICADORES = {
    "reservas_usd": "FI.RES.TOTL.CD",     # total reserves (incl. gold), current USD
    "reservas_meses": "FI.RES.TOTL.MO",   # reserves in months of imports
}
API = "https://api.worldbank.org/v2/country/{paises}/indicator/{ind}"


def descargar(indicador):
    url = API.format(paises=";".join(LAC_ISO), ind=indicador)
    params = {"format": "json", "date": "2015:2023", "per_page": 1000}
    for intento in range(3):                       # the WB sometimes returns empty; retry
        r = requests.get(url, params=params)
        try:
            datos = r.json()[1]
            break
        except (ValueError, KeyError, IndexError):
            time.sleep(2)
    else:
        raise RuntimeError(f"World Bank returned no data for {indicador}")
    return pd.DataFrame([
        {"iso": d["countryiso3code"], "anio": int(d["date"]), "valor": d["value"]}
        for d in datos
    ])


# One column per indicator, joined by country-year
reservas = None
for nombre, codigo in INDICADORES.items():
    serie = descargar(codigo).rename(columns={"valor": nombre})
    reservas = serie if reservas is None else reservas.merge(serie, on=["iso", "anio"], how="outer")

reservas = reservas.sort_values(["iso", "anio"])
reservas.to_csv(OUT, index=False)

print(f"Downloaded {len(reservas)} country-year records for {reservas.iso.nunique()} countries")
print(f"Completeness: reservas_usd {reservas.reservas_usd.notna().sum()}, "
      f"reservas_meses {reservas.reservas_meses.notna().sum()}")
print(reservas.query("iso == 'COL' and anio >= 2021"))
print(f"Saved to {OUT}")
