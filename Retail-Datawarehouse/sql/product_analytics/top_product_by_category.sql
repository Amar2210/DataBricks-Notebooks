-- Q1 — Top Product Within Each Category
-- Business question: For each product category, which product has the highest
-- quantity sold, and what is its average observed selling price?
-- Result: one row per product category with its top product, DESC category order.
--
-- Business definitions (locked, consistent with Sales & Revenue slice):
--   * Quantity sold = COUNT(*) of fact_order_items rows per product_id.
--     fact_order_items is 1 row per order item, so each row is one ordered
--     item; row count is the demand measure for this dataset.
--   * Average observed selling price = AVG(fact_order_items.price) for that
--     product. This is an observed transaction average, NOT a list price, and
--     must not be replaced by an arbitrary single-transaction price.
--   * No order_status filter, same order population as Sales Q1/Q3/Q4.
--
-- Grain safety:
--   * Demand is aggregated at product grain from fact_order_items alone, then
--     ranked. No join to fact_payments (payment grain differs; joining would
--     fan out and is forbidden for these four questions).
--   * dim_product is joined only to attach the category label (LEFT JOIN, so
--     order items whose product_id is missing from dim_product are preserved
--     under 'UNKNOWN', not dropped).
--
-- Ranking: ROW_NUMBER() partitioned by category, ordered by quantity_sold DESC
-- with product_id ASC as the deterministic tie-break, so each category returns
-- at most one product and reruns are stable.
--
-- Category label: same rule as Sales Q5/Q6 — prefer the English translation,
-- fall back to the original Portuguese name, then 'UNKNOWN' (Gold keeps
-- null-category products, so nulls are expected and preserved, not dropped).
--
-- Scope note: this query is intentionally NOT parameterized by date. It answers
-- a full-history "top product per category" question over all observed demand.
-- If a period-bounded variant is ever needed, build a separate query with the
-- established :start_date / :end_date pattern on order_purchase_timestamp.

WITH product_demand AS (
    -- One row per product: demand aggregated at product grain.
    SELECT
        oi.product_id,
        COUNT(*) AS quantity_sold,
        AVG(oi.price) AS avg_observed_price
    FROM retail_demo.gold.fact_order_items AS oi
    GROUP BY oi.product_id
),
ranked AS (
    SELECT
        COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN') AS product_category,
        pd.product_id,
        pd.quantity_sold,
        pd.avg_observed_price,
        ROW_NUMBER() OVER (
            PARTITION BY COALESCE(dp.product_category_name_english, dp.product_category_name, 'UNKNOWN')
            ORDER BY pd.quantity_sold DESC, pd.product_id ASC
        ) AS rn
    FROM product_demand AS pd
    LEFT JOIN retail_demo.gold.dim_product AS dp
        ON pd.product_id = dp.product_id
)

SELECT
    product_category,
    product_id,
    quantity_sold,
    ROUND(avg_observed_price, 2) AS avg_observed_price
FROM ranked
WHERE rn = 1
ORDER BY product_category ASC;
