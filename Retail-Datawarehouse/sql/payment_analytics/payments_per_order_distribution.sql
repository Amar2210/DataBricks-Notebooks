-- Q4 — Payments per Order Distribution
-- Business question: How many payment records does each order contain?
-- Result: distribution table (one row per payment-record-count bucket) suitable
-- for a bar/histogram-style chart, in logical bucket order.
--
-- Grain: ORDER. Two steps, in this order:
--   1. order_counts: fact_payments → GROUP BY order_id → COUNT(*) payment rows
--      per order. Row counting is the robust measure — do NOT use
--      payment_sequential alone as the count without validating it (gaps or
--      non-1-based sequences would mislead).
--   2. Bucket each order as 1, 2, 3, or 4+ payment records, then count orders
--      per bucket. Each order lands in exactly one bucket, so bucket counts sum
--      to the distinct-order population of fact_payments.
--
-- Bucket design: 1, 2, 3, 4+ (top bucket caps the long tail; multi-record
-- orders are rare, so 4+ keeps the chart readable without losing the skew
-- signal). Do NOT summarize as a single average payments-per-order metric —
-- the purpose is to preserve the shape of the distribution.
--
-- Coverage note: only orders WITH payment records can appear (an order with no
-- payment row contributes no countable record). Orders absent from
-- fact_payments are outside this population by design, not bucketed as zero.
--
-- Grain safety: fact_payments only. Never join fact_order_items here (items x
-- payments fan-out would inflate per-order record counts).
--
-- Scope note: this query covers full history. It is intentionally NOT
-- parameterized by date.

WITH order_counts AS (
    -- One row per order: its payment-record count.
    SELECT
        p.order_id,
        COUNT(*) AS payment_record_count
    FROM retail_demo.gold.fact_payments AS p
    GROUP BY p.order_id
),
bucketed AS (
    SELECT
        CASE
            WHEN payment_record_count >= 4 THEN '4+'
            ELSE CAST(payment_record_count AS STRING)
        END AS payment_record_count_bucket,
        CASE
            WHEN payment_record_count >= 4 THEN 4
            ELSE payment_record_count
        END AS bucket_sort
    FROM order_counts
)

SELECT
    payment_record_count_bucket,
    COUNT(*) AS order_count
FROM bucketed
GROUP BY payment_record_count_bucket, bucket_sort
ORDER BY bucket_sort;
