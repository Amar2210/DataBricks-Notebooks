-- Q1 — Overall On-Time Delivery Rate
-- Business question: What percentage of delivered orders reached the customer by
-- the estimated delivery date?
-- Result: single KPI row (eligible delivered orders, on-time orders, late
-- orders, on-time rate). This is an overall KPI, not a time series.
--
-- Locked definitions:
--   * Actual customer delivery    = order_delivered_customer_date.
--   * Estimated customer delivery = order_estimated_delivery_date.
--   * Eligible = delivered orders where BOTH dates are non-null. Orders missing
--     either date are excluded (they cannot be classified), not assumed on time.
--   * On time: actual <= estimated. Late: actual > estimated.
--   * On-time rate = 100.0 * on-time / eligible. NULLIF guards the empty
--     population (rate is NULL, not zero, when no order is eligible).
--
-- Grain: fact_orders is 1 row per order; COUNT(DISTINCT order_id) follows the
-- locked Orders definition. No join to fact_order_items or fact_payments, so
-- there is no fan-out risk.
--
-- Scope note: this query is intentionally NOT parameterized by date. It is a
-- full-history KPI. If a period-bounded variant is ever needed, build a separate
-- query with the established :start_date / :end_date pattern on
-- order_purchase_timestamp.

SELECT
    COUNT(DISTINCT o.order_id) AS eligible_delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS on_time_orders,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1 ELSE 0 END)
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS on_time_rate_pct
FROM retail_demo.gold.fact_orders AS o
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;
