-- Q3 — Seller Item Sales Volume
-- Business question: Which sellers have the highest number of items sold?
-- Result: one row per seller with its items-sold count, DESC order.
--
-- Locked definition: items sold = COUNT(*) of fact_order_items rows per
-- seller_id. fact_order_items is 1 row per order item, so each row is one
-- ordered item. This is ITEM volume, not order volume (distinct orders
-- fulfilled is Q2) — do not describe this metric as number of orders.
--
-- Grain safety: fact_order_items only. No join to dim_seller is needed because
-- the output carries seller_id alone; no join to fact_payments (payment grain
-- differs; joining would fan out).
--
-- Ordering is deterministic: items sold DESC, then seller_id ASC.
--
-- Scope note: this query is intentionally NOT parameterized by date. It ranks
-- sellers over full observed history. If a period-bounded variant is ever needed,
-- build a separate query with the established :start_date / :end_date pattern
-- on order_purchase_timestamp via fact_orders.

SELECT
    seller_id,
    COUNT(*) AS items_sold
FROM retail_demo.gold.fact_order_items
GROUP BY seller_id
ORDER BY items_sold DESC, seller_id ASC;
