-- Q1 — Seller Distribution by State
-- Business question: How many sellers operate in each state?
-- Result: one row per seller state with its distinct seller count, DESC order.
--
-- Seller-base geography, NOT observed demand: reads dim_seller only
-- (1 row per seller). No fact table is involved, so there is no fan-out risk.
--
-- State label: same rule as Sales Q7 — seller_state from dim_seller (per Gold
-- geography decision; no separate geography dimension). NULL states are labelled
-- 'UNKNOWN' via COALESCE, not dropped.
--
-- Scope note: this query is intentionally NOT parameterized by date. The seller
-- base is a point-in-time dimension snapshot, not a period fact population.

SELECT
    COALESCE(seller_state, 'UNKNOWN') AS seller_state,
    COUNT(DISTINCT seller_id) AS seller_count
FROM retail_demo.gold.dim_seller
GROUP BY COALESCE(seller_state, 'UNKNOWN')
ORDER BY seller_count DESC;
