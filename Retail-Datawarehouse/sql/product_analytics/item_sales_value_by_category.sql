-- Q3 — Item Sales Value by Category
-- Business question: Which product categories have the highest item sales value?
-- Result: one row per product category with its item sales value, DESC order.
--
-- Locked definition (intentionally distinct from Revenue):
--   * Item Sales Value = SUM(fact_order_items.price) by product category.
--   * This is NOT Revenue. Project Revenue remains SUM(fact_payments.payment_value)
--     (see Sales Q1/Q5). Do NOT relabel this metric as revenue.
--   * Do NOT use fact_payments here. The query never leaves item grain, so no
--     items x payments fan-out is possible and no allocation assumption is needed
--     (unlike Sales Q5, which must allocate payment grain to item grain).
--   * AVG(fact_order_items.price) vs SUM(fact_order_items.price): the average is
--     the observed selling price (see Q1); only the SUM is Item Sales Value.
--
-- Grain safety: fact_order_items (1 row per order item) LEFT JOIN dim_product
-- (1 row per product) is a many-to-one join on product_id — it cannot multiply
-- fact rows. LEFT JOIN preserves order items whose product_id is missing from
-- dim_product under 'UNKNOWN' instead of dropping them.
--
-- Category label: same rule as Sales Q5/Q6 — prefer the English translation,
-- fall back to the original Portuguese name, then 'UNKNOWN' (Gold keeps
-- null-category products, so nulls are expected and preserved, not dropped).
--
-- Scope note: this query is intentionally NOT parameterized by date. It answers
-- a full-history category ranking. If a period-bounded variant is ever needed,
-- build a separate query with the established :start_date / :end_date pattern
-- on order_purchase_timestamp via fact_orders.

SELECT
    COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN') AS product_category,
    ROUND(SUM(oi.price), 2) AS item_sales_value
FROM retail_demo.gold.fact_order_items AS oi
LEFT JOIN retail_demo.gold.dim_product AS dp
    ON oi.product_id = dp.product_id
GROUP BY COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN')
ORDER BY item_sales_value DESC;
