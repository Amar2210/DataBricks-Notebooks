-- Q4 — Order Status Distribution
-- Business question: What is the distribution of orders across order statuses?
-- Result: one row per order status with its distinct order count and share of
-- total orders, DESC order. This is a broad order-lifecycle view.
--
-- Locked definitions:
--   * Orders = COUNT(DISTINCT order_id) per status (fact_orders is 1 row/order,
--     so this equals the row count per status; DISTINCT is kept explicit per
--     the project Orders definition).
--   * Share = 100.0 * status orders / all orders (NULLIF-guarded).
--   * NULL statuses are labelled 'UNKNOWN' via COALESCE (same null convention
--     as Sales Q5/Q6/Q7), not dropped.
--
-- Grain: fact_orders only. fact_order_items is deliberately NOT involved —
-- counting item rows would inflate status counts.
-- The repository has no established status ordering, so rows are sorted by
-- order count DESC (no deterministic secondary key is needed: status labels
-- are unique, so each status appears exactly once).
--
-- Scope note: this query covers all orders in full history. It is
-- intentionally NOT parameterized by date.

WITH status_orders AS (
    SELECT
        COALESCE(o.order_status, 'UNKNOWN') AS order_status,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM retail_demo.gold.fact_orders AS o
    GROUP BY COALESCE(o.order_status, 'UNKNOWN')
),
total AS (
    SELECT SUM(order_count) AS total_orders
    FROM status_orders
)

SELECT
    s.order_status,
    s.order_count,
    ROUND(100.0 * s.order_count / NULLIF(t.total_orders, 0), 2) AS pct_of_orders
FROM status_orders AS s
CROSS JOIN total AS t
ORDER BY s.order_count DESC;
