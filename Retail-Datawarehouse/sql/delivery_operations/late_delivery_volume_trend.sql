-- Q3 — Late Delivery Volume Trend (monthly, purchase cohort)
-- Business question: How has the volume of late deliveries changed over time?
-- Result: time-series table (one row per purchase month) with late order volume
-- as the main metric, plus eligible orders and late rate for context.
--
-- Locked cohort definition: the time dimension is the month of
-- order_purchase_timestamp. Each row represents orders PLACED in that month and
-- whether they were eventually delivered late. Do NOT group by delivery month.
--
-- Locked definitions:
--   * Eligible = delivered orders where BOTH actual and estimated delivery
--     dates are non-null. Orders missing either date are excluded, not assumed
--     on time.
--   * Late: actual delivery > estimated delivery. Each late order is counted
--     exactly once (fact_orders is 1 row/order).
--   * Late rate = 100.0 * late / eligible per month (NULLIF-guarded). This is a
--     per-cohort companion to the volume metric, not a duplication of the
--     overall Q1 KPI.
--
-- Grain: fact_orders only. No join to items/payments, so no fan-out risk.
-- Months with zero eligible orders do not appear (no calendar spine); this is
-- intentional — add a calendar dimension later if a dense series is needed.
--
-- Scope note: this query covers full history (one row per purchase month). It is
-- intentionally NOT parameterized by date. If a bounded window is ever needed,
-- build a separate query with the established :start_date / :end_date pattern
-- on order_purchase_timestamp.

SELECT
    DATE_FORMAT(DATE_TRUNC('MONTH', o.order_purchase_timestamp), 'yyyy-MM') AS period,
    COUNT(DISTINCT o.order_id) AS eligible_delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END)
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS late_rate_pct
FROM retail_demo.gold.fact_orders AS o
WHERE o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY DATE_TRUNC('MONTH', o.order_purchase_timestamp)
ORDER BY DATE_TRUNC('MONTH', o.order_purchase_timestamp);
