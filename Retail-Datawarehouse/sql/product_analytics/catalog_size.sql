-- Q4 — Overall Catalog Size
-- Business question: How many distinct products and product categories are in
-- the catalog?
-- Result: single KPI row with both totals.
--
-- Reads dim_product only (1 row per product). No fact table is involved, so
-- there is no fan-out risk and no date parameter applies — the catalog is a
-- point-in-time dimension snapshot, not a period fact population.
--
-- Category counting follows the same null convention as Q1/Q2/Q3 and Sales
-- Q5/Q6: the counted label is COALESCE(product_category_name_english,
-- product_category_name, 'UNKNOWN'), so products with a null category are
-- represented as one 'UNKNOWN' category instead of being silently dropped.
-- Consequence (by design): total_categories equals the row count of Q2
-- (product_count_by_category.sql), and the Q2 product_count values sum to
-- total_products.
--
-- COUNT(DISTINCT ...) ignores NULLs; the COALESCE wrapper is what makes the
-- null-category products countable as 'UNKNOWN'.

SELECT
    COUNT(DISTINCT product_id) AS total_products,
    COUNT(DISTINCT COALESCE(product_category_name_english, product_category_name, 'UNKNOWN')) AS total_categories
FROM retail_demo.gold.dim_product;
