-- Q2 — Average Delivery Time Trend (monthly, purchase cohort)
-- Business question: How has the average delivery time changed over time for
-- orders placed in each month?
-- Result: time-series table (one row per purchase month) suitable for a line
-- chart, with the eligible order count for context.
--
-- Locked cohort definition: the time dimension is the month of
-- order_purchase_timestamp. Each row represents orders PURCHASED in that month
-- and their subsequent delivery performance. Do NOT group by delivery month.
--
-- Locked definitions:
--   * Delivery duration (days) = DATEDIFF(order_delivered_customer_date,
--     order_purchase_timestamp) — calendar-day difference (end date minus start
--     date). Fractional-day precision is intentionally not used.
--   * Eligible = orders with a non-null purchase timestamp AND a non-null
--     actual delivery date. Undelivered orders cannot contribute a duration and
--     are excluded from both the average and the count.
--
-- Grain: fact_orders only (1 row/order). No join to items/payments, so no
-- fan-out risk. Months with zero eligible orders do not appear (no calendar
-- spine); this is intentional — add a calendar dimension later if a dense
-- series is needed.
--
-- Scope note: this query covers full history (one row per purchase month). It is
-- intentionally NOT parameterized by date. If a bounded window is ever needed,
-- build a separate query with the established :start_date / :end_date pattern
-- on order_purchase_timestamp.

SELECT
    DATE_FORMAT(DATE_TRUNC('MONTH', o.order_purchase_timestamp), 'yyyy-MM') AS period,
    COUNT(DISTINCT o.order_id) AS eligible_delivered_orders,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 2) AS avg_delivery_days
FROM retail_demo.gold.fact_orders AS o
WHERE o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY DATE_TRUNC('MONTH', o.order_purchase_timestamp)
ORDER BY DATE_TRUNC('MONTH', o.order_purchase_timestamp);
