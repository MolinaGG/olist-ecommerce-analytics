# DAX Measures — Olist E-Commerce Analytics

All measures live in a dedicated `_Measures` table (best practice: measures are not attached to any single fact table, since several combine data from both `fact_orders` and `fact_reviews`). Grouped by business pillar.

---

## 💰 Financial Health

| Measure | DAX | Business meaning |
|---|---|---|
| `Total Revenue` | `SUM(fact_orders[price])` | Gross merchandise revenue (excludes freight) |
| `Total Freight` | `SUM(fact_orders[freight_value])` | Total freight cost across all order items |
| `Total Orders` | `DISTINCTCOUNT(fact_orders[order_id])` | Distinct order count (fact_orders is item-grain, so this de-duplicates) |
| `Avg Ticket` | `DIVIDE([Total Revenue], [Total Orders])` | Average order value |
| `Revenue at Risk` | `CALCULATE([Total Revenue], FILTER(fact_orders, fact_orders[is_delayed] = 1 \|\| fact_orders[is_cancelled] = 1))` | Revenue tied to items in delayed or cancelled orders — money lost or nearly lost |
| `% Revenue at Risk` | `DIVIDE([Revenue at Risk], [Total Revenue])` | Same, as a share of total revenue |
| `Freight % of Revenue` | `DIVIDE([Total Freight], [Total Revenue])` | Freight cost efficiency indicator |

## 🚚 Logistics Efficiency

| Measure | DAX | Business meaning |
|---|---|---|
| `Avg Lead Time (Days)` | `AVERAGEX(SUMMARIZE(fact_orders, fact_orders[order_id], "OrderLeadTime", AVERAGE(fact_orders[lead_time_days])), [OrderLeadTime])` | Average purchase-to-delivery time, computed at **order grain** (not item grain, to avoid over-weighting multi-item orders) |
| `Delayed Orders` | `CALCULATE(DISTINCTCOUNT(fact_orders[order_id]), fact_orders[is_delayed] = 1)` | Count of distinct orders delivered after the estimated date |
| `SLA % (On-Time Delivery)` | `1 - DIVIDE([Delayed Orders], [Total Orders])` | The headline SLA metric |
| `Delay Rate %` | `DIVIDE([Delayed Orders], [Total Orders])` | Inverse of SLA %, useful for risk-framed visuals |
| `Cancelled Orders` | `CALCULATE(DISTINCTCOUNT(fact_orders[order_id]), fact_orders[is_cancelled] = 1)` | Count of distinct cancelled orders |
| `Cancellation Rate %` | `DIVIDE([Cancelled Orders], [Total Orders])` | Share of orders cancelled |

## ⭐ Supplier Quality

| Measure | DAX | Business meaning |
|---|---|---|
| `Avg Review Score` | `AVERAGE(fact_reviews[review_score])` | Average customer satisfaction (1–5) |
| `Total Reviews` | `COUNTROWS(fact_reviews)` | Review volume |
| `Avg Response Time (Days)` | `AVERAGE(fact_reviews[response_time_days])` | How fast sellers/platform respond to reviews |
| `Total Sellers` | `DISTINCTCOUNT(dim_seller[seller_key])` | Active seller count (dimension-level, unaffected by fact filters) |
| `Gold Partners` | `CALCULATE(DISTINCTCOUNT(dim_seller[seller_key]), dim_seller[segment_tier] = "Gold Partner")` | Count of top-tier sellers, per the SQL-computed segmentation |
| `% Gold Partners` | `DIVIDE([Gold Partners], [Total Sellers])` | Share of the seller base in the top tier |
| `Operational Risk Sellers` | `CALCULATE(DISTINCTCOUNT(dim_seller[seller_key]), dim_seller[segment_tier] = "Operational Risk")` | Count of sellers flagged as operational risk |

---

## Design notes

- **All business logic (segmentation, ranking, risk classification) lives in SQL**, not DAX — `dim_seller[segment_tier]` is populated from `vw_supplier_performance.supplier_segment`, computed with `DENSE_RANK()`/`CASE` in MySQL. DAX measures here only aggregate and format; they never recalculate what the SQL layer already decided.
- `Avg Lead Time (Days)` intentionally uses `SUMMARIZE` + `AVERAGEX` instead of a flat `AVERAGE(fact_orders[lead_time_days])`, because `fact_orders` is at **item grain**: a naive average would let orders with more line items pull the number disproportionately. Computing the average at order grain first avoids that bias.
- `fact_orders` × `fact_reviews` has an **inactive relationship** on `order_id` in the model (both tables already connect through `dim_date` and `dim_seller`). No measure here uses `USERELATIONSHIP()` yet — reserved for a future cross-fact metric if needed (e.g., "average review score of orders delayed by more than 5 days").
- Percentage measures (`SLA %`, `% Revenue at Risk`, etc.) should be formatted as percentage in the Power BI field properties, not multiplied by 100 in DAX.