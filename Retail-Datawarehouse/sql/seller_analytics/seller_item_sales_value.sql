-- Q4 — Seller Item Sales Value
-- Business question: Which sellers have the highest item sales value?
-- Result: one row per seller with its item sales value, DESC order.
--
-- Locked definition (intentionally distinct from Revenue):
--   * Item Sales Value = SUM(fact_order_items.price) by seller_id.
--   * This is NOT Revenue. Project Revenue remains SUM(fact_payments.payment_value)
--     (see Sales Q1). Do NOT relabel this metric as revenue.
--   * Do NOT use fact_payments here. The query never leaves item grain, so no
--     items x payments fan-out is possible (unlike Sales Q5, which must allocate
--     payment grain to item grain).
--
-- Grain safety: fact_order_items only (1 row per order item). No join to
-- dim_seller is needed because the output carries seller_id alone — a
-- seller_id -> dim_seller join is many-to-one and would not multiply rows, but
-- it is unnecessary here, so it is omitted.
--
-- Ordering is deterministic: item sales value DESC, then seller_id ASC.
--
-- Scope note: this query is intentionally NOT parameterized by date. It ranks
-- sellers over full observed history. If a period-bounded variant is ever needed,
-- build a separate query with the established :start_date / :end_date pattern
-- on order_purchase_timestamp via fact_orders.

SELECT
    seller_id,
    ROUND(SUM(price), 2) AS item_sales_value
FROM retail_demo.gold.fact_order_items
GROUP BY seller_id
ORDER BY item_sales_value DESC, seller_id ASC;
