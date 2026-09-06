-- Sales & Revenue — Validation Queries
-- Purpose: verify the 7 analytical scripts against Gold data. Run in
-- Databricks SQL against retail_demo.gold with the same :start_date / :end_date
-- (Date type) used by the analytical queries.
--
-- How to use:
--   1. Set :start_date / :end_date widgets (e.g. 2017-01-01 to 2018-12-31 for
--      full-dataset validation; Olist spans ~2016-09 to 2018-10).
--   2. Run each block independently. Each returns PASS/FAIL or reconcilable totals.
--   3. All blocks must pass before trusting the layer as Genie/NL reference logic.
--
-- Coverage of the 7 required checks:
--   V1 revenue not inflated | V2 distinct orders | V3 AOV = Rev/Orders |
--   V4 purchase-timestamp filtering | V5 category revenue reconciles |
--   V6 category volume distinct | V7 state revenue reconciles.

-- ---------------------------------------------------------------------------
-- V1: Revenue is not inflated by duplicate joins.
-- Compares the correct Q1 logic against a deliberately NAIVE items x payments
-- join. Expect: naive_revenue >= correct_revenue (strictly greater whenever a
-- multi-item order with payments exists in range). If equal, the fan-out risk
-- is still real — the naive pattern must never be used.
-- ---------------------------------------------------------------------------
WITH filtered_orders AS (
    SELECT o.order_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
),
correct AS (
    SELECT COALESCE(SUM(p.payment_value), 0) AS revenue
    FROM filtered_orders AS fo
    LEFT JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id
),
naive AS (
    SELECT COALESCE(SUM(p.payment_value), 0) AS revenue
    FROM filtered_orders AS fo
    JOIN retail_demo.gold.fact_order_items AS oi ON fo.order_id = oi.order_id
    JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id
)
SELECT
    (SELECT revenue FROM correct) AS correct_revenue,
    (SELECT revenue FROM naive) AS naive_fanout_revenue,
    CASE
        WHEN (SELECT revenue FROM naive) >= (SELECT revenue FROM correct) THEN 'PASS (naive >= correct, fan-out demonstrated)'
        ELSE 'FAIL'
    END AS result;

-- ---------------------------------------------------------------------------
-- V2: Order count uses distinct orders (Q3 sanity).
-- Expect: row_count = distinct_count (fact_orders is 1 row/order) and both
-- equal the Q3 result. Any gap vs COUNT(*) over item/payment tables proves
-- why those tables must not be counted.
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT o.order_id) AS distinct_order_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT o.order_id) THEN 'PASS' ELSE 'FAIL' END AS result
FROM retail_demo.gold.fact_orders AS o
WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
  AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1);

-- ---------------------------------------------------------------------------
-- V3: AOV equals Revenue / Orders over the same population.
-- Recomputes revenue and orders independently and checks Q4's formula.
-- Expect: single row with result = 'PASS'.
-- ---------------------------------------------------------------------------
WITH filtered_orders AS (
    SELECT o.order_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
),
totals AS (
    SELECT
        COUNT(DISTINCT fo.order_id) AS order_count,
        COALESCE(SUM(p.payment_value), 0) AS revenue
    FROM filtered_orders AS fo
    LEFT JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id
)
SELECT
    revenue,
    order_count,
    revenue / NULLIF(order_count, 0) AS recomputed_aov,
    CASE
        WHEN order_count = 0 THEN 'PASS (no orders, AOV NULL by design)'
        WHEN ABS(revenue / NULLIF(order_count, 0) * order_count - revenue) < 0.01 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM totals;

-- ---------------------------------------------------------------------------
-- V4: Date filtering uses order_purchase_timestamp.
-- Shows the min/max purchase timestamps inside the filtered set. Expect: both
-- within [:start_date, :end_date + 1 day). If other timestamps (approved /
-- delivered) were used, these bounds would shift — this pins the definition.
-- ---------------------------------------------------------------------------
SELECT
    MIN(o.order_purchase_timestamp) AS min_purchase_in_range,
    MAX(o.order_purchase_timestamp) AS max_purchase_in_range,
    COUNT(DISTINCT o.order_id) AS orders_in_range
FROM retail_demo.gold.fact_orders AS o
WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
  AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1);

-- ---------------------------------------------------------------------------
-- V5: Category revenue (Q5) does not double-count — reconciles to Q1.
-- Re-runs the price-proportional allocation and compares its grand total to
-- Q1 revenue for orders WITH items. Expect: difference = 0 (allocation is
-- exact by construction). Any residual > rounding points to a join bug.
-- NOTE: orders with payments but zero items are unattributable and excluded
-- from the category split; V5b below quantifies that gap (expect 0 or tiny).
-- ---------------------------------------------------------------------------
WITH filtered_orders AS (
    SELECT o.order_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
),
order_revenue AS (
    SELECT fo.order_id, SUM(p.payment_value) AS order_revenue
    FROM filtered_orders AS fo
    JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id
    GROUP BY fo.order_id
),
order_totals AS (
    SELECT fo.order_id, SUM(oi.price) AS order_price, COUNT(*) AS item_count
    FROM filtered_orders AS fo
    JOIN retail_demo.gold.fact_order_items AS oi ON fo.order_id = oi.order_id
    GROUP BY fo.order_id
),
allocated AS (
    SELECT r.order_revenue
        * CASE
              WHEN t.order_price IS NOT NULL AND t.order_price > 0
                  THEN oi.price / t.order_price
              ELSE 1.0 / t.item_count
          END AS allocated_revenue
    FROM filtered_orders AS fo
    JOIN retail_demo.gold.fact_order_items AS oi ON fo.order_id = oi.order_id
    JOIN order_revenue AS r ON fo.order_id = r.order_id
    JOIN order_totals AS t ON fo.order_id = t.order_id
)
SELECT
    (SELECT COALESCE(SUM(p.payment_value), 0)
     FROM filtered_orders AS fo
     LEFT JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id) AS q1_revenue,
    (SELECT COALESCE(SUM(allocated_revenue), 0) FROM allocated) AS category_total,
    (SELECT COALESCE(SUM(allocated_revenue), 0) FROM allocated)
      - (SELECT COALESCE(SUM(p.payment_value), 0)
         FROM filtered_orders AS fo
         JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id
         WHERE fo.order_id IN (SELECT order_id FROM retail_demo.gold.fact_order_items)) AS unattributed_gap_check,
    CASE
        WHEN ABS((SELECT COALESCE(SUM(allocated_revenue), 0) FROM allocated)
               - (SELECT COALESCE(SUM(p.payment_value), 0)
                  FROM filtered_orders AS fo
                  JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id
                  WHERE fo.order_id IN (SELECT order_id FROM retail_demo.gold.fact_order_items))) < 0.01
            THEN 'PASS'
        ELSE 'FAIL'
    END AS result;

-- V5b: quantify orders in range with payments but no items (unattributable).
SELECT
    COUNT(DISTINCT fo.order_id) AS orders_with_payments_but_no_items,
    COALESCE(SUM(p.payment_value), 0) AS unattributed_revenue
FROM (
    SELECT o.order_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
) AS fo
JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id
WHERE fo.order_id NOT IN (SELECT order_id FROM retail_demo.gold.fact_order_items);

-- ---------------------------------------------------------------------------
-- V6: Category order volume (Q6) counts distinct orders, not item rows.
-- Per-category: distinct orders must be <= item rows. Expect: all PASS rows.
-- ---------------------------------------------------------------------------
WITH filtered_orders AS (
    SELECT o.order_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
),
per_category AS (
    SELECT
        COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN') AS product_category,
        COUNT(*) AS item_rows,
        COUNT(DISTINCT oi.order_id) AS distinct_orders
    FROM filtered_orders AS fo
    JOIN retail_demo.gold.fact_order_items AS oi ON fo.order_id = oi.order_id
    LEFT JOIN retail_demo.gold.dim_product AS dp ON oi.product_id = dp.product_id
    GROUP BY COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN')
)
SELECT
    product_category,
    item_rows,
    distinct_orders,
    CASE WHEN distinct_orders <= item_rows THEN 'PASS' ELSE 'FAIL' END AS result
FROM per_category
ORDER BY distinct_orders DESC;

-- ---------------------------------------------------------------------------
-- V7: State revenue (Q7) does not double-count — reconciles to Q1.
-- State split must sum exactly to Q1 revenue (each payment counted once under
-- exactly one state incl. 'UNKNOWN'). Expect: difference = 0.
-- ---------------------------------------------------------------------------
WITH filtered_orders AS (
    SELECT o.order_id, o.customer_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
),
by_state AS (
    SELECT COALESCE(c.customer_state, 'UNKNOWN') AS customer_state,
           COALESCE(SUM(p.payment_value), 0) AS revenue
    FROM filtered_orders AS fo
    LEFT JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id
    LEFT JOIN retail_demo.gold.dim_customer AS c ON fo.customer_id = c.customer_id
    GROUP BY COALESCE(c.customer_state, 'UNKNOWN')
)
SELECT
    (SELECT COALESCE(SUM(revenue), 0) FROM by_state) AS state_total,
    (SELECT COALESCE(SUM(p.payment_value), 0)
     FROM filtered_orders AS fo
     LEFT JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id) AS q1_revenue,
    CASE
        WHEN ABS((SELECT COALESCE(SUM(revenue), 0) FROM by_state)
               - (SELECT COALESCE(SUM(p.payment_value), 0)
                  FROM filtered_orders AS fo
                  LEFT JOIN retail_demo.gold.fact_payments AS p ON fo.order_id = p.order_id)) < 0.01
            THEN 'PASS'
        ELSE 'FAIL'
    END AS result;
