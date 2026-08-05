-- ============================================================================
-- Olist E-Commerce Analytics
-- 03_views/vw_logistics_regional.sql
--
-- Purpose: Measure delivery lead time, on-time performance, and freight cost
-- by customer state/region, using CTEs + window functions. Feeds Power BI
-- directly -- no business logic should be recalculated on the BI side.
--
-- Grain: one row per Brazilian state (customer_state), aggregated from
-- order-level metrics.
-- ============================================================================

USE olist_ecommerce;

CREATE OR REPLACE VIEW vw_logistics_regional AS

-- ----------------------------------------------------------------------------
-- CTE 1: order_freight
-- Total freight and item revenue per order (order_items is item-grain,
-- orders is order-grain -- aggregate up before joining).
-- ----------------------------------------------------------------------------
WITH order_freight AS (
    SELECT
        order_id,
        SUM(price)          AS order_revenue,
        SUM(freight_value)  AS order_freight_value
    FROM order_items
    GROUP BY order_id
),

-- ----------------------------------------------------------------------------
-- CTE 2: order_logistics
-- One row per delivered order, with lead time and delay computed.
-- Only orders that actually reached the customer are counted here --
-- undelivered/cancelled orders have no meaningful lead time.
-- ----------------------------------------------------------------------------
order_logistics AS (
    SELECT
        o.order_id,
        c.customer_state,
        ofr.order_revenue,
        ofr.order_freight_value,
        DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS lead_time_days,
        DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delay_days,
        CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
            ELSE 0
        END AS is_delayed
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    JOIN order_freight ofr
        ON o.order_id = ofr.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),

-- ----------------------------------------------------------------------------
-- CTE 3: state_metrics
-- Aggregate logistics KPIs per state.
-- ----------------------------------------------------------------------------
state_metrics AS (
    SELECT
        customer_state,
        COUNT(*)                                   AS total_delivered_orders,
        ROUND(AVG(lead_time_days), 1)               AS avg_lead_time_days,
        ROUND(AVG(delay_days), 1)                   AS avg_delay_days,
        ROUND(SUM(is_delayed) / COUNT(*), 4)        AS pct_delayed,
        ROUND(AVG(order_freight_value), 2)          AS avg_freight_value,
        ROUND(SUM(order_revenue), 2)                AS total_revenue,
        ROUND(AVG(order_freight_value / NULLIF(order_revenue, 0)), 4) AS avg_freight_to_revenue_ratio
    FROM order_logistics
    GROUP BY customer_state
)

-- ----------------------------------------------------------------------------
-- Final SELECT: macro-region enrichment, window-function ranking/benchmarks,
-- and a risk classification per state.
-- ----------------------------------------------------------------------------
SELECT
    customer_state,

    -- Brazilian macro-region enrichment (dimension enrichment via CASE)
    CASE customer_state
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
    END AS region,

    total_delivered_orders,
    avg_lead_time_days,
    avg_delay_days,
    pct_delayed,
    avg_freight_value,
    total_revenue,
    avg_freight_to_revenue_ratio,

    -- Ranking: fastest average lead time first (1 = fastest state in Brazil)
    DENSE_RANK() OVER (
        ORDER BY avg_lead_time_days ASC
    ) AS lead_time_rank,

    -- Ranking within the state's own macro-region
    DENSE_RANK() OVER (
        PARTITION BY CASE customer_state
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
        END
        ORDER BY avg_lead_time_days ASC
    ) AS lead_time_rank_in_region,

    -- National benchmarks (same value on every row -- for BI comparison)
    ROUND(AVG(avg_lead_time_days) OVER (), 1) AS national_avg_lead_time_days,
    ROUND(AVG(pct_delayed)        OVER (), 4) AS national_avg_pct_delayed,

    -- How many days this state deviates from the national average lead time
    ROUND(avg_lead_time_days - AVG(avg_lead_time_days) OVER (), 1) AS lead_time_vs_national_avg,

    -- Operational risk classification
    CASE
        WHEN pct_delayed <= 0.08 AND avg_lead_time_days <= 12 THEN 'Efficient Region'
        WHEN pct_delayed <= 0.20 AND avg_lead_time_days <= 20 THEN 'Moderate Delay Region'
        ELSE 'High Risk Region'
    END AS logistics_risk_tier

FROM state_metrics;

-- ============================================================================
-- Quick validation queries (run manually, not part of the view):
--
-- SELECT logistics_risk_tier, COUNT(*) AS states, ROUND(AVG(avg_lead_time_days),1) AS avg_lead_time
-- FROM vw_logistics_regional
-- GROUP BY logistics_risk_tier
-- ORDER BY avg_lead_time DESC;
--
-- SELECT region, ROUND(AVG(avg_freight_to_revenue_ratio),4) AS avg_freight_ratio
-- FROM vw_logistics_regional
-- GROUP BY region
-- ORDER BY avg_freight_ratio DESC;
-- ============================================================================