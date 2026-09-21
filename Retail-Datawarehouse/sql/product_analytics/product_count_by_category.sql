-- Q2 — Product Count by Category
-- Business question: How many distinct products are there in each product category?
-- Result: one row per product category with its distinct product count, DESC order.
--
-- Catalog composition, NOT observed demand: reads dim_product only
-- (1 row per product). No fact table is involved, so there is no fan-out risk.
--
-- Category label: same rule as Sales Q5/Q6 — prefer the English translation,
-- fall back to the original Portuguese name, then 'UNKNOWN' (Gold keeps
-- null-category products, so nulls are expected and preserved, not dropped).
--
-- Scope note: this query is intentionally NOT parameterized by date. The catalog
-- is a point-in-time dimension snapshot, not a period fact population.

SELECT
    COALESCE(product_category_name_english, product_category_name, 'UNKNOWN') AS product_category,
    COUNT(DISTINCT product_id) AS product_count
FROM retail_demo.gold.dim_product
GROUP BY COALESCE(product_category_name_english, product_category_name, 'UNKNOWN')
ORDER BY product_count DESC;
