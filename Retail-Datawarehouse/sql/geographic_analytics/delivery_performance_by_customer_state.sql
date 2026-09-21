-- Q3 — Delivery Performance by Customer Geography
-- Business question: How does delivery performance vary across customer
-- geographies?
-- Result: one row per customer state with eligible delivered orders, on-time
-- orders, on-time rate, and average delivery days, ordered by state. This is
-- state-level DESCRIPTIVE analytics — do NOT read it as a best/worst state
-- ranking. Rows are ordered by customer_state precisely so no ranking is
-- implied (same rationale as seller_delivery_performance.sql).
--
-- The geography here is CUSTOMER geography (dim_customer.customer_state via
-- the order's customer record), not seller geography.
--
-- Locked definitions:
--   * Eligible = delivered orders where BOTH order_delivered_customer_date AND
--     order_estimated_delivery_date are non-null. Orders missing either date
--     are excluded, not assumed on time.
--   * On time: actual <= estimated. Late: actual > estimated.
--   * on_time_delivery_rate = 100.0 * on-time / eligible (NULLIF-guarded, so
--     the rate is NULL — not zero — for a state with no eligible order, and
--     always 0–100% otherwise; AVG-free integer-division-safe math).
--   * average_delivery_days = AVG(DATEDIFF(order_delivered_customer_date,
--     order_purchase_timestamp)) — calendar-day difference, purchase to
--     customer delivery, over eligible delivered orders only.
--
-- Join: eligibility-filtered fact_orders (1 row/order) LEFT JOIN dim_customer
-- (1 row/customer_id) is many-to-one on customer_id — no duplication. NULL
-- states are labelled 'UNKNOWN' via COALESCE (same null convention as Sales
-- Q5/Q6/Q7), not dropped. fact_order_items and fact_payments are never joined.
--
-- Scope note: this query covers full history. It is intentionally NOT
-- parameterized by date.

SELECT
    COALESCE(c.customer_state, 'UNKNOWN') AS customer_state,
    COUNT(DISTINCT o.order_id) AS eligible_delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS on_time_orders,
    ROUND(
        100.0 * SUM(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1 ELSE 0 END)
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS on_time_delivery_rate,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 2) AS average_delivery_days
FROM retail_demo.gold.fact_orders AS o
LEFT JOIN retail_demo.gold.dim_customer AS c
    ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY COALESCE(c.customer_state, 'UNKNOWN')
ORDER BY customer_state ASC;
