-- Q5 — New Customers Over Time (monthly)
-- Business question: How many new customers did we acquire over time?
-- Result: time-series table suitable for a line/bar chart, e.g.
--   period  | new_customers
--   2017-01 | ...
--   2017-02 | ...
--
-- Definition (locked):
--   * A new customer is a customer whose FIRST-EVER order occurs in that period.
--   * Correct approach: MIN(order_purchase_timestamp) per customer_unique_id
--     over FULL history (no date filter during first-order discovery), derive
--     the first-order month, THEN filter first-order dates to the selected
--     acquisition range and group by month.
--   * Do NOT count all distinct customers per month as new — returning
--     customers would be incorrectly classified.
--
-- Properties:
--   * Each customer is counted in exactly one month (their first-ever month).
--   * Monthly counts for an acquisition range sum to the total number of
--     customers acquired in that range.
--   * Months with zero acquisitions do not appear (no calendar spine); this is
--     intentional — add a calendar dimension later if a dense series is needed.
--   * NULL customer_unique_id rows are excluded (they cannot define a first
--     purchase for a customer).
--
-- Grain: fact_orders only (1 row/order). No join to items/payments, so no
-- fan-out risk.
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first acquisition day (filters FIRST-order dates)
--   :end_date   — inclusive last acquisition day (filters FIRST-order dates)
-- Note the parameter semantics differ from Q1–Q4: here the range selects the
-- acquisition window, while first-order discovery always scans full history.

WITH first_orders AS (
    -- One row per customer: first-ever purchase across ALL history.
    SELECT
        o.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_timestamp
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.customer_unique_id IS NOT NULL
    GROUP BY o.customer_unique_id
)

SELECT
    DATE_FORMAT(DATE_TRUNC('MONTH', first_purchase_timestamp), 'yyyy-MM') AS period,
    COUNT(*) AS new_customers
FROM first_orders
WHERE first_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
  AND first_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
GROUP BY DATE_TRUNC('MONTH', first_purchase_timestamp)
ORDER BY DATE_TRUNC('MONTH', first_purchase_timestamp);
