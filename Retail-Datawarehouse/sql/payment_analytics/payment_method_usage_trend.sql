-- Q3 — Payment Method Usage Over Time (monthly, purchase cohort)
-- Business question: How does payment-method usage change over time?
-- Result: time-series table (one row per purchase month + payment method) with
-- distinct orders and monthly order percentage, chronological order.
--
-- Locked cohort definition: the time dimension is the month of
-- fact_orders.order_purchase_timestamp. Each row represents orders PURCHASED in
-- that month and the methods used to pay for them. Do NOT group by delivery
-- month, and do NOT invent a payment timestamp — none exists in Gold.
--
-- Grain: ORDER + PAYMENT METHOD + PURCHASE MONTH relationship.
--   1. order_method_month: DISTINCT order_id + payment_type + purchase month
--      from fact_payments JOIN fact_orders. Multiple payment records of the
--      SAME method for one order collapse to one row and cannot inflate counts.
--   2. An order using MULTIPLE methods contributes once to EACH method in its
--      month, so monthly method percentages can legitimately sum past 100%.
--   3. Monthly denominator = distinct orders in that month's PAYMENT population
--      (orders with at least one payment record, purchased that month). Orders
--      with no payment record cannot be attributed to a method and are outside
--      the population by design.
--
-- Join notes: INNER JOIN drops payment rows whose order_id has no fact_orders
-- match (orphans cannot be assigned a purchase month) and orders with a NULL
-- purchase timestamp are excluded (they cannot join a cohort). Surface both in
-- validation rather than inventing an 'UNKNOWN' month here.
--
-- NULL handling: NULL payment_type is labelled 'UNKNOWN' via COALESCE (same
-- null convention as Sales Q5/Q6/Q7), not dropped.
--
-- Never join fact_order_items here (items x payments fan-out).
--
-- Scope note: this query covers full history (one row set per purchase month).
-- It is intentionally NOT parameterized by date.

WITH order_method_month AS (
    -- One row per order + payment-method + purchase-month participation.
    SELECT DISTINCT
        p.order_id,
        COALESCE(p.payment_type, 'UNKNOWN') AS payment_type,
        DATE_TRUNC('MONTH', o.order_purchase_timestamp) AS purchase_month
    FROM retail_demo.gold.fact_payments AS p
    JOIN retail_demo.gold.fact_orders AS o
        ON p.order_id = o.order_id
    WHERE o.order_purchase_timestamp IS NOT NULL
),
monthly_total AS (
    -- Distinct payment-population orders per purchase month (denominator).
    SELECT
        purchase_month,
        COUNT(DISTINCT order_id) AS month_orders
    FROM order_method_month
    GROUP BY purchase_month
)

SELECT
    DATE_FORMAT(m.purchase_month, 'yyyy-MM') AS purchase_month,
    m.payment_type,
    COUNT(DISTINCT m.order_id) AS distinct_orders,
    ROUND(100.0 * COUNT(DISTINCT m.order_id) / NULLIF(t.month_orders, 0), 2) AS order_percentage
FROM order_method_month AS m
JOIN monthly_total AS t
    ON m.purchase_month = t.purchase_month
GROUP BY m.purchase_month, m.payment_type, t.month_orders
ORDER BY m.purchase_month ASC, m.payment_type ASC;
