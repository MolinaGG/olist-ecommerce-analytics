# Medidas do Power BI revisado

As medidas financeiras preservam os nomes internos originais para manter os vínculos dos visuais. A documentação histórica anterior está em [`docs/dax_measures_original.md`](../docs/dax_measures_original.md).

`olist_orders_enriched` contém uma linha por pedido com itens: entrega válida, atraso por dia de calendário, cancelamento, duração em dias corridos e última nota de avaliação. As medidas usam os pedidos visíveis em `fact_orders` para filtrar essa tabela com TREATAS.

```dax
Delivered Orders Valid =
VAR Ids = VALUES(fact_orders[order_id])
RETURN CALCULATE(COUNTROWS(olist_orders_enriched),
    TREATAS(Ids, olist_orders_enriched[order_id]),
    olist_orders_enriched[delivered_valid] = 1)

Delayed Orders =
VAR Ids = VALUES(fact_orders[order_id])
RETURN CALCULATE(COUNTROWS(olist_orders_enriched),
    TREATAS(Ids, olist_orders_enriched[order_id]),
    olist_orders_enriched[delivered_valid] = 1,
    olist_orders_enriched[is_late] = 1)

SLA % (On-Time Delivery) =
DIVIDE([Delivered Orders Valid] - [Delayed Orders], [Delivered Orders Valid])

Delay Rate % = DIVIDE([Delayed Orders], [Delivered Orders Valid])

Avg Lead Time (Days) =
VAR Ids = VALUES(fact_orders[order_id])
RETURN CALCULATE(AVERAGE(olist_orders_enriched[lead_time_days]),
    TREATAS(Ids, olist_orders_enriched[order_id]),
    olist_orders_enriched[delivered_valid] = 1)

Avg Review Score =
VAR Ids = VALUES(fact_orders[order_id])
RETURN CALCULATE(AVERAGE(olist_orders_enriched[review_score]),
    TREATAS(Ids, olist_orders_enriched[order_id]))

Total Reviews =
VAR Ids = VALUES(fact_orders[order_id])
RETURN CALCULATE(COUNT(olist_orders_enriched[review_score]),
    TREATAS(Ids, olist_orders_enriched[order_id]))

Total Sellers = DISTINCTCOUNT(fact_orders[seller_key])
Total Revenue = SUM(fact_orders[price])
Total Freight = SUM(fact_orders[freight_value])
Total Orders = DISTINCTCOUNT(fact_orders[order_id])
Avg Ticket = DIVIDE([Total Revenue], [Total Orders])
```

`Revenue at Risk` mantém a expressão original sobre os flags de `fact_orders`, agora reconstruídos com a mesma regra por dia de calendário. O rótulo público é **Valor com ocorrência**: atraso e cancelamento não comprovam perda financeira.

Na matriz financeira, os visuais usam `SUM(vw_financial_health[total_revenue])` e `SUM(vw_financial_health[revenue_at_risk])`, em vez de medidas globais desconectadas da categoria. O percentual somável da matriz original foi removido para evitar um total inválido.

Os snapshots `vw_*` representam todo o período. São agregações pré-calculadas, não medidas que reclassificam fornecedores em qualquer recorte temporal. A versão web recalcula os segmentos no recorte atual.
