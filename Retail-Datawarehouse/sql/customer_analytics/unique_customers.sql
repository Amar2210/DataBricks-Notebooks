-- Q1 — Unique Customers for a Selected Period
-- Business question: How many unique customers purchased during a selected period?
-- Result: single KPI value.
--
-- Business definitions (locked, consistent with Sales & Revenue slice):
--   * Sales date  = fact_orders.order_purchase_timestamp (purchase time only).
--   * Customer identity = fact_orders.customer_unique_id (real/business customer).
--     Do NOT use customer_id (order-associated record) for customer counts.
--   * A customer counts if they placed at least one order in the selected period.
--   * COUNT(DISTINCT ...) ignores NULLs, so orders with a NULL
--     customer_unique_id (should not occur in Gold, guarded by design) do not
--     inflate the count. No explicit IS NOT NULL filter is needed.
--   * No order_status filter, same population as Sales Q1/Q3/Q4.
--
-- Grain: fact_orders is 1 row per order; distinct customer_unique_id is safe
-- without joining any other table (no fan-out risk).
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day
-- The < DATE_ADD(end, 1) pattern makes the end date inclusive for the full
-- day regardless of the time component in order_purchase_timestamp.

SELECT
    COUNT(DISTINCT o.customer_unique_id) AS unique_customers
FROM retail_demo.gold.fact_orders AS o
WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
  AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1);
