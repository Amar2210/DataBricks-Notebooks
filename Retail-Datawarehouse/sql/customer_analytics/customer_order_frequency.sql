-- Q3 — Customer Order-Frequency Distribution for a Selected Period
-- Business question: What is the distribution of customers by order frequency?
-- Result: distribution table suitable for visualization, e.g.
--   orders_per_customer | customer_count
--   1                   | ...
--   2                   | ...
--   3                   | ...
--   4                   | ...
--   5+                  | ...
--
-- FREQUENCY DEFINITION DECISION (consistent with Q2/Q4):
--   * Frequency = orders placed INSIDE the selected period per customer_unique_id.
--   * Same period-bounded semantics as Q2 (repeat = order_count > 1 in period)
--     and Q4 (one-time vs repeat). Bucket counts therefore sum exactly to the
--     Q1 unique-customer total and the Q2 denominator for the same range.
--   * Do NOT summarize as an average: the purpose is to preserve the shape of
--     customer behavior (Olist is heavily skewed toward 1 order) and avoid
--     hiding skewness.
--
-- Bucket design: 1, 2, 3, 4, 5+ (top bucket caps the long tail; Olist has
-- almost no customers above 3 orders in any bounded window, so 5+ keeps the
-- chart readable without losing the skew signal).
--
-- Duplicate-safety: aggregates from fact_orders only (1 row/order). No join
-- to fact_order_items or fact_payments, so item/payment rows cannot inflate
-- counts. Each customer lands in exactly one bucket.
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day

WITH period_orders AS (
    -- Same order population as Q1/Q2/Q4.
    SELECT
        o.order_id,
        o.customer_unique_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
      AND o.customer_unique_id IS NOT NULL
),
customer_counts AS (
    -- One row per customer: orders placed INSIDE the period.
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM period_orders
    GROUP BY customer_unique_id
),
bucketed AS (
    SELECT
        CASE
            WHEN order_count >= 5 THEN '5+'
            ELSE CAST(order_count AS STRING)
        END AS orders_per_customer,
        CASE
            WHEN order_count >= 5 THEN 5
            ELSE order_count
        END AS bucket_sort
    FROM customer_counts
)

SELECT
    orders_per_customer,
    COUNT(*) AS customer_count
FROM bucketed
GROUP BY orders_per_customer, bucket_sort
ORDER BY bucket_sort;
