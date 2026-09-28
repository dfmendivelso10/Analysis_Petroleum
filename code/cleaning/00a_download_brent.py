# Download of the Brent crude oil price
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Downloads the annual Brent crude price (average, USD per barrel) from
#   datahub.io (series based on EIA data) and saves it as a complementary
#   source. It is the international price-shock variable; the IMF data
#   does not include the price per barrel.
#
# Output: data/raw/brent_annual.csv

import os
import requests
import pandas as pd
from io import StringIO

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data", "raw", "brent_annual.csv")
URL = "https://datahub.io/core/oil-prices/r/brent-year.csv"

datos = pd.read_csv(StringIO(requests.get(URL).text))
datos["anio"] = pd.to_datetime(datos["Date"]).dt.year
brent = (datos[datos.anio.between(2015, 2023)]
         .rename(columns={"Price": "brent_usd"})[["anio", "brent_usd"]]
         .sort_values("anio"))
brent.to_csv(OUT, index=False)

print(f"Downloaded {len(brent)} years of Brent prices")
print(brent.to_string(index=False))
print(f"Saved to {OUT}")
