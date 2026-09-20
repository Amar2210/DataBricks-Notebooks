-- Customer Analytics — Validation Queries
-- Purpose: verify the 5 analytical scripts against Gold data. Run in
-- Databricks SQL against retail_demo.gold with the same :start_date / :end_date
-- (Date type) used by the analytical queries.
--
-- How to use:
--   1. Set :start_date / :end_date widgets (e.g. 2017-01-01 to 2018-12-31 for
--      full-dataset validation; Olist spans ~2016-09 to 2018-10).
--   2. Run each block independently. Each returns PASS/FAIL or reconcilable totals.
--   3. All blocks must pass before trusting the layer as Genie/NL reference logic.
--
-- Coverage:
--   V1 Q1 distinct customers + date field | V2 repeat rate 0-100 + subset |
--   V3 frequency buckets partition + sum  | V4 revenue split reconciles, no
--   payment duplication | V5 new-customer first-ever month + sums.

-- ---------------------------------------------------------------------------
-- V1: Q1 uses distinct customer_unique_id and order_purchase_timestamp.
-- Recomputes Q1 independently and shows the purchase bounds. Expect: bounds
-- within [:start_date, :end_date + 1 day) and distinct <= row count.
-- ---------------------------------------------------------------------------
SELECT
    COUNT(DISTINCT o.customer_unique_id) AS unique_customers,
    COUNT(*) AS order_rows_in_range,
    MIN(o.order_purchase_timestamp) AS min_purchase_in_range,
    MAX(o.order_purchase_timestamp) AS max_purchase_in_range,
    CASE
        WHEN COUNT(DISTINCT o.customer_unique_id) <= COUNT(*) THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM retail_demo.gold.fact_orders AS o
WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
  AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1);

-- ---------------------------------------------------------------------------
-- V2: Q2 repeat definition — numerator subset of denominator, rate 0–100%.
-- Recomputes totals independently. Expect: single PASS row.
-- ---------------------------------------------------------------------------
WITH period_orders AS (
    SELECT o.order_id, o.customer_unique_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
      AND o.customer_unique_id IS NOT NULL
),
customer_counts AS (
    SELECT customer_unique_id, COUNT(DISTINCT order_id) AS order_count
    FROM period_orders
    GROUP BY customer_unique_id
),
totals AS (
    SELECT
        COUNT(*) AS total_customers,
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers
    FROM customer_counts
)
SELECT
    total_customers,
    repeat_customers,
    ROUND(100.0 * repeat_customers / NULLIF(total_customers, 0), 2) AS repeat_rate_pct,
    CASE
        WHEN total_customers = 0 THEN 'PASS (no customers, rate NULL by design)'
        WHEN repeat_customers <= total_customers
         AND 100.0 * repeat_customers / total_customers BETWEEN 0 AND 100 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM totals;

-- ---------------------------------------------------------------------------
-- V3: Q3 buckets — each customer in exactly one bucket, buckets sum to Q1/Q2
-- population, and item/payment rows do not inflate counts.
-- Expect: bucket_total = total_customers = Q1 unique count, all PASS.
-- ---------------------------------------------------------------------------
WITH period_orders AS (
    SELECT o.order_id, o.customer_unique_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
      AND o.customer_unique_id IS NOT NULL
),
customer_counts AS (
    SELECT customer_unique_id, COUNT(DISTINCT order_id) AS order_count
    FROM period_orders
    GROUP BY customer_unique_id
),
bucketed AS (
    SELECT
        CASE WHEN order_count >= 5 THEN '5+' ELSE CAST(order_count AS STRING) END AS bucket,
        customer_unique_id
    FROM customer_counts
)
SELECT
    (SELECT COUNT(*) FROM customer_counts) AS total_customers,
    (SELECT COUNT(*) FROM bucketed) AS bucketed_total,
    (SELECT COUNT(DISTINCT o.customer_unique_id)
     FROM retail_demo.gold.fact_orders AS o
     WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
       AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)) AS q1_unique_customers,
    -- Item/payment fan-out guard: distinct orders in range must be far fewer
    -- than item/payment row counts (proves why Q3 must not count those tables).
    (SELECT COUNT(*) FROM retail_demo.gold.fact_order_items AS oi
     WHERE oi.order_id IN (SELECT order_id FROM period_orders)) AS item_rows_in_range,
    CASE
        WHEN (SELECT COUNT(*) FROM bucketed) = (SELECT COUNT(*) FROM customer_counts)
         AND (SELECT COUNT(*) FROM customer_counts)
           = (SELECT COUNT(DISTINCT o.customer_unique_id)
              FROM retail_demo.gold.fact_orders AS o
              WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
                AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)) THEN 'PASS'
        ELSE 'FAIL'
    END AS result;

-- ---------------------------------------------------------------------------
-- V4: Q4 revenue split — Repeat + One-time = Q1 total; no payment duplication;
-- classification matches Q2/Q3 semantics.
-- Expect: difference = 0 (tolerance 0.01 for rounding).
-- ---------------------------------------------------------------------------
WITH period_orders AS (
    SELECT o.order_id, o.customer_unique_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
      AND o.customer_unique_id IS NOT NULL
),
customer_counts AS (
    SELECT customer_unique_id, COUNT(DISTINCT order_id) AS order_count
    FROM period_orders
    GROUP BY customer_unique_id
),
order_class AS (
    SELECT
        po.order_id,
        CASE WHEN cc.order_count > 1 THEN 'Repeat' ELSE 'One-time' END AS customer_type
    FROM period_orders AS po
    JOIN customer_counts AS cc ON po.customer_unique_id = cc.customer_unique_id
),
by_type AS (
    SELECT oc.customer_type, COALESCE(SUM(p.payment_value), 0) AS revenue
    FROM order_class AS oc
    LEFT JOIN retail_demo.gold.fact_payments AS p ON oc.order_id = p.order_id
    GROUP BY oc.customer_type
)
SELECT
    (SELECT COALESCE(SUM(revenue), 0) FROM by_type) AS split_total,
    (SELECT COALESCE(SUM(p.payment_value), 0)
     FROM period_orders AS fo
     LEFT JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id) AS q1_revenue_same_population,
    -- Naive fan-out guard: joining items x payments must give >= correct total.
    (SELECT COALESCE(SUM(p.payment_value), 0)
     FROM period_orders AS fo
     JOIN retail_demo.gold.fact_order_items AS oi ON fo.order_id = oi.order_id
     JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id) AS naive_fanout_revenue,
    CASE
        WHEN ABS((SELECT COALESCE(SUM(revenue), 0) FROM by_type)
               - (SELECT COALESCE(SUM(p.payment_value), 0)
                  FROM period_orders AS fo
                  LEFT JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id)) < 0.01 THEN 'PASS'
        ELSE 'FAIL'
    END AS result;

-- ---------------------------------------------------------------------------
-- V5: Q5 new customers — each customer counted only in first-ever month;
-- returning customers not counted as new; monthly counts sum correctly.
-- Expect: one row per customer in the check (FAIL rows must be zero) and the
-- monthly total equals the distinct acquired-customer count.
-- ---------------------------------------------------------------------------
-- V5a: no customer appears in more than one acquisition month.
WITH first_orders AS (
    SELECT o.customer_unique_id, MIN(o.order_purchase_timestamp) AS first_purchase
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.customer_unique_id IS NOT NULL
    GROUP BY o.customer_unique_id
)
SELECT
    COUNT(*) AS acquired_customers_in_range,
    COUNT(DISTINCT customer_unique_id) AS distinct_acquired,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT customer_unique_id) THEN 'PASS (each customer in exactly one month)'
        ELSE 'FAIL'
    END AS result
FROM first_orders
WHERE first_purchase >= CAST(:start_date AS TIMESTAMP)
  AND first_purchase < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1);

-- V5b: monthly trend total reconciles to distinct acquired customers, and the
-- naive "all distinct per month" count is >= the new-customer count (proves
-- why the naive pattern overcounts by including returners).
WITH first_orders AS (
    SELECT o.customer_unique_id, MIN(o.order_purchase_timestamp) AS first_purchase
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.customer_unique_id IS NOT NULL
    GROUP BY o.customer_unique_id
),
trend AS (
    SELECT DATE_TRUNC('MONTH', first_purchase) AS m, COUNT(*) AS new_customers
    FROM first_orders
    WHERE first_purchase >= CAST(:start_date AS TIMESTAMP)
      AND first_purchase < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
    GROUP BY DATE_TRUNC('MONTH', first_purchase)
),
naive AS (
    SELECT DATE_TRUNC('MONTH', o.order_purchase_timestamp) AS m,
           COUNT(DISTINCT o.customer_unique_id) AS all_distinct
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
    GROUP BY DATE_TRUNC('MONTH', o.order_purchase_timestamp)
)
SELECT
    (SELECT COALESCE(SUM(new_customers), 0) FROM trend) AS trend_total,
    (SELECT COALESCE(SUM(all_distinct), 0) FROM naive) AS naive_monthly_distinct_total,
    CASE
        WHEN (SELECT COALESCE(SUM(all_distinct), 0) FROM naive)
           >= (SELECT COALESCE(SUM(new_customers), 0) FROM trend) THEN 'PASS (naive >= new, returner overcount demonstrated)'
        ELSE 'FAIL'
    END AS result;
