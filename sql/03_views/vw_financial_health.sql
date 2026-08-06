-- ============================================================================
-- Olist E-Commerce Analytics
-- 03_views/vw_financial_health.sql
--
-- Purpose: Revenue, average ticket, freight cost and revenue-at-risk
-- (cancelled or late-delivered orders) per product category, using CTEs +
-- window functions. Feeds Power BI directly -- no business logic should be
-- recalculated on the BI side.
--
-- Grain: one row per product category (product_category_name_english).
-- ============================================================================

USE olist_ecommerce;

CREATE OR REPLACE VIEW vw_financial_health AS

-- ----------------------------------------------------------------------------
-- CTE 1: order_category_base
-- One row per (order, category) combination -- an order can touch more than
-- one category, so revenue is attributed at the item level and rolled up.
-- ----------------------------------------------------------------------------
WITH order_category_base AS (
    SELECT
        oi.order_id,
        COALESCE(p.product_category_name_english, 'unknown') AS category,
        o.order_status,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        oi.price,
        oi.freight_value,
        CASE WHEN o.order_status = 'canceled' THEN 1 ELSE 0 END AS is_cancelled,
        CASE
            WHEN o.order_delivered_customer_date IS NOT NULL
                 AND o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 1 ELSE 0
        END AS is_late
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
),

-- ----------------------------------------------------------------------------
-- CTE 2: category_financials
-- Aggregate revenue, freight, order counts and at-risk revenue per category.
-- "At risk" = revenue tied to orders that were cancelled or delivered late --
-- money the business effectively lost or nearly lost to a service failure.
-- ----------------------------------------------------------------------------
category_financials AS (
    SELECT
        category,
        COUNT(DISTINCT order_id)                                   AS total_orders,
        ROUND(SUM(price), 2)                                       AS total_revenue,
        ROUND(SUM(freight_value), 2)                                AS total_freight,
        ROUND(SUM(price) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS avg_ticket,
        ROUND(SUM(CASE WHEN is_cancelled = 1 OR is_late = 1 THEN price ELSE 0 END), 2)
                                                                     AS revenue_at_risk,
        ROUND(
            SUM(CASE WHEN is_cancelled = 1 OR is_late = 1 THEN price ELSE 0 END)
            / NULLIF(SUM(price), 0), 4
        )                                                            AS pct_revenue_at_risk,
        SUM(is_cancelled)                                           AS cancelled_items,
        SUM(is_late)                                                AS late_delivered_items
    FROM order_category_base
    GROUP BY category
)

-- ----------------------------------------------------------------------------
-- Final SELECT: window functions for ranking, distribution and benchmarking.
-- ----------------------------------------------------------------------------
SELECT
    category,
    total_orders,
    total_revenue,
    total_freight,
    avg_ticket,
    revenue_at_risk,
    pct_revenue_at_risk,
    cancelled_items,
    late_delivered_items,

    -- Revenue ranking across all categories (1 = highest-earning category)
    RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_rank,

    -- Percentile position by revenue (0 = smallest, 1 = largest category)
    ROUND(PERCENT_RANK() OVER (ORDER BY total_revenue), 4) AS revenue_percentile,

    -- Revenue quartile: 1 = top 25% of categories by revenue
    NTILE(4) OVER (ORDER BY total_revenue DESC) AS revenue_quartile,

    -- Company-wide benchmarks (same value on every row -- for BI comparison)
    ROUND(AVG(avg_ticket) OVER (), 2)          AS company_avg_ticket,
    ROUND(AVG(pct_revenue_at_risk) OVER (), 4) AS company_avg_pct_revenue_at_risk,

    -- Financial health classification per category
    CASE
        WHEN pct_revenue_at_risk >= 0.15 THEN 'High Financial Risk'
        WHEN pct_revenue_at_risk >= 0.07 THEN 'Moderate Financial Risk'
        ELSE 'Financially Healthy'
    END AS financial_health_tier

FROM category_financials;

-- ============================================================================
-- Quick validation queries (run manually, not part of the view):
--
-- SELECT financial_health_tier, COUNT(*) AS categories,
--        ROUND(SUM(total_revenue),2) AS total_revenue,
--        ROUND(SUM(revenue_at_risk),2) AS total_revenue_at_risk
-- FROM vw_financial_health
-- GROUP BY financial_health_tier
-- ORDER BY total_revenue DESC;
--
-- SELECT category, total_revenue, revenue_at_risk, financial_health_tier
-- FROM vw_financial_health
-- ORDER BY revenue_rank
-- LIMIT 10;
-- ============================================================================