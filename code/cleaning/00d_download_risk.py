# Download of country risk (EMBIG)
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Downloads the EMBIG (country risk, sovereign spread in basis points) from the
#   Central Reserve Bank of Peru (BCRP) API for the LATAM countries that publish it,
#   and averages the monthly values to annual. The EMBIG only exists for countries
#   that issue dollar-denominated debt, so it does not cover all 34 (the Caribbean
#   islands have no data). It is a proxy for the cost of sovereign financing.
#
# Output: data/raw/country_risk.csv

import os
import requests
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data", "raw", "country_risk.csv")

# BCRP series code -> country (ISO3)
SERIES = {
    "PN01129XM": "PER", "PN01130XM": "ARG", "PN01131XM": "BRA", "PN01132XM": "CHL",
    "PN01133XM": "COL", "PN01134XM": "ECU", "PN01135XM": "MEX", "PN01136XM": "VEN",
}
API = "https://estadisticas.bcrp.gob.pe/estadisticas/series/api/{serie}/json/2015-1/2023-12"
MESES = {"Ene": 1, "Feb": 2, "Mar": 3, "Abr": 4, "May": 5, "Jun": 6,
         "Jul": 7, "Ago": 8, "Set": 9, "Oct": 10, "Nov": 11, "Dic": 12}


def descargar(serie, iso):
    datos = requests.get(API.format(serie=serie)).json()["periods"]
    filas = []
    for p in datos:
        valor = p["values"][0]
        if valor not in ("", "n.d."):
            anio = int(p["name"].split(".")[1])
            filas.append({"iso": iso, "anio": anio, "embig": float(valor)})
    return pd.DataFrame(filas)


# Download each country and average the months to an annual value
mensual = pd.concat([descargar(s, iso) for s, iso in SERIES.items()])
riesgo = mensual.groupby(["iso", "anio"], as_index=False)["embig"].mean().round(1)
riesgo.to_csv(OUT, index=False)

print(f"Downloaded EMBIG for {riesgo.iso.nunique()} countries, {len(riesgo)} country-year records")
print(riesgo.query("anio >= 2021").pivot(index="iso", columns="anio", values="embig"))
print(f"Saved to {OUT}")
