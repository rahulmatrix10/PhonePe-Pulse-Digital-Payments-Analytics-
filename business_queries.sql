-- =====================================================================
-- PhonePe Pulse Analytics: business queries
-- Units: 1 crore = 10,000,000 (1e7);  1 lakh crore = 1e12 rupees
-- Notes:
--   * 2026 has only Q1 and Q2, so it is never compared with a full year.
--   * registered_users / registered_merchants are running totals:
--     never SUM them across quarters, use one quarter (e.g. the latest).
--   * registered_merchants is NULL where the source has no data (mostly 2018).
-- =====================================================================
USE phonepe_project;

-- Q1. Yearly growth: transactions and value
SELECT year,
       SUM(txn_count) AS transactions,
       ROUND(SUM(txn_amount_inr)/1000000000000, 2) AS amount_lakh_crore
FROM fact_state
GROUP BY year
ORDER BY year;

-- Q2. Quarter-over-quarter growth in transactions (LAG window function)
WITH q AS (
  SELECT year, quarter, period, SUM(txn_count) AS txns
  FROM fact_state
  GROUP BY year, quarter, period
)
SELECT period, txns,
       ROUND(100 * (txns - LAG(txns) OVER (ORDER BY year, quarter))
             / LAG(txns) OVER (ORDER BY year, quarter), 1) AS qoq_growth_pct
FROM q
ORDER BY year, quarter;

-- Q3. Top 10 states in 2025 with share of total PhonePe value
SELECT state,
       SUM(txn_count) AS transactions,
       ROUND(SUM(txn_amount_inr)/10000000) AS amount_crore,
       ROUND(100 * SUM(txn_amount_inr) / SUM(SUM(txn_amount_inr)) OVER (), 2) AS pct_share
FROM fact_state
WHERE year = 2025
GROUP BY state
ORDER BY SUM(txn_amount_inr) DESC
LIMIT 10;

-- Q4. Fastest-growing states by value, 2025 vs 2024 (both full years)
WITH y AS (
  SELECT state, year, SUM(txn_amount_inr) AS amt
  FROM fact_state
  WHERE year IN (2024, 2025)
  GROUP BY state, year
)
SELECT state,
       ROUND(100 * (MAX(CASE WHEN year = 2025 THEN amt END)
                  / MAX(CASE WHEN year = 2024 THEN amt END) - 1), 1) AS yoy_growth_pct
FROM y
GROUP BY state
ORDER BY yoy_growth_pct DESC
LIMIT 10;

-- Q5. Payment category mix by year (P2P / Retail / Utility, by count)
SELECT year, category,
       SUM(txn_count) AS transactions,
       ROUND(100 * SUM(txn_count) / SUM(SUM(txn_count)) OVER (PARTITION BY year), 1) AS pct_of_year
FROM fact_category
GROUP BY year, category
ORDER BY year, category;

-- Q6. Top 10 districts in 2025 (group by state AND district)
SELECT state, district,
       ROUND(SUM(txn_amount_inr)/10000000) AS amount_crore
FROM fact_district
WHERE year = 2025
GROUP BY state, district
ORDER BY SUM(txn_amount_inr) DESC
LIMIT 10;

-- Q7. Biggest district in each state, 2025 (RANK window function)
WITH d AS (
  SELECT state, district, SUM(txn_amount_inr) AS amt
  FROM fact_district
  WHERE year = 2025
  GROUP BY state, district
), r AS (
  SELECT *, RANK() OVER (PARTITION BY state ORDER BY amt DESC) AS rk
  FROM d
)
SELECT state, district, ROUND(amt/10000000) AS amount_crore
FROM r
WHERE rk = 1
ORDER BY amt DESC;

-- Q8. Transactions per registered user by state, latest quarter (2026 Q2)
SELECT state, txn_per_user, avg_txn_value
FROM fact_state
WHERE year = 2026 AND quarter = 2
ORDER BY txn_per_user DESC;

-- Q9. Registered merchants and users by state, latest quarter (running totals)
SELECT state, registered_merchants, registered_users
FROM fact_state
WHERE year = 2026 AND quarter = 2
ORDER BY registered_merchants DESC
LIMIT 10;

-- Q10. Like-for-like: first half of 2025 vs first half of 2026
SELECT year, SUM(txn_count) AS transactions,
       ROUND(SUM(txn_amount_inr)/1000000000000, 2) AS lakh_crore
FROM fact_state
WHERE quarter IN (1, 2) AND year IN (2025, 2026)
GROUP BY year;

-- Q11. Average payment size by year (weighted: total amount / total count)
SELECT year, ROUND(SUM(txn_amount_inr)/SUM(txn_count), 0) AS avg_payment_inr
FROM fact_state
GROUP BY year
ORDER BY year;

-- Q12. Users vs engagement rank, latest quarter
WITH latest AS (
  SELECT state, registered_users, txn_per_user
  FROM fact_state WHERE year = 2026 AND quarter = 2
)
SELECT state, registered_users, txn_per_user,
       RANK() OVER (ORDER BY registered_users DESC) AS user_rank,
       RANK() OVER (ORDER BY txn_per_user DESC) AS engagement_rank
FROM latest
ORDER BY registered_users DESC
LIMIT 10;

-- Q13. How concentrated is each state on its biggest district? (2025)
--      States with fewer than 5 districts are excluded: a single-district
--      state is trivially 100%.
WITH d AS (
  SELECT state, district, SUM(txn_amount_inr) AS amt
  FROM fact_district WHERE year = 2025
  GROUP BY state, district
),
r AS (
  SELECT state, district, amt,
         SUM(amt) OVER (PARTITION BY state) AS state_amt,
         RANK() OVER (PARTITION BY state ORDER BY amt DESC) AS rk,
         COUNT(*) OVER (PARTITION BY state) AS n_districts
  FROM d
)
SELECT state, district, n_districts,
       ROUND(100 * amt / state_amt, 1) AS top_district_share_pct
FROM r
WHERE rk = 1 AND n_districts >= 5
ORDER BY top_district_share_pct DESC
LIMIT 10;

-- Q14. 2025 value per registered merchant (merchants at end of 2025)
--      Caveat: amounts include person-to-person payments, so this is a rough
--      indicator, not true merchant sales.
SELECT a.state, ROUND(a.amt/10000000) AS amount_crore, m.registered_merchants,
       ROUND(a.amt / m.registered_merchants / 100000, 1) AS lakh_per_merchant
FROM (SELECT state, SUM(txn_amount_inr) AS amt
      FROM fact_state WHERE year = 2025 GROUP BY state) a
JOIN fact_state m ON m.state = a.state AND m.year = 2025 AND m.quarter = 4
ORDER BY lakh_per_merchant DESC
LIMIT 10;
