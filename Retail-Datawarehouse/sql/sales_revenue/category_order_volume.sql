-- Q6 — Order Volume by Product Category
-- Business question: Which product categories have the highest order volume?
-- Result: one row per product category with distinct order count, DESC order.
--
-- Grain note: COUNT(DISTINCT order_id), NOT item rows. An order with 3 items
-- in one category counts ONCE for that category. An order with items in two
-- categories counts once under EACH category (it genuinely touched both), so
-- category totals can sum to more than the overall Q3 order count — expected.
--
-- Category label: same rule as Q5 — prefer English translation, fall back to
-- the original Portuguese name, then 'UNKNOWN' (nulls preserved, not dropped).
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day

WITH filtered_orders AS (
    SELECT
        o.order_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
)

SELECT
    COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN') AS product_category,
    COUNT(DISTINCT oi.order_id) AS order_count
FROM filtered_orders AS fo
JOIN retail_demo.gold.fact_order_items AS oi
    ON fo.order_id = oi.order_id
LEFT JOIN retail_demo.gold.dim_product AS dp
    ON oi.product_id = dp.product_id
GROUP BY COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN')
ORDER BY order_count DESC;
