-- Q2 — Repeat Customer Rate for a Selected Period
-- Business question: What percentage of customers are repeat customers?
-- Result: single KPI row (total_customers, repeat_customers, repeat_rate_pct).
--
-- REPEAT DEFINITION DECISION (explicit, do not change silently):
--   * Chosen semantics: PERIOD-BOUNDED. A repeat customer is a customer with
--     more than one order WITHIN the selected period.
--   * Alternative considered and REJECTED as default: lifetime classification
--     (customers active in the period ranked by their lifetime order history).
--   * Rationale for period-bounded:
--       1. Self-contained: uses only the selected order population, same as
--          Sales Q1/Q3/Q4 and Customer Q1. No scan outside the range, no
--          lookback bias where early periods mechanically undercount repeats.
--       2. Reconcilable: numerator is a strict subset of denominator, rate is
--          always 0–100%, and Q2/Q3/Q4 share one classification so bucket
--          counts (Q3) and revenue split (Q4) reconcile exactly.
--       3. Genie-friendly: reusable pattern with only :start_date/:end_date.
--   * Limitation: a lifetime-repeat customer who buys only once inside the
--     window counts as one-time here. If lifetime loyalty is ever required,
--     build a separate query that classifies by full history — do not mix the
--     two semantics in one KPI.
--
-- Business rules:
--   * Customer identity = customer_unique_id. Orders = COUNT(DISTINCT order_id).
--   * Sales date = fact_orders.order_purchase_timestamp. No status filter.
--   * NULL customer_unique_id rows are excluded from the population (they
--     cannot be attributed to a customer); COUNT(DISTINCT) would ignore them
--     anyway, but grouping must exclude them explicitly.
--
-- Duplicate-safety: aggregates from fact_orders only (1 row/order). No join
-- to fact_order_items or fact_payments, so item/payment rows cannot inflate
-- order counts.
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day

WITH period_orders AS (
    -- Same order population as Sales Q1/Q3/Q4 and Customer Q1.
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
totals AS (
    SELECT
        COUNT(*) AS total_customers,
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers
    FROM customer_counts
)

SELECT
    total_customers,
    repeat_customers,
    ROUND(100.0 * repeat_customers / NULLIF(total_customers, 0), 2) AS repeat_rate_pct
FROM totals;
