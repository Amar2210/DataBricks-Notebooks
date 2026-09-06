-- Q2 — Revenue Trend Over Time (monthly)
-- Business question: How does revenue trend over a selected period?
-- Result: time-series table (one row per month) suitable for a line chart.
--
-- Business definitions (locked):
--   * Time dimension = fact_orders.order_purchase_timestamp, truncated to month.
--   * Revenue = SUM(fact_payments.payment_value) for orders purchased in range.
--
-- Duplicate-safety:
--   * Joins fact_orders (1 row/order) -> fact_payments only. No join to
--     fact_order_items, so no items x payments fan-out.
--   * Months with zero revenue do not appear (no calendar spine); this is
--     intentional — add a calendar dimension later if dense series is needed.
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day

WITH filtered_orders AS (
    SELECT
        o.order_id,
        o.order_purchase_timestamp
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
)

SELECT
    DATE_FORMAT(DATE_TRUNC('MONTH', fo.order_purchase_timestamp), 'yyyy-MM') AS period,
    COALESCE(SUM(p.payment_value), 0) AS revenue
FROM filtered_orders AS fo
LEFT JOIN retail_demo.gold.fact_payments AS p
    ON fo.order_id = p.order_id
GROUP BY DATE_TRUNC('MONTH', fo.order_purchase_timestamp)
ORDER BY DATE_TRUNC('MONTH', fo.order_purchase_timestamp);
