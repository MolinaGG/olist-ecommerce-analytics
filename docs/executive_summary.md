# Executive Summary - Olist Marketplace Analytics

Scope: ~99,000 orders analyzed across logistics, supplier quality, and financial health, using the Olist Brazilian e-commerce dataset (2016-2018).

---

## The Headline

The marketplace generated R$13.59M in revenue at a 92% on-time delivery rate and a 4.09/5 average customer satisfaction score - a fundamentally healthy operation. But two structural risks stand out:

1. 9% of revenue (R$1.25M) is tied to cancelled or late-delivered orders - a direct, quantifiable cost of operational failure.
2. 22% of the seller base (roughly 1 in 5 sellers) is flagged "Operational Risk" - underperforming on either delivery reliability or customer satisfaction, or both.

---

## Financial Health

| Metric | Value |
|---|---|
| Total Revenue | R$13.59M |
| Total Orders | ~99,000 |
| Average Ticket | R$137.75 |
| Revenue at Risk | R$1.25M (9%) |
| Freight Cost | 17% of revenue |

Revenue grew from near-zero in 2016 to ~R$7M in 2018 - a trajectory consistent with the platform's real-world scale-up. The top revenue categories (health & beauty, watches & gifts, home goods, sports & leisure) match Olist's known category mix, a good sanity check on the pipeline's correctness.

## Logistics Efficiency

| Metric | Value |
|---|---|
| Avg. Lead Time | 12.5 days |
| On-Time Delivery (SLA) | 92% |
| Delay Rate | 8% |

The Southeast region (Sudeste) - Brazil's most populous and commercially dense area - carries the largest order volume and the best delivery efficiency. Smaller-volume regions (North, parts of the Northeast) show proportionally higher delay rates, a pattern consistent with longer shipping distances and less carrier density.

## Supplier Quality

| Segment | Share of Sellers |
|---|---|
| Regular Operation | 72.7% |
| Operational Risk | 22.2% |
| Gold Partner | 5.1% |

Segmentation is computed directly in SQL from review score, on-time delivery rate, and order volume - not a subjective label. The ~1-in-5 sellers in "Operational Risk" represent the clearest, most actionable target for a supplier improvement program.

---

## What This Project Demonstrates

- Relational database design: a lean, normalized 7-table MySQL schema built from raw CSVs, with explicit data-quality checks (duplicate keys, referential integrity, out-of-range values).
- Advanced SQL: multi-CTE analytical views combining window functions (DENSE_RANK, RANK, PERCENT_RANK, NTILE, AVG() OVER ()) to produce ranking, benchmarking, and executive segmentation - entirely in the database layer.
- Dimensional modeling: a Star Schema (5 dimensions, 2 fact tables at different grains) designed for Power BI performance and flexibility.
- BI storytelling: a 4-page executive dashboard translating raw operational data into decisions a marketplace operator could act on this week.

Full technical documentation, SQL scripts, and the interactive dashboard are available in the project repository.