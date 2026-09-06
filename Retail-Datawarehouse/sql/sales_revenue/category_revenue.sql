-- Q5 — Revenue by Product Category
-- Business question: Which product categories generate the most revenue?
-- Result: one row per product category with attributed revenue,DESC order.
--
-- THE ATTRIBUTION PROBLEM (read before changing this query):
--   * Revenue lives at payment grain (fact_payments, 1..N rows per order).
--   * Category lives at item grain (fact_order_items -> dim_product).
--   * A naive fact_orders -> fact_order_items -> fact_payments join creates an
--     items x payments fan-out (e.g. 3 items x 2 payments = 6 rows) and
--     multiplies payment_value. NEVER sum payment_value across that join.
--
-- CHOSEN ASSUMPTION (documented, defensible):
--   * Each order's total payment value (SUM of its payment_value rows) is
--     allocated across its items IN PROPORTION TO ITEM PRICE (oi.price).
--     Allocated item revenue = order_revenue * (item_price / order_price).
--   * Rationale: price-proportional split preserves the locked revenue
--     definition (totals reconcile exactly to Q1 revenue for the same period)
--     while giving a sensible category share. Equal-split would ignore that
--     items have very different prices; full-attribution to every category
--     would double-count.
--   * Freight is EXCLUDED from the allocation weight (weight = price only);
--     revenue allocated is still payment_value, per the locked definition.
--   * Fallback: if an order's total item price is 0/NULL (should not happen
--     in Olist, guarded anyway), payment is split EQUALLY across its items.
--   * Orders with no order-item rows cannot be attributed and are excluded
--     from this breakdown (see validation V5 for the reconciliation check).
--
-- Category label: prefer the English translation, fall back to the original
-- Portuguese name, then 'UNKNOWN' (Gold keeps 620 null-category products via
-- LEFT JOIN at build time, so nulls are expected and preserved, not dropped).
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day
-- SUM(price) by category is simpler because it never leaves item grain — but it answers "item sales," not "Revenue = payment_value." Crossing from payment grain to item grain requires an allocation assumption; proportional-to-price keeps every query's totals reconciled under one definition.

WITH filtered_orders AS (
    -- Same order population as Q1/Q3/Q4: purchased in range.
    SELECT
        o.order_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
),
order_revenue AS (
    -- One row per order: total payment_value (no item join -> no fan-out).
    SELECT
        fo.order_id,
        SUM(p.payment_value) AS order_revenue
    FROM filtered_orders AS fo
    JOIN retail_demo.gold.fact_payments AS p
        ON fo.order_id = p.order_id
    GROUP BY fo.order_id
),
order_totals AS (
    -- One row per order: total item price + item count (allocation basis).
    SELECT
        fo.order_id,
        SUM(oi.price) AS order_price,
        COUNT(*) AS item_count
    FROM filtered_orders AS fo
    JOIN retail_demo.gold.fact_order_items AS oi
        ON fo.order_id = oi.order_id
    GROUP BY fo.order_id
),
allocated_items AS (
    -- One row per order item: its share of the order's payment value.
    SELECT
        oi.order_id,
        oi.product_id,
        r.order_revenue
            * CASE
                  WHEN t.order_price IS NOT NULL AND t.order_price > 0
                      THEN oi.price / t.order_price
                  ELSE 1.0 / t.item_count
              END AS allocated_revenue
    FROM filtered_orders AS fo
    JOIN retail_demo.gold.fact_order_items AS oi
        ON fo.order_id = oi.order_id
    JOIN order_revenue AS r
        ON fo.order_id = r.order_id
    JOIN order_totals AS t
        ON fo.order_id = t.order_id
)

SELECT
    COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN') AS product_category,
    ROUND(SUM(a.allocated_revenue), 2) AS revenue
FROM allocated_items AS a
LEFT JOIN retail_demo.gold.dim_product AS dp
    ON a.product_id = dp.product_id
GROUP BY COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN')
ORDER BY revenue DESC;
