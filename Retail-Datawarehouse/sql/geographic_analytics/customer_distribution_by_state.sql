-- Q1 — Customer Distribution by State
-- Business question: How are customers distributed across states?
-- Result: one row per customer state with unique customers and orders,
-- ordered by unique customers DESC. Descriptive analytics only — no state is
-- labelled best or worst.
--
-- Locked definitions:
--   * Customer identity = fact_orders.customer_unique_id (real/business
--     customer). Do NOT use customer_id for customer counts.
--   * unique_customers = COUNT(DISTINCT customer_unique_id). COUNT(DISTINCT ...)
--     ignores NULLs, so orders with a NULL customer_unique_id do not inflate
--     the count (same rule as Customer Q1).
--   * orders = COUNT(DISTINCT order_id) per state.
--
-- Join: fact_orders.customer_id -> dim_customer.customer_id (the
-- order-associated record key for attribute lookup, per the Gold customer
-- model and Sales Q7). LEFT JOIN preserves orders whose customer lookup fails;
-- their state is labelled 'UNKNOWN' via COALESCE (same null convention as
-- Sales Q5/Q6/Q7), not dropped.
--
-- Grain: fact_orders is 1 row per order; dim_customer is 1 row per
-- customer_id, so the join is many-to-one and cannot duplicate orders.
--
-- Scope note: this query covers full history. It is intentionally NOT
-- parameterized by date.

SELECT
    COALESCE(c.customer_state, 'UNKNOWN') AS customer_state,
    COUNT(DISTINCT o.customer_unique_id) AS unique_customers,
    COUNT(DISTINCT o.order_id) AS orders
FROM retail_demo.gold.fact_orders AS o
LEFT JOIN retail_demo.gold.dim_customer AS c
    ON o.customer_id = c.customer_id
GROUP BY COALESCE(c.customer_state, 'UNKNOWN')
ORDER BY unique_customers DESC, customer_state ASC;
