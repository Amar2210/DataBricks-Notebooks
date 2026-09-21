-- Q2 — Seller Order Volume
-- Business question: Which sellers fulfill the highest number of distinct orders?
-- Result: one row per seller with its distinct fulfilled-order count, DESC order.
--
-- Locked definition: distinct orders fulfilled = COUNT(DISTINCT order_id) per
-- seller_id from fact_order_items. Do NOT use COUNT(*) here — an order can
-- contain multiple order-item rows from the same seller, and item rows are not
-- orders (item volume is Q3).
--
-- Grain safety: fact_order_items only (1 row per order item). No join to
-- dim_seller is needed because the output carries seller_id alone; no join to
-- fact_payments (payment grain differs; joining would fan out).
--
-- Ordering is deterministic: order count DESC, then seller_id ASC.
--
-- Scope note: this query is intentionally NOT parameterized by date. It ranks
-- sellers over full observed history. If a period-bounded variant is ever needed,
-- build a separate query with the established :start_date / :end_date pattern
-- on order_purchase_timestamp via fact_orders.

SELECT
    seller_id,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM retail_demo.gold.fact_order_items
GROUP BY seller_id
ORDER BY distinct_orders DESC, seller_id ASC;
