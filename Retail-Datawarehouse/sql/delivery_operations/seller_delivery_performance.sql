-- Q5 — Seller Delivery Performance
-- Business question: How does delivery performance vary across sellers?
-- Result: one row per seller with eligible delivered orders, late orders, late
-- percentage, and average days late. This is a DESCRIPTIVE operational view —
-- do NOT read it as a best/worst seller ranking. Rows are ordered by seller_id
-- precisely so no ranking is implied.
--
-- THE GRAIN PROBLEM (read before changing this query):
--   * fact_orders is 1 row per order; fact_order_items is 1..N rows per order.
--   * Delivery dates live at ORDER grain, but seller participation lives at the
--     ORDER-SELLER relationship: one order can contain several items from the
--     SAME seller (must count once for that seller) and items from MULTIPLE
--     sellers (may legitimately contribute once to EACH participating seller).
--   * A naive fact_orders JOIN fact_order_items would repeat the order's
--     delivery dates once per ITEM row and inflate every metric. NEVER count
--     item rows here.
--
-- CHOSEN FLOW (deduplicate before measuring):
--   1. seller_orders: SELECT DISTINCT order_id, seller_id from fact_order_items
--      → exactly one row per seller-order participation.
--   2. Join each seller-order row to its single fact_orders row and keep only
--      eligible participations (actual AND estimated delivery dates non-null,
--      delivered orders only).
--   3. Classify late once per seller-order row (actual > estimated) and
--      aggregate by seller.
--
-- Locked definitions:
--   * Eligible delivered orders (per seller) = seller-order participations with
--     both dates available.
--   * Late percentage = 100.0 * late / eligible (NULLIF-guarded).
--   * Average days late = AVG(DATEDIFF(actual, estimated)) over LATE
--     participations ONLY (AVG ignores the NULLs produced for on-time rows).
--     Do NOT average lateness across on-time and late orders. A seller with no
--     late orders gets NULL average days late by design (no lateness to
--     describe), not zero.
--
-- Seller attributes (city/state) are deliberately NOT joined in: Seller
-- Analytics Q2–Q6 output seller_id alone, and the join is unnecessary for these
-- metrics. Join dim_seller only if a downstream use genuinely needs geography.
--
-- Scope note: this query covers full history. It is intentionally NOT
-- parameterized by date. If a period-bounded variant is ever needed, build a
-- separate query with the established :start_date / :end_date pattern on
-- order_purchase_timestamp via fact_orders.

WITH seller_orders AS (
    -- One row per seller-order participation (deduplicated grain).
    SELECT DISTINCT
        oi.order_id,
        oi.seller_id
    FROM retail_demo.gold.fact_order_items AS oi
),
eligible AS (
    -- One row per eligible seller-order participation: order-level delivery
    -- dates attached exactly once per participation.
    SELECT
        so.seller_id,
        so.order_id,
        o.order_delivered_customer_date AS delivered_date,
        o.order_estimated_delivery_date AS estimated_date
    FROM seller_orders AS so
    JOIN retail_demo.gold.fact_orders AS o
        ON so.order_id = o.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    seller_id,
    COUNT(*) AS eligible_delivered_orders,
    SUM(CASE WHEN delivered_date > estimated_date THEN 1 ELSE 0 END) AS late_delivered_orders,
    ROUND(
        100.0 * SUM(CASE WHEN delivered_date > estimated_date THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS late_pct,
    ROUND(
        AVG(CASE WHEN delivered_date > estimated_date THEN DATEDIFF(delivered_date, estimated_date) END),
        2
    ) AS avg_days_late
FROM eligible
GROUP BY seller_id
ORDER BY seller_id ASC;
