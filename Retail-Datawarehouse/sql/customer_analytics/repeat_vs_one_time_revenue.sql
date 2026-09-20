-- Q4 — Revenue: Repeat vs One-Time Customers for a Selected Period
-- Business question: How much revenue comes from repeat vs one-time customers?
-- Result:
--   customer_type | revenue
--   One-time      | ...
--   Repeat        | ...
--
-- Classification (consistent with Q2/Q3 period-bounded semantics):
--   * one-time = exactly 1 order INSIDE the selected period.
--   * repeat   = more than 1 order INSIDE the selected period.
--   * See repeat_customer_rate.sql for why period-bounded was chosen over
--     lifetime history (reconciliability, no lookback bias, shared population).
--
-- Business definitions (locked):
--   * Revenue = SUM(fact_payments.payment_value) for orders purchased in range.
--     Do NOT use fact_order_items.price / freight_value.
--   * Sales date = fact_orders.order_purchase_timestamp. No status filter.
--
-- GRAIN SAFETY (critical — read before changing this query):
--   * fact_orders is order grain (1 row/order); fact_payments is payment grain
--     (1..N rows/order). Joining payments AFTER classification at order grain
--     counts each payment row exactly once — no fan-out.
--   * Classification is derived from fact_orders alone (customer -> order_count
--     -> customer_type -> order's type), producing exactly ONE type per order.
--     Only then is fact_payments LEFT-joined on order_id.
--   * fact_order_items is NEVER joined here; it would risk an items x payments
--     fan-out that multiplies payment_value.
--   * LEFT JOIN (not INNER) so orders with no payment row contribute 0 revenue
--     but are still attributed to their type — same population as Q1/Q2/Q3.
--   * Validation invariant: Repeat revenue + One-time revenue = Q1 total
--     revenue for the same period (see validation.sql V4).
--
-- Parameters (Databricks SQL named parameter markers, Date type):
--   :start_date — inclusive first calendar day
--   :end_date   — inclusive last calendar day

WITH period_orders AS (
    -- Same order population as Q1/Q2/Q3.
    SELECT
        o.order_id,
        o.customer_unique_id
    FROM retail_demo.gold.fact_orders AS o
    WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
      AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
      AND o.customer_unique_id IS NOT NULL
),
customer_counts AS (
    -- One row per customer: orders INSIDE the period.
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM period_orders
    GROUP BY customer_unique_id
),
order_class AS (
    -- Exactly one row per order with its customer's period-bounded type.
    SELECT
        po.order_id,
        CASE
            WHEN cc.order_count > 1 THEN 'Repeat'
            ELSE 'One-time'
        END AS customer_type
    FROM period_orders AS po
    JOIN customer_counts AS cc
        ON po.customer_unique_id = cc.customer_unique_id
)

SELECT
    oc.customer_type,
    ROUND(COALESCE(SUM(p.payment_value), 0), 2) AS revenue
FROM order_class AS oc
LEFT JOIN retail_demo.gold.fact_payments AS p
    ON oc.order_id = p.order_id
GROUP BY oc.customer_type
ORDER BY oc.customer_type;
