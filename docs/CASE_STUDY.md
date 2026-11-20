# Case study: delivery performance as a BI problem

[Português](CASE_STUDY.pt-BR.md) · [Dashboard](https://guilherme-molina-portfolio.guilhermemolinasolan.chatgpt.site/olist/) · [Project](../README.md)

## Problem and audience

An operations or finance analyst needs to distinguish delivery-performance signals from the monetary value associated with orders. The question is where to investigate, not how much money was definitively lost.

## Data and method

The public Olist dataset covers 2016–2018. The revised pipeline uses Python to prepare web and Power BI snapshots. SQL from the original pipeline is preserved as a separate historical implementation.

Orders may contain multiple items, categories and suppliers. Item values are additive; order counts across categories are not. Reviews are deduplicated to the latest record per order. Delivery rates use delivered orders with valid dates and compare calendar days. These choices prevent a multi-item order from receiving extra weight in delivery and satisfaction metrics.

## Findings and interpretation

The documented baseline has 98,666 orders with items. Of 96,470 valid deliveries, 6,534 were late, giving 93.2269% on-time delivery. Product value totals BRL 13,591,643.70 excluding freight. These describe the dataset, not financial performance achieved for a client.

The dashboard provides regional, category and supplier views for investigation. Compare sample sizes and delivery denominators before ranking groups. A supplier's shared order review does not establish its individual responsibility for a problem.

## What a reviewer can verify

| Evidence | File |
| --- | --- |
| Data preparation and exclusions | [build_dashboard_data.py](../scripts/build_dashboard_data.py) |
| Power BI data preparation | [build_powerbi_data.py](../scripts/build_powerbi_data.py) |
| Aggregation logic | [metrics.js](../dashboard/metrics.js) |
| Granularity, filters and reference totals | [metrics.test.cjs](../tests/metrics.test.cjs) |
| Definitions and Power BI limitations | [METHODOLOGY.md](METHODOLOGY.md) |

## Limitations and contribution discussion

This is an independent portfolio study using historical data. It does not establish an Olist engagement, operating savings, recognized revenue, profit or causal relationships. Power BI aggregate snapshots do not all recalculate by month like the web application.

In an interview, the useful walkthrough is the path from source CSVs to a displayed metric: explain the unit of analysis, exclusions, denominator, validation and trade-offs. Repository history supports the implementation discussion; a screenshot alone does not establish personal authorship or independence from AI assistance.
