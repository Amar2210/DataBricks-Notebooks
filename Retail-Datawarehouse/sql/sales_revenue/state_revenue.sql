-- Q7 — Revenue by Customer State
-- Business question: Which customer states generate the most revenue?
-- Result: one row per customer state with revenue, DESC order.
--
-- Attribution note: each order maps to exactly ONE customer record
-- (fact_orders.customer_id -> dim_customer.customer_id, 1:1 at order grain),
-- so grouping payment_value by the order's customer state introduces NO
-- fan-out, provided fact_order_items is NOT joined. This query deliberately
-- avoids the item table. Each payment row is counted exactly once under its
-- order's state.
--
-- State label: customer_state from dim_customer (per Gold geography decision;
-- no separate geography dimension). NULL states labelled 'UNKNOWN' via
-- COALESCE (LEFT JOIN preserves orders whose customer lookup fails).
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day

WITH filtered_orders AS (
    SELECT
        o.order_id,
        o.customer_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
)

SELECT
    COALESCE(c.customer_state, 'UNKNOWN') AS customer_state,
    ROUND(COALESCE(SUM(p.payment_value), 0), 2) AS revenue
FROM filtered_orders AS fo
LEFT JOIN retail_demo.gold.fact_payments AS p
    ON fo.order_id = p.order_id
LEFT JOIN retail_demo.gold.dim_customer AS c
    ON fo.customer_id = c.customer_id
GROUP BY COALESCE(c.customer_state, 'UNKNOWN')
ORDER BY revenue DESC;
