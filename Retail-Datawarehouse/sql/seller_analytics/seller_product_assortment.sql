-- Q5 — Seller Product Assortment
-- Business question: How many distinct products does each seller sell?
-- Result: one row per seller with its distinct observed-product count, DESC order.
--
-- Locked definition: observed assortment breadth = COUNT(DISTINCT product_id)
-- per seller_id from fact_order_items. This measures products appearing in
-- ordered data only — it is NOT the seller's guaranteed complete catalog, since
-- the dataset captures observed ordered products. A higher count means broader
-- observed assortment; a lower count means narrower observed assortment. Do not
-- make causal or categorical claims such as "this seller is definitely
-- specialized."
--
-- Grain safety: fact_order_items only. No join to dim_seller is needed because
-- the output carries seller_id alone; no join to fact_payments (payment grain
-- differs; joining would fan out).
--
-- Ordering is deterministic: distinct product count DESC, then seller_id ASC.
--
-- Scope note: this query is intentionally NOT parameterized by date. It measures
-- assortment over full observed history. If a period-bounded variant is ever
-- needed, build a separate query with the established :start_date / :end_date
-- pattern on order_purchase_timestamp via fact_orders.

SELECT
    seller_id,
    COUNT(DISTINCT product_id) AS distinct_product_count
FROM retail_demo.gold.fact_order_items
GROUP BY seller_id
ORDER BY distinct_product_count DESC, seller_id ASC;
