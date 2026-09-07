# Genie Setup — Sales & Revenue Slice (Olist)

Reproducibility record for the Databricks-native Genie agent covering the
Sales & Revenue vertical (Q1–Q7). Genie configuration lives in the
Databricks workspace and cannot be pushed to Git; this file is the
source of truth for rebuilding it. SQL logic itself is NOT duplicated
here — it lives in the `.sql` files referenced below.

## 1. Agent identity

- Title: `Retail Sales & Revenue`
- Compute: serverless SQL warehouse (Free Edition single 2X-Small).
- Domain: Olist Brazilian e-commerce, Gold layer only.

## 2. Sources (Configure → Sources)

All six Gold tables from `retail_demo.gold`:

- `fact_orders` (1 row/order)
- `fact_order_items` (1 row/order item)
- `fact_payments` (1 row/payment)
- `dim_customer` (1 row/customer_id)
- `dim_product` (1 row/product)
- `dim_seller` (1 row/seller)

Note: `dim_seller` is attached but unused by this slice. No instruction
references it. It stays inert until the seller-analytics slice.

## 3. Instructions (Configure → Instructions, single text block)

```
SALES DATE
- The sales/purchase date is always fact_orders.order_purchase_timestamp.
- Never use order_approved_at, order_delivered_carrier_date,
  order_delivered_customer_date, or order_estimated_delivery_date
  for period filtering unless the user explicitly names one of them.

REVENUE
- Revenue is always SUM(fact_payments.payment_value), linked to orders
  through order_id.
- Never use fact_order_items.price or fact_order_items.freight_value
  as revenue. Those are separate measures.

ORDERS
- An order count is always COUNT(DISTINCT fact_orders.order_id).
- Never count rows from fact_order_items or fact_payments.

AOV
- Average Order Value is Revenue divided by distinct orders computed
  over the same order population. AOV over an empty set is NULL.

DATE RANGES
- A selected end date is inclusive for the full calendar day
  (up to but not including midnight of the next day).

JOIN SAFETY
- An order can have multiple items and multiple payments.
- Never join fact_order_items to fact_payments at row level and then
  sum payment values; that fan-out overstates revenue.
- Category labels: prefer product_category_name_english, fall back to
  product_category_name, then 'UNKNOWN'. Never drop null categories.

CUSTOMERS
- customer_unique_id is the real customer identity for customer-level
  analysis; customer_id identifies the order's customer record and is
  the join key to dim_customer.
```

## 4. Examples (Configure → Examples → Add → Example query)

Title is the natural-language question; code is the referenced repo file
pasted verbatim with `:start_date` / `:end_date` markers intact.

| # | Title | Code source |
|---|-------|-------------|
| 1 | What is the total revenue for a selected date range? | `revenue.sql` |
| 2 | How does revenue trend over time? | `revenue_trend.sql` |
| 3 | How many orders were placed in a selected period? | `order_count.sql` |
| 4 | What is the average order value for a selected period? | `aov.sql` |
| 5 | Which product categories generate the most revenue? | `category_revenue.sql` |
| 6 | Which product categories have the highest order volume? | `category_order_volume.sql` |
| 7 | Which customer states generate the most revenue? | `state_revenue.sql` |

Usage guidance on #5 only:

```
Use this query when revenue is broken down by product category.
Each order's total payment_value is allocated across its items in
proportion to item price. Never join fact_order_items to fact_payments
at row level and sum payment values — that fan-out overstates revenue.
Category labels prefer product_category_name_english, then
product_category_name, then 'UNKNOWN'; null categories are kept, not dropped.
```

## 5. Deliberately deferred (not configured in this pass)

Specified but left unentered; add in a later curation pass without
re-deriving:

- Measures: `Revenue` = `SUM(payment_value)` on `fact_payments`
  (synonyms: revenue, sales, total sales, turnover);
  `Order count` = `COUNT(DISTINCT order_id)` on `fact_orders`
  (synonyms: orders, order volume, number of orders).
- Fields: `Product category` =
  `COALESCE(product_category_name_english, product_category_name, 'UNKNOWN')`
  on `dim_product`; `Customer state` = `customer_state` on `dim_customer`.
- Joins (many-to-one): `fact_order_items.order_id = fact_orders.order_id`;
  `fact_payments.order_id = fact_orders.order_id`;
  `fact_order_items.product_id = dim_product.product_id`;
  `fact_orders.customer_id = dim_customer.customer_id`.
- Filters: none — nothing in Q1–Q7 needs a reusable boolean condition.

## 6. Verification status (no figures recorded by design)

- Q1 reuse test ("total revenue Jan 2017 → Jan 2018"): PASS — agent
  reproduced the example skeleton with a correct end-inclusive bound.
- Q5 exam ("which product categories generate the most revenue?"):
  PASS — correct answer; agent added an unrequested visual (benign).

## 7. Benchmark set (defined, pending)

~20 chat-mode questions: the 7 canonical questions plus 2–4 paraphrases
each (e.g. "how much money did we make in 2017?", "monthly sales trend",
"avg basket size"), each with the corresponding repo SQL as gold answer.
Not yet run in the Benchmark tab.

## 8. Free Edition caveats

- ~20 questions/min UI throughput; pace benchmark runs accordingly.
- Daily serverless quota can halt the agent until the next day; a sudden
  stop mid-testing indicates quota, not config error.
