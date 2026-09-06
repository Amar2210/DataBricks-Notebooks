-- Q3 — Order Count for a Selected Period
-- Business question: How many orders were placed during a selected period?
-- Result: single KPI value.
--
-- Business definitions (locked):
--   * Orders = COUNT(DISTINCT order_id) from fact_orders.
--   * Date filter = fact_orders.order_purchase_timestamp only.
--   * Do NOT count rows from fact_order_items or fact_payments (an order
--     can have many items / payments; row counts would overstate orders).
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day

SELECT
    COUNT(DISTINCT o.order_id) AS order_count
FROM retail_demo.gold.fact_orders AS o
WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
  AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1);
