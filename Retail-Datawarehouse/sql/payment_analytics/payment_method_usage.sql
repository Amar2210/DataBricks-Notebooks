-- Q1 — Payment Method Usage
-- Business question: What percentage of orders are associated with each payment
-- method?
-- Result: one row per payment method with its distinct order count and order
-- percentage, DESC order.
--
-- Grain: ORDER + PAYMENT METHOD relationship (not payment rows, not orders).
--   1. order_method: SELECT DISTINCT order_id + payment_type from fact_payments.
--      Multiple payment records of the SAME type for one order collapse to a
--      single relationship row and cannot inflate the order count.
--   2. An order using MULTIPLE methods (e.g. credit card + voucher) contributes
--      once to EACH method. This is intentional: method percentages can
--      legitimately sum to more than 100%. Do NOT "fix" this by forcing
--      single-method attribution.
--   3. Denominator = distinct orders in the payment population
--      (COUNT(DISTINCT order_id) over fact_payments). Orders with no payment
--      record cannot be attributed to a method and are outside this population
--      by design.
--
-- NULL handling: NULL payment_type is labelled 'UNKNOWN' via COALESCE (same
-- null convention as Sales Q5/Q6/Q7), not dropped — the relationship row is
-- preserved and the order still counts in the denominator.
--
-- Grain safety: fact_payments only. No join to fact_orders or
-- fact_order_items (joining items would fan out across payment rows).
--
-- Scope note: this query covers full history. It is intentionally NOT
-- parameterized by date.

WITH order_method AS (
    -- One row per order + payment-method participation (deduplicated grain).
    SELECT DISTINCT
        p.order_id,
        COALESCE(p.payment_type, 'UNKNOWN') AS payment_type
    FROM retail_demo.gold.fact_payments AS p
),
total AS (
    -- Distinct orders in the payment population (denominator).
    SELECT COUNT(DISTINCT order_id) AS total_orders
    FROM retail_demo.gold.fact_payments
)

SELECT
    m.payment_type,
    COUNT(DISTINCT m.order_id) AS distinct_orders,
    ROUND(100.0 * COUNT(DISTINCT m.order_id) / NULLIF(t.total_orders, 0), 2) AS order_percentage
FROM order_method AS m
CROSS JOIN total AS t
GROUP BY m.payment_type, t.total_orders
ORDER BY distinct_orders DESC, m.payment_type ASC;
