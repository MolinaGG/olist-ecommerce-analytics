-- ============================================================================
-- Olist E-Commerce Analytics
-- 03_views/dim_tables.sql
--
-- Purpose: Dimension views for the Power BI Star Schema.
-- dim_date is generated via a non-recursive "tally table" technique
-- (cross-joined digit sets) instead of a recursive CTE, to avoid MySQL's
-- default cte_max_recursion_depth limit (1000) for a ~1,096-day range.
-- ============================================================================

USE olist_ecommerce;

-- ----------------------------------------------------------------------------
-- DIM_DATE
-- Covers 2016-01-01 through 2018-12-31 (the full Olist dataset range, with
-- a small buffer). date_key format: YYYYMMDD (integer), for easy joining.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW dim_date AS
WITH digits AS (
    SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9
),
numbers AS (
    SELECT d1.n + d2.n * 10 + d3.n * 100 + d4.n * 1000 AS num
    FROM digits d1
    CROSS JOIN digits d2
    CROSS JOIN digits d3
    CROSS JOIN digits d4
),
date_seq AS (
    SELECT DATE_ADD('2016-01-01', INTERVAL num DAY) AS full_date
    FROM numbers
    WHERE DATE_ADD('2016-01-01', INTERVAL num DAY) <= '2018-12-31'
)
SELECT
    CAST(DATE_FORMAT(full_date, '%Y%m%d') AS UNSIGNED) AS date_key,
    full_date,
    YEAR(full_date)                                    AS year,
    QUARTER(full_date)                                 AS quarter,
    MONTH(full_date)                                   AS month,
    MONTHNAME(full_date)                                AS month_name,
    DAYOFMONTH(full_date)                               AS day_of_month,
    DAYNAME(full_date)                                  AS day_name,
    DAYOFWEEK(full_date)                                AS day_of_week,
    CASE WHEN DAYOFWEEK(full_date) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM date_seq;

-- ----------------------------------------------------------------------------
-- DIM_CUSTOMER
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW dim_customer AS
SELECT
    customer_id          AS customer_key,
    customer_unique_id,
    customer_city         AS city,
    customer_state         AS state
FROM customers;

-- ----------------------------------------------------------------------------
-- DIM_SELLER
-- Enriched with the executive segment_tier computed in vw_supplier_performance,
-- so Power BI can slice/filter by Gold Partner / Regular Operation /
-- Operational Risk directly from the seller dimension.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW dim_seller AS
SELECT
    s.seller_id                                          AS seller_key,
    s.seller_city                                         AS city,
    s.seller_state                                         AS state,
    COALESCE(sp.supplier_segment, 'No Fulfilled Orders')  AS segment_tier
FROM sellers s
LEFT JOIN vw_supplier_performance sp
    ON s.seller_id = sp.seller_id;

-- ----------------------------------------------------------------------------
-- DIM_PRODUCT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW dim_product AS
SELECT
    product_id                                             AS product_key,
    COALESCE(product_category_name_english, 'unknown')     AS category_name_en
FROM products;

-- ----------------------------------------------------------------------------
-- DIM_GEOGRAPHY
-- One row per Brazilian state seen anywhere in the dataset (customers OR
-- sellers), enriched with macro-region -- same mapping used in
-- vw_logistics_regional, kept consistent across the model.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW dim_geography AS
SELECT DISTINCT
    state AS state_key,
    CASE state
        WHEN 'AC' THEN 'Norte' WHEN 'AP' THEN 'Norte' WHEN 'AM' THEN 'Norte'
        WHEN 'PA' THEN 'Norte' WHEN 'RO' THEN 'Norte' WHEN 'RR' THEN 'Norte'
        WHEN 'TO' THEN 'Norte'
        WHEN 'AL' THEN 'Nordeste' WHEN 'BA' THEN 'Nordeste' WHEN 'CE' THEN 'Nordeste'
        WHEN 'MA' THEN 'Nordeste' WHEN 'PB' THEN 'Nordeste' WHEN 'PE' THEN 'Nordeste'
        WHEN 'PI' THEN 'Nordeste' WHEN 'RN' THEN 'Nordeste' WHEN 'SE' THEN 'Nordeste'
        WHEN 'DF' THEN 'Centro-Oeste' WHEN 'GO' THEN 'Centro-Oeste'
        WHEN 'MT' THEN 'Centro-Oeste' WHEN 'MS' THEN 'Centro-Oeste'
        WHEN 'ES' THEN 'Sudeste' WHEN 'MG' THEN 'Sudeste'
        WHEN 'RJ' THEN 'Sudeste' WHEN 'SP' THEN 'Sudeste'
        WHEN 'PR' THEN 'Sul' WHEN 'RS' THEN 'Sul' WHEN 'SC' THEN 'Sul'
        ELSE 'Unknown'
    END AS region
FROM (
    SELECT customer_state AS state FROM customers
    UNION
    SELECT seller_state FROM sellers
) all_states
WHERE state IS NOT NULL;

-- ============================================================================
-- Quick validation queries (run manually):
-- SELECT COUNT(*) FROM dim_date;          -- expected ~1096
-- SELECT COUNT(*) FROM dim_customer;       -- expected ~99441
-- SELECT COUNT(*) FROM dim_seller;         -- expected ~3095
-- SELECT COUNT(*) FROM dim_product;        -- expected ~32951
-- SELECT COUNT(*) FROM dim_geography;      -- expected 27
-- SELECT segment_tier, COUNT(*) FROM dim_seller GROUP BY segment_tier;
-- ============================================================================