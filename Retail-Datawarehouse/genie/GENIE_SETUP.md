# Genie Setup — Retail Data Warehouse (Olist)

Reproducibility record for the Databricks Genie agent. Genie configuration
lives in the Databricks workspace and cannot be pushed to Git; this file is
the source of truth for rebuilding it. SQL logic itself is NOT duplicated
here — it lives in the `sql/` files referenced below.

## 1. Agent identity

- Title: `Retail Sales & Revenue` (expand title/scope as further slices are added)
- Compute: serverless SQL warehouse
- Domain: Olist Brazilian e-commerce, Gold layer only (`retail_demo.gold`)

## 2. Sources (Configure → Sources)

Six Gold tables plus two Bronze supplements (8 sources total). Gold is
authoritative for all locked metrics; the Bronze tables cover attributes not
(yet) promoted to Gold:

- `retail_demo.gold.fact_orders` (1 row/order)
- `retail_demo.gold.fact_order_items` (1 row/order item)
- `retail_demo.gold.fact_payments` (1 row/payment)
- `retail_demo.gold.dim_customer` (1 row/customer_id)
- `retail_demo.gold.dim_product` (1 row/product)
- `retail_demo.gold.dim_seller` (1 row/seller)
- `retail_demo.bronze.customers_raw` (supplement — raw customer attributes absent from Gold)
- `retail_demo.bronze.geolocation_raw` (supplement — geolocation was deliberately excluded from Gold)

Rule: metric questions (revenue, orders, AOV, customers) must resolve against
Gold per §3. Bronze supplements are for descriptive attributes only, never for
measures.

Key joins (many-to-one):

- `fact_order_items.order_id = fact_orders.order_id`
- `fact_payments.order_id = fact_orders.order_id`
- `fact_order_items.product_id = dim_product.product_id`
- `fact_orders.customer_id = dim_customer.customer_id`

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

## 4. Curated SQL examples (Configure → Examples → Add → Example query)

Title is the natural-language question; code is the referenced repo file
pasted verbatim with `:start_date` / `:end_date` markers intact.

### Sales & Revenue (`sql/sales_revenue/`)

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

### Customer (`sql/customer_analytics/`)

| # | Title | Code source |
|---|-------|-------------|
| 1 | How many unique customers purchased during a selected period? | `unique_customers.sql` |
| 2 | What percentage of customers are repeat customers? | `repeat_customer_rate.sql` |
| 3 | What is the distribution of customers by order frequency? | `customer_order_frequency.sql` |
| 4 | How much revenue comes from repeat vs one-time customers? | `repeat_vs_one_time_revenue.sql` |
| 5 | How many new customers did we acquire over time? | `new_customers_trend.sql` |

### Product (`sql/product_analytics/`)

| Title | Code source |
|-------|-------------|
| For each product category, which product has the highest quantity sold? | `top_product_by_category.sql` |
| How many distinct products are there in each product category? | `product_count_by_category.sql` |
| Which product categories have the highest item sales value? | `item_sales_value_by_category.sql` |
| How many distinct products and categories are in the catalog? | `catalog_size.sql` |

### Seller (`sql/seller_analytics/`)

| Title | Code source |
|-------|-------------|
| How many sellers operate in each state? | `seller_count_by_state.sql` |
| Which sellers fulfill the highest number of distinct orders? | `seller_order_volume.sql` |
| Which sellers have the highest number of items sold? | `seller_item_volume.sql` |
| Which sellers have the highest item sales value? | `seller_item_sales_value.sql` |
| How many distinct products does each seller sell? | `seller_product_assortment.sql` |
| What is the average observed selling price by seller? | `seller_average_selling_price.sql` |

### Payment (`sql/payment_analytics/`)

| Title | Code source |
|-------|-------------|
| What percentage of orders are associated with each payment method? | `payment_method_usage.sql` |
| How are payment records distributed across installment ranges? | `installment_distribution.sql` |
| How does payment-method usage change over time? | `payment_method_usage_trend.sql` |
| How many payment records does each order contain? | `payments_per_order_distribution.sql` |

### Delivery (`sql/delivery_operations/`)

| Title | Code source |
|-------|-------------|
| What percentage of delivered orders reached the customer by the estimated date? | `on_time_delivery_rate.sql` |
| How has the average delivery time changed over time? | `average_delivery_time_trend.sql` |
| How has the volume of late deliveries changed over time? | `late_delivery_volume_trend.sql` |
| What is the distribution of orders across order statuses? | `order_status_distribution.sql` |
| How does delivery performance vary across sellers? | `seller_delivery_performance.sql` |

### Geographic (`sql/geographic_analytics/`)

| Title | Code source |
|-------|-------------|
| How are customers distributed across states? | `customer_distribution_by_state.sql` |
| How does freight value vary across customer geographies? | `freight_value_by_customer_state.sql` |
| How does delivery performance vary across customer geographies? | `delivery_performance_by_customer_state.sql` |
| How concentrated are orders and customers across states? | `order_customer_concentration_by_state.sql` |

## 5. Parameter convention

All date-range examples use Databricks SQL named Date parameters:

- `:start_date` — inclusive first calendar day
- `:end_date` — inclusive last calendar day

With the inclusive-end pattern:

```sql
WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
  AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
```

Do not invent other parameter syntax.

## 6. Rebuild steps

1. Create/verify the Genie space with the identity in §1.
2. Attach the six sources in §2.
3. Paste the single instruction block from §3.
4. Add example queries from §4 (paste file contents verbatim).
5. Test with one canonical question per slice before trusting the agent.
