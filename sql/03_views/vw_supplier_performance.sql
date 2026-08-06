-- ============================================================================
-- Olist E-Commerce Analytics
-- 03_views/vw_supplier_performance.sql
--
-- Purpose: Rank and segment sellers (suppliers) by volume, review quality and
-- on-time delivery rate, using CTEs + window functions. Feeds Power BI
-- directly -- no business logic should be recalculated on the BI side.
--
-- Modeling assumption: a review is recorded per ORDER, not per seller. When
-- an order has items from multiple sellers (rare in this dataset), the same
-- review score is attributed to every seller involved in that order. This is
-- a standard simplification for the Olist dataset and is documented here for
-- transparency.
-- ============================================================================

USE olist_ecommerce;

CREATE OR REPLACE VIEW vw_supplier_performance AS

-- ----------------------------------------------------------------------------
-- CTE 1: seller_orders
-- One row per (seller, order) combination, with delivery timing flags.
-- Cancelled orders are excluded -- they carry no meaningful delivery signal.
-- ----------------------------------------------------------------------------
WITH seller_orders AS (
    SELECT DISTINCT
        oi.seller_id,
        oi.order_id,
        o.order_status,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date,
        CASE
            WHEN o.order_delivered_customer_date IS NOT NULL
                 AND o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 1
            WHEN o.order_delivered_customer_date IS NOT NULL
                 AND o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 0
            ELSE NULL  -- not yet delivered / no estimate: excluded from the SLA rate
        END AS is_on_time
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('cancelled', 'unavailable')
),

-- ----------------------------------------------------------------------------
-- CTE 2: seller_revenue
-- Revenue and item volume per seller (item grain, includes freight).
-- ----------------------------------------------------------------------------
seller_revenue AS (
    SELECT
        oi.seller_id,
        COUNT(*)                           AS total_items_sold,
        COUNT(DISTINCT oi.order_id)        AS total_orders,
        SUM(oi.price)                      AS total_revenue,
        SUM(oi.freight_value)              AS total_freight,
        AVG(oi.price)                      AS avg_item_price
    FROM order_items oi
    GROUP BY oi.seller_id
),

-- ----------------------------------------------------------------------------
-- CTE 3: seller_reviews
-- Average review score per seller (via the orders they fulfilled).
-- ----------------------------------------------------------------------------
seller_reviews AS (
    SELECT
        oi.seller_id,
        AVG(orv.review_score) AS avg_review_score,
        COUNT(orv.review_id)  AS total_reviews
    FROM order_items oi
    JOIN order_reviews orv
        ON oi.order_id = orv.order_id
    GROUP BY oi.seller_id
),

-- ----------------------------------------------------------------------------
-- CTE 4: seller_sla
-- On-time delivery rate per seller (only orders with a known outcome count).
-- ----------------------------------------------------------------------------
seller_sla AS (
    SELECT
        seller_id,
        COUNT(is_on_time)                                   AS orders_with_known_outcome,
        SUM(is_on_time)                                     AS orders_on_time,
        ROUND(SUM(is_on_time) / NULLIF(COUNT(is_on_time), 0), 4) AS on_time_rate
    FROM seller_orders
    GROUP BY seller_id
),

-- ----------------------------------------------------------------------------
-- CTE 5: seller_metrics
-- Join all metrics together into one row per seller, joined to seller location.
-- ----------------------------------------------------------------------------
seller_metrics AS (
    SELECT
        s.seller_id,
        s.seller_city,
        s.seller_state,
        COALESCE(rev.total_orders, 0)        AS total_orders,
        COALESCE(rev.total_items_sold, 0)    AS total_items_sold,
        COALESCE(rev.total_revenue, 0)       AS total_revenue,
        COALESCE(rev.avg_item_price, 0)      AS avg_item_price,
        COALESCE(rvw.avg_review_score, 0)    AS avg_review_score,
        COALESCE(rvw.total_reviews, 0)       AS total_reviews,
        COALESCE(sla.on_time_rate, 0)        AS on_time_rate
    FROM sellers s
    LEFT JOIN seller_revenue rev ON s.seller_id = rev.seller_id
    LEFT JOIN seller_reviews rvw ON s.seller_id = rvw.seller_id
    LEFT JOIN seller_sla     sla ON s.seller_id = sla.seller_id
    WHERE COALESCE(rev.total_orders, 0) > 0  -- exclude sellers with zero fulfilled orders
)

-- ----------------------------------------------------------------------------
-- Final SELECT: window functions for ranking, benchmarking and segmentation
-- ----------------------------------------------------------------------------
SELECT
    seller_id,
    seller_city,
    seller_state,
    total_orders,
    total_items_sold,
    total_revenue,
    avg_item_price,
    avg_review_score,
    total_reviews,
    on_time_rate,

    -- Overall quality ranking across all sellers (best review score + best SLA first)
    DENSE_RANK() OVER (
        ORDER BY avg_review_score DESC, on_time_rate DESC
    ) AS quality_rank,

    -- Ranking within the seller's own state (regional leaderboard)
    DENSE_RANK() OVER (
        PARTITION BY seller_state
        ORDER BY avg_review_score DESC, on_time_rate DESC
    ) AS quality_rank_in_state,

    -- Revenue quartile: 1 = top 25% of sellers by revenue, 4 = bottom 25%
    NTILE(4) OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_quartile,

    -- Company-wide benchmarks (same value on every row -- for BI comparison)
    ROUND(AVG(avg_review_score) OVER (), 2) AS company_avg_review_score,
    ROUND(AVG(on_time_rate)     OVER (), 4) AS company_avg_on_time_rate,

    -- Executive segmentation
    CASE
        WHEN avg_review_score >= 4.5 AND on_time_rate >= 0.90 AND total_orders >= 10
            THEN 'Gold Partner'
        WHEN avg_review_score >= 3.5 AND on_time_rate >= 0.70
            THEN 'Regular Operation'
        ELSE 'Operational Risk'
    END AS supplier_segment

FROM seller_metrics;

-- ============================================================================
-- Quick validation query (run manually, not part of the view):
-- SELECT supplier_segment, COUNT(*) AS sellers, ROUND(AVG(total_revenue),2) AS avg_revenue
-- FROM vw_supplier_performance
-- GROUP BY supplier_segment
-- ORDER BY avg_revenue DESC;
-- ============================================================================