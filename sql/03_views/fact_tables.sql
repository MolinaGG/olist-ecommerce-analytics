-- ============================================================================
-- Olist E-Commerce Analytics
-- 03_views/fact_tables.sql
--
-- Purpose: Fact views for the Power BI Star Schema. Two facts at different
-- grains, as defined in ARCHITECTURE.md:
--   - fact_orders  : order-item grain (financial/logistics)
--   - fact_reviews : review grain (quality)
--
-- These connect to dim_customer, dim_seller, dim_product, dim_date and
-- dim_geography (via dim_seller.state / dim_customer.state).
-- ============================================================================

USE olist_ecommerce;

-- ----------------------------------------------------------------------------
-- FACT_ORDERS
-- Grain: one row per order item. date_key uses the purchase date.
-- is_delayed / is_cancelled are pre-computed flags so Power BI DAX measures
-- (e.g. SLA %) don't need to recalculate business logic.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW fact_orders AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id                                              AS product_key,
    oi.seller_id                                                AS seller_key,
    o.customer_id                                                AS customer_key,
    CAST(DATE_FORMAT(o.order_purchase_timestamp, '%Y%m%d') AS UNSIGNED) AS date_key,
    oi.price,
    oi.freight_value,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
             AND o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN 1 ELSE 0
    END                                                          AS is_delayed,
    CASE WHEN o.order_status = 'canceled' THEN 1 ELSE 0 END      AS is_cancelled,
    DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS lead_time_days
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id;

-- ----------------------------------------------------------------------------
-- FACT_REVIEWS
-- Grain: one row per review. date_key uses the review creation date.
--
-- Modeling assumption: when an order has items from multiple sellers (rare
-- in this dataset), the review is attributed to that order's LOWEST
-- seller_id (a deterministic, arbitrary tie-break) rather than duplicating
-- the review across every seller -- this keeps fact_reviews at a true
-- one-row-per-review grain, unlike vw_supplier_performance which
-- intentionally fans reviews out across sellers for aggregate scoring.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW fact_reviews AS
SELECT
    r.review_id,
    r.order_id,
    os.seller_key,
    CAST(DATE_FORMAT(r.review_creation_date, '%Y%m%d') AS UNSIGNED) AS date_key,
    r.review_score,
    DATEDIFF(r.review_answer_timestamp, r.review_creation_date) AS response_time_days
FROM order_reviews r
LEFT JOIN (
    SELECT order_id, MIN(seller_id) AS seller_key
    FROM order_items
    GROUP BY order_id
) os
    ON r.order_id = os.order_id;

-- ============================================================================
-- Quick validation queries (run manually):
-- SELECT COUNT(*) FROM fact_orders;    -- expected ~112650 (order_items row count)
-- SELECT COUNT(*) FROM fact_reviews;   -- expected ~98410 (post-dedup order_reviews count)
-- SELECT COUNT(*) FROM fact_reviews WHERE seller_key IS NULL;  -- should be 0 or very low
-- SELECT ROUND(SUM(is_delayed)/COUNT(*),4) AS overall_delay_rate FROM fact_orders;
-- ============================================================================