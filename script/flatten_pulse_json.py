"""
Flatten PhonePe Pulse JSON into 7 flat CSV tables.

Usage (from the repo root):
    python scripts/flatten_pulse_json.py <path to pulse/data folder> <output folder>
Example:
    python scripts/flatten_pulse_json.py data/phonepe_pulse/data data/flat

Source: https://github.com/PhonePe/pulse  (CDLA-Permissive-2.0)
"""
import glob
import json
import os
import sys

import pandas as pd

DATA = sys.argv[1] if len(sys.argv) > 1 else "data/phonepe_pulse/data"
OUT = sys.argv[2] if len(sys.argv) > 2 else "data/flat"
os.makedirs(OUT, exist_ok=True)


def title_state(s):
    """andaman-&-nicobar-islands -> Andaman & Nicobar Islands"""
    return " ".join(w if w == "&" else w.capitalize() for w in s.replace("-", " ").split())


def clean_district(s):
    """'bagalkote district' -> 'Bagalkote'"""
    s = s.strip()
    if s.endswith(" district"):
        s = s[:-9]
    return " ".join(w if w == "&" else w.capitalize() for w in s.split())


def year_quarter(path):
    parts = path.replace("\\", "/").split("/")
    return int(parts[-2]), int(parts[-1].split(".")[0])


def state_of(path):
    return title_state(path.replace("\\", "/").split("/")[-3])


def files(pattern):
    return glob.glob(os.path.join(DATA, pattern))


# 1. District transactions (count + amount)
rows = []
for f in files("map/transaction/hover/country/india/state/*/*/*.json"):
    y, q = year_quarter(f)
    s = state_of(f)
    for x in json.load(open(f))["data"]["hoverDataList"]:
        m = x["metric"][0]
        rows.append((s, clean_district(x["name"]), y, q, m["count"], m["amount"]))
district_txn = pd.DataFrame(rows, columns=["state", "district", "year", "quarter", "txn_count", "txn_amount_inr"])

# 2. State transactions (count + amount)
rows = []
for f in files("map/transaction/hover/country/india/*/*.json"):
    y, q = year_quarter(f)
    for x in json.load(open(f))["data"]["hoverDataList"]:
        m = x["metric"][0]
        rows.append((title_state(x["name"]), y, q, m["count"], m["amount"]))
state_txn = pd.DataFrame(rows, columns=["state", "year", "quarter", "txn_count", "txn_amount_inr"])

# 3. State transactions by category (count only)
rows = []
for f in files("aggregated/transaction/country/india/state/*/*/*.json"):
    y, q = year_quarter(f)
    s = state_of(f)
    for c in json.load(open(f))["data"]["transactionData"]:
        for pi in c["paymentInstruments"]:
            rows.append((s, y, q, c["name"], pi["count"]))
state_cat = pd.DataFrame(rows, columns=["state", "year", "quarter", "category", "txn_count"])


# 4/6. District registered users / merchants
def district_hover(pattern, col):
    rows = []
    for f in files(pattern):
        y, q = year_quarter(f)
        s = state_of(f)
        for name, v in json.load(open(f))["data"]["hoverData"].items():
            rows.append((s, clean_district(name), y, q, v["registeredCount"]))
    return pd.DataFrame(rows, columns=["state", "district", "year", "quarter", col])


district_users = district_hover("map/user/hover/country/india/state/*/*/*.json", "registered_users")
district_merch = district_hover("map/merchant/hover/country/india/state/*/*/*.json", "registered_merchants")


# 5/7. State registered users / merchants
def state_agg(pattern, col):
    rows = []
    for f in files(pattern):
        y, q = year_quarter(f)
        rows.append((state_of(f), y, q, json.load(open(f))["data"]["aggregated"]["registeredCount"]))
    return pd.DataFrame(rows, columns=["state", "year", "quarter", col])


state_users = state_agg("aggregated/user/country/india/state/*/*/*.json", "registered_users")
state_merch = state_agg("aggregated/merchant/country/india/state/*/*/*.json", "registered_merchants")

tables = {
    "district_transactions": district_txn,
    "state_transactions": state_txn,
    "state_txn_category": state_cat,
    "district_users": district_users,
    "state_users": state_users,
    "district_merchants": district_merch,
    "state_merchants": state_merch,
}
for name, df in tables.items():
    keys = [c for c in ("state", "district", "year", "quarter", "category") if c in df.columns]
    df = df.sort_values(keys).reset_index(drop=True)
    df.to_csv(os.path.join(OUT, name + ".csv"), index=False)
    print(f"{name}: {len(df):,} rows")
