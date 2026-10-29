# PhonePe Pulse: Digital Payments Analytics (India, 2018 – 2026)

An end-to-end analytics project on PhonePe's open **Pulse** data: how digital payments grew across India's states and districts, who the users and merchants are, and where the growth is slowing. Built as a practice project covering the full analyst toolchain: **Python (data flattening), Excel, Power Query, MySQL, Power BI and Tableau**.

> **Project status**
>
> | Stage | Status |
> |---|---|
> | JSON → flat tables (Python) | Done |
> | Excel profiling + Power Query modelling | Done |
> | MySQL analysis (14 business queries) | Done |
> | Power BI dashboard | In progress |
> | Tableau dashboard | Planned |

---

## Business questions

1. How fast has PhonePe payment volume and value grown, year by year and quarter by quarter?
2. Which states and districts drive the most value, and how concentrated is it?
3. Is the average payment getting bigger or smaller?
4. Which states have many registered users but low engagement?
5. How are payment categories (P2P, Retail, Utility) shifting over time?
6. How does value per registered merchant vary across states?

## Key findings

All figures come from the queries in [`sql/02_business_queries.sql`](sql/02_business_queries.sql).

- **Total volume, 2018 to Q2 2026: ₹587.26 lakh crore** across all states and union territories.
- **Growth is slowing.** Payment value grew about **37%** in 2024 (94.6 → 129.7 lakh crore) but about **20%** in 2025 (→ 155.4). Transaction count grew about 29% in 2025. On a like-for-like basis, H1 2026 is up **17.4% in value** but **23.5% in transactions** versus H1 2025.
- **Payments are getting smaller.** The average payment peaked at **₹1,827 in 2020** and fell to **₹1,187 in 2026 H1** (about −35%), consistent with more people making more small payments.
- **COVID shows in the data.** 2020 Q2 fell **10.6%** versus the previous quarter, the first quarterly decline in the series.
- **Concentration.** In 2025, Maharashtra (11.75%), Karnataka (11.55%) and Telangana (10.89%) together made up about **34%** of PhonePe's payment value, and the top five states about **53%**.
- **Bengaluru Urban is the largest district** at about ₹7.9 lakh crore in 2025, more than twice Pune (second), and about **44% of Karnataka's** value. In Telangana, the three districts around Hyderabad (Rangareddy, Medchal Malkajgiri, Hyderabad) account for about **53%** of the state.
- **Users ≠ engagement.** Uttar Pradesh has the most registered users (90.6M) but ranks 17th of 36 in transactions per user; Tamil Nadu is 7th in users but 28th in engagement; Telangana is 9th in users but 1st in engagement (about 106 transactions per registered user in 2026 Q2).
- **Fast growth is from small bases.** Meghalaya (+42.8%), Manipur (+39.6%) and Lakshadweep (+34.5%) grew fastest in 2025 versus 2024 against about 20% nationally, but these are small states.
- **Category mix:** Utility payments rose from **3.5% of transactions in 2018 to 11.1% in 2020**, while P2P fell from 47.3% to 43.5%.

*Shares and rankings describe **PhonePe's own** data, not the whole Indian digital-payments market.*

## Data

| | |
|---|---|
| **Source** | [PhonePe Pulse](https://github.com/PhonePe/pulse) (open data published by PhonePe) |
| **License** | CDLA-Permissive-2.0, credit PhonePe |
| **Coverage** | Q1 2018 to Q2 2026 (34 quarters), 36 states and union territories, about 780 districts |
| **Contents** | Transaction count and ₹ amount (state and district); transaction count by category (P2P, Retail, Utility; state level, count only); registered users; registered merchants |
| **Nature** | Aggregated and anonymised. There are no individual transactions. |

The raw data is nested JSON (11,184 files). [`scripts/flatten_pulse_json.py`](scripts/flatten_pulse_json.py) converts it into 7 flat tables, which are then modelled in Power Query into the 4 cleaned tables in [`data/cleaned/`](data/cleaned/).

## Data model

| Table | Rows | Grain |
|---|---|---|
| `fact_state` | 1,224 | state × quarter: txn count, ₹ amount, registered users, registered merchants, avg payment, ₹ crore, txns per user |
| `fact_district` | 26,616 | state × district × quarter, same measures |
| `fact_category` | 3,671 | state × quarter × category: txn count |
| `dim_period` | 34 | quarter: label (e.g. `2024 Q1`), quarter-end date, sort key |

Columns added in Power Query: `avg_txn_value`, `amount_crore`, `txn_per_user`, `period`.

## Workflow

1. **Flatten:** Python script turns the JSON into 7 CSVs (reproduces the same files every run).
2. **Excel:** profile each table (row counts, types, blanks, pivots).
3. **Power Query:** clean text, set types, build `dim_period`, merge transactions with users and merchants on **state + district + year + quarter**, add derived columns.
4. **MySQL:** create tables, load CSVs (`LOAD DATA`, blank merchants stored as `NULL`), validate, then answer the business questions with joins, CTEs, `LAG`, `RANK` and window-function shares.
5. **Power BI / Tableau:** dashboards on the cleaned tables *(in progress)*.

## Data quality checks

| Check | Result |
|---|---|
| Blanks, zeros, negatives in any source table | None |
| Duplicate rows (same state / district / period) | None |
| District totals vs state totals | Match exactly in every state-quarter |
| Category totals (P2P + Retail + Utility) vs state totals | Match exactly |
| State names across tables | Same 36 everywhere |
| Merchant data | Missing for 46 state-quarters (almost all 2018) and 1,879 district-quarters (1,730 in 2018). Kept as `NULL`, not filled with 0. |
| Districts with users but no transactions | 6 district-quarters (2018) |
| SQL load check | 1,224 / 26,616 / 3,671 / 34 rows; 46 and 1,879 `NULL` merchant rows as expected |
| Grand total | ₹587.26 lakh crore in both `fact_state` and `fact_district` |

## Things to know before using the numbers

- **Registered users and merchants are running totals**, not per-quarter figures. They are never summed across quarters; the latest quarter is used.
- **2026 is a half year** (Q1 and Q2 only), so it is compared with H1 2025, not with full-year 2025.
- **Three district names repeat across states** (Bilaspur, Hamirpur, Pratapgarh), so every join and group uses state + district.
- **Merchant analysis is reliable from 2019 onward.**
- **Transactions per user** = one quarter's transactions ÷ all registered users, so inactive users pull the figure down.
- **Value per merchant** includes person-to-person payments, so it is a rough indicator, not true merchant sales.
- Category data has counts only, not rupee amounts.


## How to reproduce

1. Download the PhonePe Pulse data from https://github.com/PhonePe/pulse and unzip it to `data/phonepe_pulse/`.
2. Flatten the JSON: `python scripts/flatten_pulse_json.py data/phonepe_pulse/data data/flat` (needs `pandas`).
3. Model the tables in Power Query as described above, or skip to step 4 and use the ready tables in `data/cleaned/`.
4. In MySQL 8.0+, run `sql/01_setup.sql` (edit the `LOAD DATA` paths to your `secure_file_priv` folder), then `sql/02_business_queries.sql`.

## Tools

Python (pandas), Excel, Power Query, MySQL 8.0, Power BI, Tableau

## Author

**Rahul Ballidav**, aspiring data analyst, Bengaluru.
LinkedIn:linkedin.com/in/rahulballidav07  GitHub: https://github.com/rahulmatrix10

*Data: PhonePe Pulse, © PhonePe, used under CDLA-Permissive-2.0.*
