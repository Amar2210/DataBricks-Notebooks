-- Q6 — Average Observed Selling Price by Seller
-- Business question: What is the average observed selling price of products sold
-- by each seller?
-- Result: one row per seller with its average observed selling price, DESC order.
--
-- Locked definition: average observed selling price = AVG(fact_order_items.price)
-- per seller_id. This is the average transaction-level item price observed for
-- that seller. Do NOT call it average revenue, do not build price bands, and do
-- not infer profitability from it (no cost/COGS data exists).
--
-- NULL handling: AVG ignores NULL prices, so sellers are averaged over their
-- non-null transaction prices. Any NULL-price rows should be investigated as a
-- data-quality issue (see validation), not silently redefined.
--
-- Grain safety: fact_order_items only (1 row per order item). No join to
-- dim_seller is needed because the output carries seller_id alone; no join to
-- fact_payments (payment grain differs; joining would fan out).
--
-- Ordering is deterministic: average observed selling price DESC, then
-- seller_id ASC.
--
-- Scope note: this query is intentionally NOT parameterized by date. It averages
-- over full observed history. If a period-bounded variant is ever needed, build
-- a separate query with the established :start_date / :end_date pattern on
-- order_purchase_timestamp via fact_orders.

SELECT
    seller_id,
    ROUND(AVG(price), 2) AS avg_observed_price
FROM retail_demo.gold.fact_order_items
GROUP BY seller_id
ORDER BY avg_observed_price DESC, seller_id ASC;
