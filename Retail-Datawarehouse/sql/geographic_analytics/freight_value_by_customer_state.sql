-- Q2 — Freight Value by Customer Geography
-- Business question: How does freight value vary across customer geographies?
-- Result: one row per customer state with order count, total freight, and
-- average freight per order, ordered by total freight DESC.
--
-- THE GRAIN PROBLEM (read before changing this query):
--   * freight_value lives at ORDER-ITEM grain (fact_order_items, 1..N rows per
--     order). Averaging it directly (AVG(freight_value)) would produce an
--     ITEM-level average, not an order-level one.
--   * Correct flow: aggregate freight to ONE row per order FIRST
--     (order_freight: SUM(freight_value) per order_id), THEN attach customer
--     geography, THEN aggregate by state. SUM and AVG over the per-order
--     totals are order-level measures by construction.
--
-- Locked definitions:
--   * orders = COUNT(DISTINCT order_id) per state.
--   * total_freight_value = SUM(total_freight_per_order).
--   * average_freight_value_per_order = AVG(total_freight_per_order) — one
--     freight total per order. NEVER AVG(fact_order_items.freight_value).
--
-- Coverage note: only orders WITH order-item rows can carry freight, so orders
-- absent from fact_order_items are outside this population by design (they
-- contribute no freight). An order whose freight rows are all NULL yields a
-- NULL total: it counts in `orders` but is ignored by AVG (which skips NULLs).
-- Surface NULL-freight volume in validation rather than redefining the metric.
--
-- Joins: order_freight (1 row/order) JOIN fact_orders (1 row/order) is 1:1 on
-- order_id — no duplication. dim_customer is attached via LEFT JOIN on
-- customer_id (many-to-one); NULL states are labelled 'UNKNOWN' via COALESCE
-- (same null convention as Sales Q5/Q6/Q7), not dropped. fact_payments is
-- never joined (items x payments fan-out).
--
-- Scope note: this query covers full history. It is intentionally NOT
-- parameterized by date.

WITH order_freight AS (
    -- One row per order: its total freight across all items.
    SELECT
        oi.order_id,
        SUM(oi.freight_value) AS total_freight_per_order
    FROM retail_demo.gold.fact_order_items AS oi
    GROUP BY oi.order_id
)

SELECT
    COALESCE(c.customer_state, 'UNKNOWN') AS customer_state,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(SUM(f.total_freight_per_order), 2) AS total_freight_value,
    ROUND(AVG(f.total_freight_per_order), 2) AS average_freight_value_per_order
FROM order_freight AS f
JOIN retail_demo.gold.fact_orders AS o
    ON f.order_id = o.order_id
LEFT JOIN retail_demo.gold.dim_customer AS c
    ON o.customer_id = c.customer_id
GROUP BY COALESCE(c.customer_state, 'UNKNOWN')
ORDER BY total_freight_value DESC, customer_state ASC;
