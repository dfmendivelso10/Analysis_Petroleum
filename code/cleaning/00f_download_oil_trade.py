# Download of oil trade flows from UN Comtrade (treatment classification)
# Author: Daniel Mendivelso
# Date: 2026-09-28
#
# Description:
#   Downloads annual trade values (USD) with the World (partnerCode = 0) for the
#   34 LATAM countries, 2015-2023, from the UN Comtrade public preview API (no key):
#     HS 2709  crude petroleum oils
#     HS 2710  petroleum oils other than crude (refined products)
#     HS 2711  petroleum gases (natural gas, LPG) -- sensitivity only
#   flows M (imports) and X (exports). These flows define the pre-specified
#   treatment rule (net oil exporter; see quality_reports/plans/
#   2026-09-28_treatment-definition.md and code/cleaning/01_variables.py).
#
#   Own vs mirror data:
#     1. Reporting status. A country-year-flow is "own-reported" when the country
#        publishes its TOTAL (all commodities) trade for that year and flow.
#     2. Own data. For own-reported country-year-flows, the 27xx values are taken
#        from the country's own report. Comtrade does not publish zero rows, so a
#        commodity absent from an own report is recorded as 0 (source = own).
#     3. Mirror data. For country-year-flows that are not own-reported, the value
#        is rebuilt from partners' reports (partnerCode = country, all reporters):
#        partners' imports from the country = its exports; partners' exports to the
#        country = its imports. Aggregate reporters (World, EU) are excluded. A
#        missing mirror commodity is recorded as 0 (source = mirror).
#   The API returns at most 500 records per call and accepts one period per call;
#   calls are split by year (and, for mirror data, by commodity and flow) and the
#   script stops if any call hits the cap. It sleeps ~1 s between calls and
#   retries on HTTP 429/5xx.
#
# Input:  UN Comtrade public API  https://comtradeapi.un.org/public/v1/preview/C/A/HS
# Output: data/raw/oil_trade_comtrade.csv
#         (iso, year, cmd, flow, value_usd, source = own|mirror, n_partners)

import os
import time
import requests
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data", "raw", "oil_trade_comtrade.csv")

API = "https://comtradeapi.un.org/public/v1/preview/C/A/HS"
YEARS = list(range(2015, 2024))
CMDS = ["2709", "2710", "2711"]
FLOWS = ["M", "X"]
CAP = 500                      # maximum records returned by the preview endpoint
AGGREGATE_REPORTERS = {0, 97}  # World, European Union (would double count members)

# ISO3 -> UN M49 code (the code Comtrade uses as reporter/partner)
M49 = {
    "ATG": 28,  "ARG": 32,  "ABW": 533, "BHS": 44,  "BRB": 52,  "BLZ": 84,
    "BOL": 68,  "BRA": 76,  "CHL": 152, "COL": 170, "CRI": 188, "DMA": 212,
    "DOM": 214, "ECU": 218, "SLV": 222, "GRD": 308, "GTM": 320, "GUY": 328,
    "HTI": 332, "HND": 340, "JAM": 388, "MEX": 484, "NIC": 558, "PAN": 591,
    "PRY": 600, "PER": 604, "PRI": 630, "KNA": 659, "LCA": 662, "VCT": 670,
    "SUR": 740, "TTO": 780, "URY": 858, "VEN": 862,
}
ISO = {v: k for k, v in M49.items()}
assert len(M49) == 34


def consulta(params, intentos=6):
    """GET with retries on 429/5xx; returns the list of records (fails at the cap)."""
    for i in range(intentos):
        time.sleep(1.1)
        try:
            r = requests.get(API, params=params, timeout=60)
        except requests.RequestException:
            time.sleep(2 ** i)
            continue
        if r.status_code == 429 or r.status_code >= 500:
            time.sleep(2 ** (i + 1))
            continue
        r.raise_for_status()
        d = r.json()
        if "data" not in d:
            raise RuntimeError(f"Comtrade error {d.get('error')} for {params}")
        if len(d["data"]) >= CAP:
            raise RuntimeError(f"Response hit the {CAP}-record cap for {params}; split further")
        return d["data"]
    raise RuntimeError(f"Comtrade failed after {intentos} attempts: {params}")


def solo_totales(rows):
    """Keep aggregate customs regime / transport mode / secondary partner rows only."""
    return [r for r in rows
            if r["customsCode"] == "C00" and r["motCode"] == 0 and r["partner2Code"] == 0]


reporters = ",".join(str(c) for c in M49.values())

# ----------------------------------------------------------------
# 1. Reporting status: which country-year-flows have an own report
# ----------------------------------------------------------------
reporta = set()   # (iso, year, flow)
for y in YEARS:
    rows = solo_totales(consulta({"reporterCode": reporters, "period": y,
                                  "partnerCode": 0, "cmdCode": "TOTAL",
                                  "flowCode": "M,X"}))
    for r in rows:
        reporta.add((ISO[r["reporterCode"]], y, r["flowCode"]))
    print(f"{y}: {len({k[0] for k in reporta if k[1] == y})} of 34 countries report")

# ----------------------------------------------------------------
# 2. Own data (all 34 reporters, one call per year: <= 34*3*2 = 204 records)
# ----------------------------------------------------------------
own = {}
for y in YEARS:
    rows = solo_totales(consulta({"reporterCode": reporters, "period": y,
                                  "partnerCode": 0, "cmdCode": ",".join(CMDS),
                                  "flowCode": "M,X"}))
    for r in rows:
        k = (ISO[r["reporterCode"]], y, r["cmdCode"], r["flowCode"])
        own[k] = own.get(k, 0.0) + float(r["primaryValue"] or 0.0)

registros = []
for iso in M49:
    for y in YEARS:
        for f in FLOWS:
            if (iso, y, f) in reporta:
                for c in CMDS:
                    registros.append({"iso": iso, "year": y, "cmd": c, "flow": f,
                                      "value_usd": own.get((iso, y, c, f), 0.0),
                                      "source": "own", "n_partners": pd.NA})

# ----------------------------------------------------------------
# 3. Mirror data for country-year-flows without an own report
# ----------------------------------------------------------------
# Partners' reported flow is the mirror of the country's flow
ESPEJO = {"X": "M", "M": "X"}
faltan = sorted({(iso, y, f) for iso in M49 for y in YEARS for f in FLOWS
                 if (iso, y, f) not in reporta})
print(f"\nCountry-year-flows without an own report: {len(faltan)}")

for y in YEARS:
    for f in FLOWS:
        paises = sorted({iso for iso, yy, ff in faltan if yy == y and ff == f})
        if not paises:
            continue
        for c in CMDS:
            rows = solo_totales(consulta({"partnerCode": ",".join(str(M49[p]) for p in paises),
                                          "period": y, "cmdCode": c,
                                          "flowCode": ESPEJO[f]}))
            for p in paises:
                sel = [r for r in rows
                       if r["partnerCode"] == M49[p]
                       and r["reporterCode"] not in AGGREGATE_REPORTERS
                       and r["reporterCode"] != M49[p]]
                registros.append({"iso": p, "year": y, "cmd": c, "flow": f,
                                  "value_usd": sum(float(r["primaryValue"] or 0.0) for r in sel),
                                  "source": "mirror",
                                  "n_partners": len({r["reporterCode"] for r in sel})})

df = (pd.DataFrame(registros)
      .sort_values(["iso", "year", "cmd", "flow"])
      .reset_index(drop=True))
assert not df.duplicated(["iso", "year", "cmd", "flow"]).any()
assert len(df) == 34 * len(YEARS) * len(CMDS) * len(FLOWS), "incomplete country-year-cmd-flow grid"
df.to_csv(OUT, index=False)

# ----------------------------------------------------------------
# 4. Summary
# ----------------------------------------------------------------
print(f"\nSaved {len(df)} records ({df.iso.nunique()} countries) to {OUT}")
fuente = (df[df.year.between(2015, 2019)]
          .groupby("iso").source.agg(lambda s: f"own {int((s == 'own').sum())}, mirror {int((s == 'mirror').sum())}"))
print("\nSource of the 2015-2019 records (out of 30 per country):")
print(fuente[fuente.str.contains("mirror [1-9]")].to_string())
print("\nMexico 2018 (USD bn):")
print(df.query("iso == 'MEX' and year == 2018").assign(value_usd=lambda x: x.value_usd / 1e9))
