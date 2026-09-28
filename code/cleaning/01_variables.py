# Construction of derived variables
# Author: Daniel Mendivelso
# Date: 2026-06-13
#
# Description:
#   Takes the base panel and builds the analysis indicators:
#     per capita, explicit share, and price gaps
#     (consumer price minus supply cost) by fuel.
#   The gap is the explicit subsidy per unit: the transmission channel of the shock.
#   Also builds the treatment: net oil exporter status from UN Comtrade under the
#   pre-specified rule (main) plus the sensitivity variants.
#
# Input:  data/processed/panel_base.xlsx
#         data/raw/oil_trade_comtrade.csv (code/cleaning/00f_download_oil_trade.py)
# Output: data/processed/panel_country_year.xlsx
#         data/processed/classification.csv, outputs/results/classification.rds

import os
import subprocess
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

# ----------------------------------------------------------------
# Net oil exporter: PRE-SPECIFIED treatment rule (fixed before estimation,
# quality_reports/plans/2026-09-28_treatment-definition.md). Do not tune it to results.
#   net oil trade = exports - imports of HS 2709 (crude) + HS 2710 (refined products),
#   USD, partner = World, UN Comtrade, averaged over 2015-2019 (years available);
#   net oil exporter iff the average is > 0; time-invariant.
#   Countries with no own report in the window are measured with mirror data
#   (partners' reports). Countries with some own-reported years are averaged over
#   those years only (their mirror rows are not mixed in).
# The criterion is NET exposure to the crude price: a Brent rise raises oil rents of
# net exporters and the import bill of net importers.
# Sensitivity variants (reported, not chosen among): adding gas (HS 2711), a 2019-2021
# window, the previous hand-coded list, and a continuous exposure (% of GDP).
# ----------------------------------------------------------------
TRADE = os.path.join(ROOT, "data", "raw", "oil_trade_comtrade.csv")
tr = pd.read_csv(TRADE)
tr["neto"] = tr["value_usd"] * tr["flow"].map({"X": 1, "M": -1})

# Documented exception (decided by the author after the download showed no data):
# Puerto Rico is neither a Comtrade reporter nor a partner (code 842 "USA" covers the
# USA, Puerto Rico and the US Virgin Islands), so neither own nor mirror data exist.
# It is classified as a net oil IMPORTER from an outside source: it has no crude oil
# production and no operating refinery (the last refineries closed in the 2000s) and
# imports all refined products -- U.S. Energy Information Administration, Puerto Rico
# territory energy profile, https://www.eia.gov/state/print.php?sid=RQ.
# Its net oil trade stays NA (not 0); it is an importer in every binary variant and
# drops out of the continuous-exposure variant.
EXTERNAL_IMPORTERS = {"PRI"}


def posicion_neta(cmds, anios):
    """Average net trade (USD) per country over `anios` for commodities `cmds`.
    Returns iso, net_usd, source (own|mirror), n_years; raises if a country has no data."""
    w = tr[tr.year.isin(anios) & tr.cmd.isin(cmds)]
    # A year is own-reported when both flows come from the country's own report
    own_y = (w[w.source == "own"].groupby(["iso", "year"]).flow.nunique()
             .loc[lambda s: s == 2].reset_index()[["iso", "year"]])
    filas, sin_datos = [], []
    for iso, g in w.groupby("iso"):
        if iso in EXTERNAL_IMPORTERS:
            filas.append({"iso": iso, "net_usd": float("nan"), "source": "external",
                          "n_years": 0})
            continue
        anios_own = set(own_y.year[own_y.iso == iso])
        if anios_own:
            g = g[g.year.isin(anios_own) & (g.source == "own")]
            fuente = "own"
        else:
            g = g[g.source == "mirror"]
            fuente = "mirror"
            # Mirror rows with no reporting partner at all = no data (not zero trade)
            if g.n_partners.fillna(0).sum() == 0:
                sin_datos.append(iso)
                continue
        anual = g.groupby("year").neto.sum()
        filas.append({"iso": iso, "net_usd": anual.mean(), "source": fuente,
                      "n_years": anual.size})
    if sin_datos:
        raise SystemExit(
            f"STOP: no own or mirror oil trade data in {min(anios)}-{max(anios)} for "
            f"{sorted(sin_datos)}; the pre-specified rule cannot classify them. "
            "Decide how to handle them before continuing (see data/raw/SOURCES.md).")
    return pd.DataFrame(filas)


PRE = range(2015, 2020)
main = posicion_neta([2709, 2710], PRE)
gas  = posicion_neta([2709, 2710, 2711], PRE)
r1921 = posicion_neta([2709, 2710], range(2019, 2022))
assert set(main.iso) == set(df.iso), "every panel country must be classified"

# Previous hand-coded list (kept only as a sensitivity variant)
EXPORTADORES_MANUAL = {"VEN", "ECU", "COL", "MEX", "TTO", "BOL", "GUY"}

# Average nominal GDP 2015-2019 (IMF, USD bn; mean over available years)
gdp_1519 = df[df.anio.isin(PRE)].groupby("iso").gdp.mean()

clasif = (main.rename(columns={"net_usd": "net_oil_trade_usd_1519",
                               "source": "data_source", "n_years": "n_years_1519"})
          .merge(gas[["iso", "net_usd"]].rename(columns={"net_usd": "net_oil_gas_trade_usd_1519"}),
                 on="iso")
          .merge(r1921[["iso", "net_usd", "source"]]
                 .rename(columns={"net_usd": "net_oil_trade_usd_1921",
                                  "source": "data_source_1921"}), on="iso"))
clasif["net_oil_trade_gdp_1519"] = (clasif.net_oil_trade_usd_1519
                                    / (clasif.iso.map(gdp_1519) * 1e9) * 100)
ext = clasif.iso.isin(EXTERNAL_IMPORTERS)                          # importer in every variant
clasif["exportador_neto"]   = (clasif.net_oil_trade_usd_1519 > 0) & ~ext   # MAIN rule
clasif["exportador_gas"]    = (clasif.net_oil_gas_trade_usd_1519 > 0) & ~ext
clasif["exportador_1921"]   = (clasif.net_oil_trade_usd_1921 > 0) & ~ext
clasif["exportador_manual"] = clasif.iso.isin(EXPORTADORES_MANUAL)
pais = df.drop_duplicates("iso").set_index("iso").pais
clasif.insert(1, "country", clasif.iso.map(pais))
clasif = (clasif.sort_values("net_oil_trade_usd_1519", ascending=False, na_position="last")
          .reset_index(drop=True))
# Only the external-source countries may lack a net trade value
assert set(clasif.iso[clasif.net_oil_trade_usd_1519.isna()]) == EXTERNAL_IMPORTERS
assert set(clasif.iso[clasif.net_oil_trade_gdp_1519.isna()]) == EXTERNAL_IMPORTERS

VARS_CLASIF = ["net_oil_trade_usd_1519", "net_oil_trade_gdp_1519", "exportador_neto",
               "exportador_manual", "exportador_gas", "exportador_1921"]
df = df.merge(clasif[["iso"] + VARS_CLASIF], on="iso", how="left")
assert df.exportador_neto.notna().all() and df.exportador_neto.dtype == bool

print("Classification (pre-specified rule: HS 2709+2710, mean 2015-2019 > 0):")
print(clasif.assign(net_bn=lambda x: (x.net_oil_trade_usd_1519 / 1e9).round(3),
                    net_gdp=lambda x: x.net_oil_trade_gdp_1519.round(2))
      [["iso", "net_bn", "net_gdp", "data_source", "n_years_1519", "exportador_neto",
        "exportador_gas", "exportador_1921", "exportador_manual"]].to_string(index=False))
print("Switch vs hand-coded list:",
      sorted(clasif.iso[clasif.exportador_neto != clasif.exportador_manual]), "\n")

# Per-country classification table -> outputs/results/classification.rds
# (written through Rscript, which the analysis already requires)
RES = os.path.join(ROOT, "outputs", "results")
os.makedirs(RES, exist_ok=True)
csv_tmp = os.path.join(PROC, "classification.csv")
clasif.to_csv(csv_tmp, index=False)
rds = os.path.join(RES, "classification.rds")
subprocess.run(["Rscript", "-e",
                f"d <- read.csv('{csv_tmp}', stringsAsFactors = FALSE); "
                f"for (v in grep('^exportador', names(d), value = TRUE)) d[[v]] <- as.logical(d[[v]]); "
                f"saveRDS(d, '{rds}')"], check=True)
print(f"Classification saved to {rds} (and {csv_tmp})\n")

print(f"Analysis panel: {df.shape[0]} rows × {df.shape[1]} columns")
print(f"Net exporters: {df[df.exportador_neto].iso.nunique()} countries | "
      f"importers: {df[~df.exportador_neto].iso.nunique()}")
print(df[["iso", "anio", "exportador_neto", "subsidio_pc_usd", "expl_share",
          "brecha_gso", "brecha_die"]].head(), "\n")

df.to_excel(os.path.join(PROC, "panel_country_year.xlsx"), index=False)
print("Panel saved to data/processed/panel_country_year.xlsx")
