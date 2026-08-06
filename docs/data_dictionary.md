# Data Dictionary — Olist E-Commerce Analytics

This document describes every table and analytical view in the `olist_ecommerce` MySQL database: grain, columns, types, and business meaning. Views are the single source of truth for business logic — Power BI consumes them directly and does not recalculate any of the metrics documented here.

---

## 1. Core Tables (Schema Layer)

### `customers`
Grain: one row per unique customer address record (`customer_id`). Note that `customer_unique_id` can repeat across rows — the same real person can have multiple `customer_id` values, one per order placed.

| Column | Type | Description |
|---|---|---|
| `customer_id` | VARCHAR(32) PK | Unique per order/checkout instance |
| `customer_unique_id` | VARCHAR(32) | Stable identifier for the actual person across orders |
| `customer_zip_code_prefix` | VARCHAR(5) | First 5 digits of the customer's ZIP code |
| `customer_city` | VARCHAR(100) | Customer city |
| `customer_state` | CHAR(2) | Customer state (Brazilian UF code, e.g. `SP`, `RJ`) |

### `sellers`
Grain: one row per seller.

| Column | Type | Description |
|---|---|---|
| `seller_id` | VARCHAR(32) PK | Unique seller identifier |
| `seller_zip_code_prefix` | VARCHAR(5) | First 5 digits of the seller's ZIP code |
| `seller_city` | VARCHAR(100) | Seller city |
| `seller_state` | CHAR(2) | Seller state (Brazilian UF code) |

### `products`
Grain: one row per product.

| Column | Type | Description |
|---|---|---|
| `product_id` | VARCHAR(32) PK | Unique product identifier |
| `product_category_name` | VARCHAR(100) | Category name, original Portuguese |
| `product_category_name_english` | VARCHAR(100) | Category name in English — populated in staging via `product_category_name_translation.csv`, not present in the raw products CSV |
| `product_weight_g` | INT | Product weight in grams |
| `product_length_cm` / `product_height_cm` / `product_width_cm` | INT | Product dimensions in centimeters |

### `orders`
Grain: one row per order.

| Column | Type | Description |
|---|---|---|
| `order_id` | VARCHAR(32) PK | Unique order identifier |
| `customer_id` | VARCHAR(32) FK → `customers` | Who placed the order |
| `order_status` | VARCHAR(20) | `delivered`, `shipped`, `canceled`, `unavailable`, `invoiced`, `processing`, `created`, `approved` |
| `order_purchase_timestamp` | DATETIME | When the order was placed |
| `order_approved_at` | DATETIME (nullable) | When payment was approved |
| `order_delivered_carrier_date` | DATETIME (nullable) | When the order was handed to the logistics carrier |
| `order_delivered_customer_date` | DATETIME (nullable) | When the customer actually received the order — **NULL for orders never delivered** |
| `order_estimated_delivery_date` | DATETIME (nullable) | SLA promise shown to the customer at checkout |

### `order_items`
Grain: one row per item line within an order (an order with 3 products has 3 rows here).

| Column | Type | Description |
|---|---|---|
| `order_id` | VARCHAR(32) FK → `orders` | Parent order |
| `order_item_id` | INT | Sequential item number within the order |
| `product_id` | VARCHAR(32) FK → `products` | Which product |
| `seller_id` | VARCHAR(32) FK → `sellers` | Which seller fulfilled this item |
| `shipping_limit_date` | DATETIME (nullable) | Seller's shipping deadline for this item |
| `price` | DECIMAL(10,2) | Item price (excludes freight) |
| `freight_value` | DECIMAL(10,2) | Freight cost allocated to this item |

### `order_payments`
Grain: one row per payment installment/method applied to an order (a single order can have multiple payment rows, e.g. split between credit card and voucher).

| Column | Type | Description |
|---|---|---|
| `order_id` | VARCHAR(32) FK → `orders` | Parent order |
| `payment_sequential` | INT | Order of this payment among multiple payments on the same order |
| `payment_type` | VARCHAR(20) | `credit_card`, `boleto`, `voucher`, `debit_card` |
| `payment_installments` | INT | Number of installments |
| `payment_value` | DECIMAL(10,2) | Amount paid via this payment record |

### `order_reviews`
Grain: one row per customer review. `review_comment_message` is **not stored** (discarded at staging — free-text not needed for this project's KPIs).

| Column | Type | Description |
|---|---|---|
| `review_id` | VARCHAR(32) PK | Unique review identifier |
| `order_id` | VARCHAR(32) FK → `orders` | Which order this review is about |
| `review_score` | INT | 1 (worst) to 5 (best) |
| `review_comment_title` | VARCHAR(255) (nullable) | Optional short review title |
| `review_creation_date` | DATETIME (nullable) | When the review was submitted |
| `review_answer_timestamp` | DATETIME (nullable) | When the seller/platform responded |

> **Not a core table**: `geolocation` (raw CSV) is used only at staging time to enrich city/state lookups and is not persisted as a schema table, keeping the operational schema lean (7 tables instead of 9).

> **Known data quality note**: `olist_order_reviews_dataset.csv` contains ~814 duplicate `review_id` values in the source data. These are silently skipped on load due to the `review_id` primary key constraint — this is expected, not a load failure.

---

## 2. Analytical Views (Business Logic Layer)

### `vw_supplier_performance`
**Grain**: one row per seller. **Pillar**: Supplier Quality.

| Column | Description |
|---|---|
| `seller_id`, `seller_city`, `seller_state` | Seller identity/location |
| `total_orders`, `total_items_sold`, `total_revenue`, `avg_item_price` | Volume and revenue metrics |
| `avg_review_score`, `total_reviews` | Quality signal, attributed via the orders the seller fulfilled |
| `on_time_rate` | Share of orders delivered on or before the estimated date (orders with no delivery outcome yet are excluded from the denominator) |
| `quality_rank` | `DENSE_RANK()` across all sellers, best review score + best SLA first |
| `quality_rank_in_state` | Same ranking, partitioned by `seller_state` |
| `revenue_quartile` | `NTILE(4)` — 1 = top 25% of sellers by revenue |
| `company_avg_review_score`, `company_avg_on_time_rate` | Company-wide benchmarks via `AVG() OVER ()`, repeated on every row |
| `supplier_segment` | `Gold Partner` (score ≥4.5, SLA ≥90%, ≥10 orders) / `Regular Operation` (score ≥3.5, SLA ≥70%) / `Operational Risk` (below both) |

**Modeling assumption**: a review is recorded per order, not per seller. Orders with items from multiple sellers attribute the same review score to every seller involved — a standard simplification for this dataset.

### `vw_logistics_regional`
**Grain**: one row per Brazilian state (`customer_state`). **Pillar**: Logistics Efficiency.

| Column | Description |
|---|---|
| `customer_state`, `region` | State and its macro-region (Norte/Nordeste/Centro-Oeste/Sudeste/Sul), enriched via `CASE` |
| `total_delivered_orders` | Only orders with `order_status = 'delivered'` and a non-null delivery date count here |
| `avg_lead_time_days` | Average days from purchase to customer delivery |
| `avg_delay_days` | Average (actual − estimated) delivery date; positive = late on average |
| `pct_delayed` | Share of orders delivered after the estimated date |
| `avg_freight_value`, `total_revenue`, `avg_freight_to_revenue_ratio` | Financial/logistics cost signal per state |
| `lead_time_rank` | `DENSE_RANK()` nationally, fastest state first |
| `lead_time_rank_in_region` | Same ranking, partitioned by macro-region |
| `national_avg_lead_time_days`, `national_avg_pct_delayed` | National benchmarks via `AVG() OVER ()` |
| `lead_time_vs_national_avg` | This state's deviation (in days) from the national average |
| `logistics_risk_tier` | `Efficient Region` / `Moderate Delay Region` / `High Risk Region`, based on delay rate and lead time thresholds |

### `vw_financial_health`
**Grain**: one row per product category (`product_category_name_english`). **Pillar**: Financial Health.

| Column | Description |
|---|---|
| `category` | English category name (`unknown` if the product had no category in the source data) |
| `total_orders`, `total_revenue`, `total_freight`, `avg_ticket` | Revenue and freight aggregates; `avg_ticket` = total revenue ÷ distinct orders touching this category |
| `revenue_at_risk`, `pct_revenue_at_risk` | Revenue tied to items in **cancelled** or **late-delivered** orders — money effectively lost or nearly lost to a service failure |
| `cancelled_items`, `late_delivered_items` | Raw counts behind the risk metric |
| `revenue_rank` | `RANK()` across all categories by total revenue |
| `revenue_percentile` | `PERCENT_RANK()` — 0 = smallest category, 1 = largest |
| `revenue_quartile` | `NTILE(4)` — 1 = top 25% of categories by revenue |
| `company_avg_ticket`, `company_avg_pct_revenue_at_risk` | Company-wide benchmarks via `AVG() OVER ()` |
| `financial_health_tier` | `Financially Healthy` (<7% at risk) / `Moderate Financial Risk` (7–15%) / `High Financial Risk` (≥15%) |

---

## 3. SQL Techniques Used (for reference)

| Technique | Where used |
|---|---|
| Multiple chained CTEs | All 3 views (5 CTEs in `vw_supplier_performance`, 3 in the other two) |
| `DENSE_RANK() OVER (ORDER BY ...)` | Supplier quality rank, logistics lead time rank |
| `DENSE_RANK() OVER (PARTITION BY ... ORDER BY ...)` | Regional/state-level ranking within a group |
| `RANK() OVER (ORDER BY ...)` | Category revenue rank |
| `PERCENT_RANK() OVER (ORDER BY ...)` | Category revenue percentile |
| `NTILE(4) OVER (ORDER BY ...)` | Revenue quartiles (both supplier and category views) |
| `AVG(...) OVER ()` (no partition) | Company/national benchmarks repeated on every row |
| `CASE` for dimension enrichment | State → macro-region mapping |
| `CASE` for executive segmentation | Supplier tier, logistics risk tier, financial health tier |
| `COALESCE` / `NULLIF` for null-safety | Division-by-zero protection, default category labeling |