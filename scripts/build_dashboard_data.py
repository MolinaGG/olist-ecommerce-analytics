"""Rebuild the anonymized browser dataset from the pinned original CSVs."""
import json, hashlib
from pathlib import Path
import pandas as pd
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'dashboard'
DEST.mkdir(exist_ok=True)
VALIDATION=ROOT/'validation';VALIDATION.mkdir(exist_ok=True)
def read(name,**kw):return pd.read_csv(ROOT/'data'/f'olist_{name}_dataset.csv',**kw)
orders=read('orders'); customers=read('customers'); items=read('order_items'); products=read('products'); reviews=read('order_reviews')
assert orders.order_id.is_unique and customers.customer_id.is_unique and products.product_id.is_unique
# Keep the latest review record per order; never join review rows to item rows.
reviews=reviews.sort_values(['review_answer_timestamp','review_creation_date','review_id'],kind='stable',na_position='first').drop_duplicates('order_id',keep='last')
orders=orders.merge(customers[['customer_id','customer_state']],on='customer_id',validate='many_to_one').merge(reviews[['order_id','review_score']],on='order_id',how='left',validate='one_to_one')
items=items.merge(products[['product_id','product_category_name']],on='product_id',how='left',validate='many_to_one')
items.product_category_name=items.product_category_name.fillna('sem_categoria')
for col in ['price','freight_value']:items[col]=(items[col]*100).round().astype(int)
categories=sorted(items.product_category_name.unique().tolist());states=sorted(orders.customer_state.unique().tolist());statuses=sorted(orders.order_status.unique().tolist());sellers=sorted(items.seller_id.unique().tolist())
ci={v:i for i,v in enumerate(categories)};si={v:i for i,v in enumerate(states)};ti={v:i for i,v in enumerate(statuses)};vi={v:i for i,v in enumerate(sellers)}
months=pd.period_range(pd.to_datetime(orders.order_purchase_timestamp).min().to_period('M'),pd.to_datetime(orders.order_purchase_timestamp).max().to_period('M'),freq='M').astype(str).tolist();mi={v:i for i,v in enumerate(months)}
by_order={}
for r in items.itertuples(index=False):by_order.setdefault(r.order_id,[]).append([ci[r.product_category_name],vi[r.seller_id],r.price,r.freight_value])
rows=[];no_items=0
for r in orders.itertuples(index=False):
 its=by_order.get(r.order_id)
 if not its:no_items+=1;continue
 purchase=pd.Timestamp(r.order_purchase_timestamp);delivery=pd.to_datetime(r.order_delivered_customer_date);estimate=pd.to_datetime(r.order_estimated_delivery_date)
 valid=r.order_status=='delivered' and pd.notna(delivery) and pd.notna(estimate)
 # Calendar-day comparison: arriving on the promised day is on time.
 late=int(delivery.normalize()>estimate.normalize()) if valid else None
 lead=round((delivery-purchase).total_seconds()/86400,4) if valid and delivery>=purchase else None
 score=None if pd.isna(r.review_score) else int(r.review_score)
 rows.append([mi[str(purchase.to_period('M'))],si[r.customer_state],ti[r.order_status],lead,late,score,its])
payload={'version':1,'sourceCommit':'cf8524a59b856e684d6538aa3f7c524e15438b43','source':'https://github.com/MolinaGG/olist-ecommerce-analytics','months':months,'states':states,'statuses':statuses,'categories':categories,'sellerCount':len(sellers),'excludedNoItems':no_items,'rows':rows}
path=DEST/'data.json';path.write_text(json.dumps(payload,separators=(',',':'),ensure_ascii=False,allow_nan=False),encoding='utf-8')
summary={'orders':len(rows),'productsCents':int(items.price.sum()),'freightCents':int(items.freight_value.sum()),'items':len(items),'deliveredWithDates':sum(r[4] is not None for r in rows),'late':sum(r[4]==1 for r in rows),'reviewedOrders':sum(r[5] is not None for r in rows),'excludedNoItems':no_items,'jsonBytes':path.stat().st_size}
summary['sla']=1-summary['late']/summary['deliveredWithDates']
assert sum(sum(it[2] for it in r[6]) for r in rows)==summary['productsCents']
assert sum(sum(it[3] for it in r[6]) for r in rows)==summary['freightCents']
(VALIDATION/'reference.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
(VALIDATION/'source-hashes.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'data').glob('*.csv')},indent=2),encoding='utf8')
print(json.dumps(summary))
