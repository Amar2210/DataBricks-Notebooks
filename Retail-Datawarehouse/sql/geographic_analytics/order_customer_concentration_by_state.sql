-- Q4 — Geographic Concentration of Orders & Customers
-- Business question: How concentrated are orders and customers across states?
-- Result: one row per customer state with order/customer counts and each
-- state's share of the overall dataset, ordered by order share DESC. No
-- concentration index (e.g. HHI) is introduced — the required metric is the
-- state-level distribution and share.
--
-- Locked definitions:
--   * orders = COUNT(DISTINCT order_id) per state;
--     order_share_pct = 100.0 * state orders / TOTAL distinct orders.
--   * unique_customers = COUNT(DISTINCT customer_unique_id) per state;
--     customer_share_pct = 100.0 * state customers / TOTAL distinct customers.
--   * Denominators are computed over the COMPLETE population (all of
--     fact_orders), not as sums of state-level counts — a customer ordering
--     from two states counts once in the denominator and once under each
--     state, so customer shares measure per-state reach, not a partition.
--     (Cross-state customers are rare in Olist; shares still sum to
--     approximately 100% — verify, do not force.)
--
-- Totals use the established CTE + CROSS JOIN pattern (same as
-- delivery_operations.order_status_distribution) rather than DISTINCT window
-- aggregates, keeping the denominators independently auditable.
--
-- Join: fact_orders LEFT JOIN dim_customer on customer_id (many-to-one, no
-- duplication). NULL states are labelled 'UNKNOWN' via COALESCE (same null
-- convention as Sales Q5/Q6/Q7) and are INCLUDED in both the state rows and
-- the denominators, so shares reconcile to the full dataset.
--
-- Scope note: this query covers full history. It is intentionally NOT
-- parameterized by date.

WITH state_stats AS (
    -- One row per customer state: distinct orders and customers.
    SELECT
        COALESCE(c.customer_state, 'UNKNOWN') AS customer_state,
        COUNT(DISTINCT o.order_id) AS orders,
        COUNT(DISTINCT o.customer_unique_id) AS unique_customers
    FROM retail_demo.gold.fact_orders AS o
    LEFT JOIN retail_demo.gold.dim_customer AS c
        ON o.customer_id = c.customer_id
    GROUP BY COALESCE(c.customer_state, 'UNKNOWN')
),
total AS (
    -- Complete-population denominators (not sums of state rows).
    SELECT
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT customer_unique_id) AS total_customers
    FROM retail_demo.gold.fact_orders
)

SELECT
    s.customer_state,
    s.orders,
    ROUND(100.0 * s.orders / NULLIF(t.total_orders, 0), 2) AS order_share_pct,
    s.unique_customers,
    ROUND(100.0 * s.unique_customers / NULLIF(t.total_customers, 0), 2) AS customer_share_pct
FROM state_stats AS s
CROSS JOIN total AS t
ORDER BY order_share_pct DESC, s.customer_state ASC;
