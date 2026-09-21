-- Q2 — Installment Distribution
-- Business question: How are payment records distributed across installment
-- ranges?
-- Result: distribution table (one row per installment bucket) suitable for a
-- bar/histogram-style chart, in logical bucket order.
--
-- Grain: PAYMENT RECORD. Each fact_payments row is one payment record and
-- payment_installments belongs to that record. This query counts RECORDS, not
-- orders: if 10 orders generate 14 payment records in 0–3 installments, the
-- 0–3 bucket shows 14. Do NOT summarize as an average and do NOT count orders
-- here (order-level payment counts are Q4).
--
-- Bucket design: 0–3, 4–6, 7–9, 10–12, 13+ (top bucket caps the long tail and
-- keeps the chart readable). Every non-null record lands in exactly one bucket.
--
-- NULL handling: NULL payment_installments is labelled 'UNKNOWN' via COALESCE
-- logic (same null convention as Sales Q5/Q6/Q7), not dropped — the record is
-- preserved and bucket counts reconcile to the full payment-record population.
-- The UNKNOWN row appears only when nulls exist.
--
-- Assumption (validate, do not silently redefine): installments are
-- non-negative per the source domain. Any negative value would fall into 0–3;
-- surface it in validation rather than inventing a bucket here.
--
-- Grain safety: fact_payments only. No join to fact_orders or
-- fact_order_items, so nothing can fan out or duplicate records.
--
-- Scope note: this query covers full history. It is intentionally NOT
-- parameterized by date.

WITH bucketed AS (
    SELECT
        CASE
            WHEN p.payment_installments IS NULL THEN 'UNKNOWN'
            WHEN p.payment_installments <= 3 THEN '0-3'
            WHEN p.payment_installments <= 6 THEN '4-6'
            WHEN p.payment_installments <= 9 THEN '7-9'
            WHEN p.payment_installments <= 12 THEN '10-12'
            ELSE '13+'
        END AS installment_bucket,
        CASE
            WHEN p.payment_installments IS NULL THEN 6
            WHEN p.payment_installments <= 3 THEN 1
            WHEN p.payment_installments <= 6 THEN 2
            WHEN p.payment_installments <= 9 THEN 3
            WHEN p.payment_installments <= 12 THEN 4
            ELSE 5
        END AS bucket_sort
    FROM retail_demo.gold.fact_payments AS p
)

SELECT
    installment_bucket,
    COUNT(*) AS payment_record_count
FROM bucketed
GROUP BY installment_bucket, bucket_sort
ORDER BY bucket_sort;
