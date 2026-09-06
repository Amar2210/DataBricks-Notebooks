-- Q4 — Average Order Value (AOV) for a Selected Period
-- Business question: What is the Average Order Value for a selected period?
-- Result: single KPI value.
--
-- Definition (locked): AOV = Revenue / Distinct Orders, where both measures
-- use the SAME order population (orders purchased in range) and Revenue =
-- SUM(fact_payments.payment_value).
--
-- Duplicate-safety:
--   * Revenue comes from fact_payments joined to the filtered order set only
--     (no item join, so no fan-out). Orders are counted DISTINCT.
--   * LEFT JOIN so orders with no payment row contribute 0 revenue but still
--     count in the denominator — same population as Q1 + Q3.
--   * NULLIF guards division-by-zero (returns NULL AOV when no orders).
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day

WITH filtered_orders AS (
    SELECT
        o.order_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
),
totals AS (
    SELECT
        COUNT(DISTINCT fo.order_id) AS order_count,
        COALESCE(SUM(p.payment_value), 0) AS total_revenue
    FROM filtered_orders AS fo
    LEFT JOIN retail_demo.gold.fact_payments AS p
        ON fo.order_id = p.order_id
)

SELECT
    total_revenue,
    order_count,
    total_revenue / NULLIF(order_count, 0) AS aov -- NULLIF guards division-by-zero (it returns NULL AOV when no orders) and we know something is off
FROM totals;
-- Also I though why not keep the backup as 1 so that we get the total revenue value, but this becomes messy when we have to integrate it with AI as it might now understand the context
-- if we have null it knows something is wrong and we also definetly know it rather than a silent revenue value which is incorrect.
