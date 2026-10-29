-- =====================================================================
-- PhonePe Pulse Analytics: database setup
-- Run order: 01_setup.sql  ->  02_business_queries.sql
-- Requires MySQL 8.0+ (window functions are used in the queries)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS phonepe_project;
USE phonepe_project;

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS dim_period;
CREATE TABLE dim_period (
  year        SMALLINT,
  quarter     TINYINT,
  period      VARCHAR(8),     -- e.g. '2024 Q1'
  quarter_end DATE,
  period_key  INT,            -- year*10 + quarter, e.g. 20241
  PRIMARY KEY (year, quarter)
);


DROP TABLE IF EXISTS fact_state;
CREATE TABLE fact_state (
  state                VARCHAR(60),
  year                 SMALLINT,
  quarter              TINYINT,
  txn_count            BIGINT,
  txn_amount_inr       DECIMAL(20,2),
  registered_users     BIGINT,                -- running total at quarter end
  registered_merchants BIGINT NULL,           -- running total; NULL = no data in source
  avg_txn_value        DECIMAL(12,2),
  amount_crore         DECIMAL(16,2),
  txn_per_user         DECIMAL(12,4),
  period               VARCHAR(8),
  PRIMARY KEY (state, year, quarter)
);


DROP TABLE IF EXISTS fact_district;
CREATE TABLE fact_district (
  state                VARCHAR(60),
  district             VARCHAR(80),
  year                 SMALLINT,
  quarter              TINYINT,
  txn_count            BIGINT,
  txn_amount_inr       DECIMAL(20,2),
  registered_users     BIGINT,
  registered_merchants BIGINT NULL,
  avg_txn_value        DECIMAL(12,2),
  amount_crore         DECIMAL(16,2),
  txn_per_user         DECIMAL(12,4),
  period               VARCHAR(8),
  -- three district names (Bilaspur, Hamirpur, Pratapgarh) exist in more than
  -- one state, so state + district is the key, never district alone
  PRIMARY KEY (state, district, year, quarter)
);


DROP TABLE IF EXISTS fact_category;
CREATE TABLE fact_category (
  state     VARCHAR(60),
  year      SMALLINT,
  quarter   TINYINT,
  category  VARCHAR(20),      -- P2P / Retail / Utility
  txn_count BIGINT,
  period    VARCHAR(8),
  PRIMARY KEY (state, year, quarter, category)
);


-- ---------------------------------------------------------------------
-- Load the cleaned CSVs
-- 1) Find the folder MySQL is allowed to read from:
--      SHOW VARIABLES LIKE 'secure_file_priv';
-- 2) Copy the four CSVs from data/cleaned/ into that folder.
-- 3) Change the path below (use forward slashes).
-- Blank merchant cells are loaded as NULL (not 0, not dropped).
-- ---------------------------------------------------------------------

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/dim_period.csv'
INTO TABLE dim_period
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(year, quarter, period, quarter_end, period_key);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/fact_state.csv'
INTO TABLE fact_state
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(state, year, quarter, txn_count, txn_amount_inr, registered_users,
 @merch, avg_txn_value, amount_crore, txn_per_user, period)
SET registered_merchants = NULLIF(@merch, '');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/fact_district.csv'
INTO TABLE fact_district
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(state, district, year, quarter, txn_count, txn_amount_inr, registered_users,
 @merch, avg_txn_value, amount_crore, txn_per_user, period)
SET registered_merchants = NULLIF(@merch, '');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/fact_category.csv'
INTO TABLE fact_category
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(state, year, quarter, category, txn_count, period);

-- ---------------------------------------------------------------------
-- Validation (expected results in comments)
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS rows_fact_state    FROM fact_state;      -- 1224
SELECT COUNT(*) AS rows_fact_district FROM fact_district;   -- 26616
SELECT COUNT(*) AS rows_fact_category FROM fact_category;   -- 3671
SELECT COUNT(*) AS rows_dim_period    FROM dim_period;      -- 34
SELECT COUNT(*) AS null_merchants_state    FROM fact_state    WHERE registered_merchants IS NULL;  -- 46
SELECT COUNT(*) AS null_merchants_district FROM fact_district WHERE registered_merchants IS NULL;  -- 1879

-- District totals must equal state totals (both = 587.26 lakh crore)
SELECT ROUND(SUM(txn_amount_inr)/1000000000000, 2) AS total_lakh_crore_state    FROM fact_state;
SELECT ROUND(SUM(txn_amount_inr)/1000000000000, 2) AS total_lakh_crore_district FROM fact_district;
