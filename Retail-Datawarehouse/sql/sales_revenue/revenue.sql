-- Q1 — Total Revenue for a Selected Period
-- Business question: What is the total revenue for a selected date range?
-- Result: single KPI value.
--
-- Business definitions (locked):
--   * Sales date  = fact_orders.order_purchase_timestamp (purchase time only).
--   * Revenue     = SUM(fact_payments.payment_value) for orders purchased in range.
--     Do NOT use fact_order_items.price / freight_value as revenue.
--   * Grain: one row per order in fact_orders; payments are 1..N per order.
--
-- Duplicate-safety:
--   * Joins fact_orders (1 row/order) -> fact_payments only. No join to
--     fact_order_items, so there is no items x payments fan-out.
--   * LEFT JOIN so orders with no payment row still count (contribute 0,
--     not dropped). SUM ignores NULLs; COALESCE guards the all-NULL case.
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day
-- The < DATE_ADD(end, 1) pattern makes the end date inclusive for the full
-- day regardless of the time component in order_purchase_timestamp.
-- 1. An order with no payment row. 
-- We use LEFT JOIN, so such an order produces one joined row with p.payment_value = NULL. 
-- SUM ignores NULLs, so the order contributes 0 — good. 
-- But if every row is NULL (e.g. zero orders in range, or none have payments), SUM over all-NULL returns NULL, not 0. COALESCE(..., 0) converts that to a clean 0 KPI instead of a blank NULL.


WITH filtered_orders AS (
    SELECT
        o.order_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
)

SELECT
    COALESCE(SUM(p.payment_value), 0) AS total_revenue
FROM filtered_orders AS fo
LEFT JOIN retail_demo.gold.fact_payments AS p
    ON fo.order_id = p.order_id;
