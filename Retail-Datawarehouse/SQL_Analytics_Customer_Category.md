# Task: Implement Customer SQL Analytics Layer

## Project Context

I am building a production-oriented Data + AI portfolio project using the Olist Brazilian E-commerce dataset.

Architecture:

Raw Olist Data
→ BRONZE
→ SILVER
→ GOLD BUSINESS / DIMENSIONAL LAYER
→ SQL ANALYTICS
→ Databricks Genie / Natural Language Interface

The Gold layer is already implemented, validated, committed, pushed to GitHub, and synchronized with Databricks.

The Sales & Revenue portion of the SQL Analytics layer is already implemented (`sql/sales_revenue/` with 7 queries + `validation.sql`).

The next task is to implement the **Customer** portion of the SQL Analytics layer.

This task is ONLY about the SQL Analytics layer. Do not implement Genie, NLP, LangChain, a frontend, or any other future layer.

---

# Gold Tables Available

## Dimensions

### dim_customer

- customer_id
- customer_unique_id
- customer_zip_code_prefix
- customer_city
- customer_state

### dim_product

- product_id
- product_category_name
- product_category_name_english
- product_name_length
- product_description_length
- product_photos_qty
- product_weight_g
- product_length_cm
- product_height_cm
- product_width_cm

### dim_seller

- seller_id
- seller_zip_code_prefix
- seller_city
- seller_state

## Facts

### fact_orders

- order_id
- customer_unique_id
- customer_id
- order_status
- order_purchase_timestamp
- order_approved_at
- order_delivered_carrier_date
- order_delivered_customer_date
- order_estimated_delivery_date

### fact_order_items

- order_id
- order_item_id
- product_id
- seller_id
- shipping_limit_date
- price
- freight_value

### fact_payments

- order_id
- payment_sequential
- payment_type
- payment_installments
- payment_value

---

# Important Business Definitions

These definitions are already agreed and MUST be followed. They are consistent with the Sales & Revenue slice.

## Sales Date

Use:

`fact_orders.order_purchase_timestamp`

This represents when the customer placed the order.

Do not use approval, delivery, carrier, or estimated delivery timestamps for Customer period filtering, except Q5 where the same timestamp is used with different range semantics (see Q5).

## Customer Identity

For this project, the customer is defined as:

> `fact_orders.customer_unique_id` — the real/business customer identity.

Do NOT use:

- `fact_orders.customer_id` / `dim_customer.customer_id`

That field identifies the order-associated customer record and is retained only for traceability and for the `fact_orders.customer_id → dim_customer.customer_id` join when customer attributes are needed.

Consequences:

- Unique customers = `COUNT(DISTINCT customer_unique_id)`
- Orders per customer = `COUNT(DISTINCT order_id)` grouped by `customer_unique_id`
- `COUNT(DISTINCT ...)` ignores NULLs, but any `GROUP BY customer_unique_id` population must explicitly exclude `NULL` before grouping (a NULL cannot define a customer).

## Revenue (for Q4 only)

Same definition as Sales & Revenue:

> Total `payment_value` associated with orders purchased during the selected period.

The canonical calculation is based on `fact_payments.payment_value`, linked to orders through `order_id`.

Do NOT substitute:

- `fact_order_items.price`
- `fact_order_items.freight_value`

## Orders

Orders means:

`COUNT(DISTINCT order_id)`

based on `fact_orders.order_purchase_timestamp`.

## Important Join Warning

`fact_orders` is 1 row per order. `fact_order_items` is 1..N rows per order. `fact_payments` is 1..N rows per order.

Therefore, do NOT join `fact_order_items` or `fact_payments` when counting customers or orders — item/payment rows will fan out and inflate counts.

For Customer queries, only join tables required for the analytical question, and preserve the correct grain:

- Q1/Q2/Q3/Q5: `fact_orders` only. No join at all.
- Q4: classify at order grain from `fact_orders` first, then `LEFT JOIN fact_payments` on `order_id`. Never join `fact_order_items` here.

---

# Customer Questions

Implement these 5 canonical analytical SQL scripts.

## Q1 — Unique Customers for a Selected Period

Business question:

> How many unique customers purchased during a selected date range?

Expected result:

A single KPI-style value.

Expected conceptual inputs:

- start date
- end date

Rules:

- Count `COUNT(DISTINCT customer_unique_id)` from `fact_orders`.
- Date filter must use `fact_orders.order_purchase_timestamp`.
- Same order population as Sales Q1/Q3/Q4 (no `order_status` filter).
- No join — no fan-out risk.

---

## Q2 — Repeat Customer Rate

Business question:

> What percentage of customers are repeat customers?

Expected result:

A single KPI row:

| total_customers | repeat_customers | repeat_rate_pct |
|---|---|---:|
| ... | ... | ... |

Locked semantics — **period-bounded** (do not change silently):

- A repeat customer = a customer with **more than one order WITHIN the selected period**.
- Alternative considered and REJECTED as default: lifetime classification (classify period-active customers by their full lifetime history).
- Rationale for period-bounded:
  1. Self-contained: same order population as Q1/Sales Q1/Q3/Q4, no scan outside the range, no lookback bias.
  2. Reconcilable: numerator is a strict subset of denominator, rate is always 0–100%, and Q2/Q3/Q4 share one classification.
  3. Genie-friendly: reusable pattern with only `:start_date` / `:end_date`.
- Limitation: a lifetime-repeat customer who buys only once inside the window counts as one-time here. If lifetime loyalty is ever required, build a separate query — do not mix semantics in one KPI.

Rules:

- Exclude `NULL customer_unique_id` before grouping.
- Aggregate from `fact_orders` only.
- Guard division by zero (`NULLIF`); rate = `100.0 * repeat / total`.

---

## Q3 — Customer Order-Frequency Distribution

Business question:

> What is the distribution of customers by order frequency?

Expected result:

A distribution table suitable for visualization:

| orders_per_customer | customer_count |
|---|---:|
| 1 | ... |
| 2 | ... |
| 3 | ... |
| 4 | ... |
| 5+ | ... |

Rules:

- Frequency = orders placed INSIDE the selected period per `customer_unique_id` (same period-bounded semantics as Q2/Q4).
- Bucket design: `1, 2, 3, 4, 5+` (top bucket caps the long tail; Olist is heavily skewed toward 1 order, so this keeps the chart readable without losing the skew signal). Do NOT summarize as an average.
- Each customer lands in exactly one bucket; bucket counts must sum to the Q1 unique-customer total and the Q2 denominator for the same range.
- `fact_orders` only. No item/payment join.

---

## Q4 — Revenue: Repeat vs One-Time Customers

Business question:

> How much revenue comes from repeat vs one-time customers?

Expected result:

| customer_type | revenue |
|---|---:|
| One-time | ... |
| Repeat | ... |

Rules:

- Classification is consistent with Q2/Q3: one-time = exactly 1 order INSIDE the period; repeat = more than 1 order INSIDE the period.
- Revenue = `SUM(fact_payments.payment_value)` (same locked definition as Sales).
- Grain safety (critical):
  1. Classify at order grain from `fact_orders` alone (customer → order_count → customer_type → one type per order).
  2. Only then `LEFT JOIN fact_payments` on `order_id` — each payment row is counted exactly once.
  3. NEVER join `fact_order_items` here (items × payments fan-out).
  4. Use `LEFT JOIN`, not `INNER`, so orders with no payment row still belong to their type and contribute 0.
- Validation invariant: Repeat revenue + One-time revenue = Q1/Sales-Q1 total revenue for the same period.

---

## Q5 — New Customers Over Time (monthly)

Business question:

> How many new customers did we acquire over time?

Expected result:

A time-series table suitable for a line/bar chart:

| period | new_customers |
|---|---:|
| 2017-01 | ... |
| 2017-02 | ... |
| 2017-03 | ... |

Locked definition:

- A new customer = a customer whose **FIRST-EVER order** occurs in that month.
- Correct approach: `MIN(order_purchase_timestamp)` per `customer_unique_id` over FULL history (no date filter during first-order discovery), derive the first-order month, THEN filter first-order dates to the selected acquisition range and group by month.
- Do NOT count all distinct customers per month as new — that overcounts by including returning customers.

Properties:

- Each customer is counted in exactly one month.
- Monthly counts for an acquisition range sum to the distinct acquired-customer count in that range.
- Months with zero acquisitions do not appear (no calendar spine by design; add a calendar dimension later if a dense series is needed).
- Exclude `NULL customer_unique_id`.
- `fact_orders` only. No item/payment join.

Note the parameter semantics differ from Q1–Q4: here the range selects the **acquisition window** (filters first-order dates), while first-order discovery always scans full history.

---

# Parameterization Requirements

Where a date range is relevant, make the query parameterized for:

- start date
- end date

Use the parameter syntax supported by the project's intended Databricks SQL execution environment.

The established convention (same as Sales & Revenue) is Databricks SQL named parameter markers of Date type:

- `:start_date` — inclusive first calendar day
- `:end_date` — inclusive last calendar day

With the inclusive-end pattern:

```sql
WHERE o.order_purchase_timestamp >= CAST(:start_date AS TIMESTAMP)
  AND o.order_purchase_timestamp < DATE_ADD(CAST(:end_date AS TIMESTAMP), 1)
```

This makes the end date inclusive for the full day regardless of the time component in `order_purchase_timestamp`.

Do not invent unsupported parameter syntax.

Before finalizing, inspect the repository for existing SQL/notebook conventions and follow the project's established style if one exists.

Do not create separate SQL files for individual months, years, or customer segments.

The goal is reusable analytical logic.

---

# Repository / File Structure

First inspect the existing repository structure.

Create the SQL Analytics layer following the project's existing naming conventions.

Preferred structure (mirrors `sql/sales_revenue/`, already established):

`sql/customer_analytics/`

with:

- `unique_customers.sql`         — Q1
- `repeat_customer_rate.sql`     — Q2
- `customer_order_frequency.sql` — Q3
- `repeat_vs_one_time_revenue.sql` — Q4
- `new_customers_trend.sql`      — Q5
- `validation.sql`               — validation blocks V1–V5 (see below)

Do not create a redundant dimensional-modeling layer.

Gold is already the warehouse-ready business/dimensional layer.

---

# Production-Oriented Requirements

The SQL should be:

- readable
- maintainable
- deterministic
- explicitly tied to Gold tables
- safe against duplicate counting
- easy to validate
- easy for another engineer to understand
- useful as reference logic for an AI/NL interface later

Use clear aliases and CTEs where they improve readability (`period_orders → customer_counts → bucketed / order_class`, `first_orders → trend`).

Do not over-engineer the queries with unnecessary CTEs.

Add concise comments for important business logic, especially:

- customer-identity definition (`customer_unique_id` vs `customer_id`)
- date semantics (including Q5 acquisition-window vs period-population distinction)
- grain
- duplicate item/payment fan-out risks
- period-bounded repeat semantics and its limitation
- any unavoidable attribution assumptions

Do not add technologies or abstractions just for portfolio appearance.

---

# Validation Requirements

Do not merely write syntactically valid SQL.

For each query, determine how it can be validated against the Gold data.

Follow the repository's established convention: a single `validation.sql` in the same `sql/customer_analytics/` directory containing independently runnable blocks that return PASS/FAIL or reconcilable totals, run in Databricks SQL against `retail_demo.gold` with the same `:start_date` / `:end_date` used by the analytical queries.

At minimum verify (mirrors the implemented `validation.sql` V1–V5):

1. V1 (Q1): distinct `customer_unique_id` ≤ order row count; purchase bounds within `[:start_date, :end_date + 1 day)` — proves `order_purchase_timestamp` filtering and distinct-customer grain.
2. V2 (Q2): repeat numerator is a subset of denominator; rate is 0–100% (or NULL-by-design on empty population) — recomputed independently.
3. V3 (Q3): every customer lands in exactly one bucket; bucket total = customer total = Q1 unique count; item/payment row counts demonstrate why those tables must not be counted.
4. V4 (Q4): Repeat revenue + One-time revenue = Q1 total revenue for the same population (tolerance 0.01); naive items × payments join shown to be ≥ correct total (fan-out guard); classification matches Q2/Q3 semantics.
5. V5 (Q5): each customer appears in exactly one acquisition month; monthly trend total reconciles to distinct acquired-customer count; naive "all distinct per month" total ≥ new-customer total (proves why the naive pattern overcounts returners).

Use the existing Gold validation results as context but do not assume analytical correctness merely because Gold passed data-quality validation.

Use the Sales & Revenue `sql/sales_revenue/validation.sql` (V1–V7) as the style reference: header usage notes, one block per check, `Expect:` comment per block, `PASS/FAIL` output column.

---

# Very Important: Investigate Before Coding

Before creating the five scripts:

1. Inspect the repository structure.
2. Inspect existing Gold notebook/table creation code if needed.
3. Inspect naming conventions.
4. Confirm the exact catalog/schema/table references used by the project (established: `retail_demo.gold.fact_orders`, etc.).
5. Determine the Databricks SQL parameter syntax appropriate to the project's environment (established: `:start_date` / `:end_date` Date widgets).
6. Understand the Olist customer-identity rule (`customer_unique_id` = analytical identity, `customer_id` = record traceability) and the order → items/payments 1:many fan-out risk.

Do not guess table names, schemas, or parameter syntax if the repository already establishes them.

---

# Important Analytical Challenge: Repeat Definition

Q2/Q3/Q4 deserve special attention.

Repeat could mean (a) more than one order within the selected period, or (b) period-active customers ranked by lifetime history. The layer deliberately chooses (a) period-bounded as the default.

Before implementing, reason explicitly about why:

- Period-bounded is self-contained, reconcilable across Q2/Q3/Q4, and free of lookback bias.
- Lifetime semantics is valid but answers a different question and must live in a separate query if ever needed.

The goal is not merely to produce SQL that runs.

The goal is to produce a defensible analytical definition.

If a definition requires an assumption, do not hide it — document it in the SQL file comments (see `repeat_customer_rate.sql` header) rather than silently choosing one.

The same principle applies to Q5: document why first-ever discovery must scan full history before range filtering.

---

# Scope Boundary

Do NOT:

- configure Genie
- create a Genie Space/Agent
- create an NLP layer
- introduce LangChain
- create a frontend
- implement sales/revenue analytics beyond what is required for Q4
- implement product analytics
- implement seller analytics
- implement payment analytics
- implement delivery analytics
- implement geographic analytics
- modify the Gold layer unless a genuine blocking issue is discovered

If you discover a problem in Gold that affects these queries, stop and report it rather than silently changing Gold.

---

# Expected Deliverable

At the end:

1. Five SQL scripts exist under `sql/customer_analytics/`.
2. Each script has a clear business purpose (Q1–Q5 above).
3. Each query follows the agreed definitions (`order_purchase_timestamp`, `customer_unique_id`, `payment_value` for Q4).
4. Duplicate counting risks are addressed (no item/payment fan-out in counts; order-grain classification before payment join in Q4).
5. Parameters are implemented appropriately (`:start_date` / `:end_date`, with Q5 acquisition-window semantics called out).
6. Validation approach/results are documented (`validation.sql` V1–V5, all PASS before trusting the layer).
7. No unrelated architecture or technology is introduced.

Do NOT commit or push automatically unless explicitly asked.

After implementation, report:

- files created
- key design decisions (especially period-bounded repeat + first-ever new-customer logic)
- any assumptions
- validation performed
- any issues/questions requiring human review

The human will review the implementation before Git commit/push.

---

# Development Philosophy

The SQL Analytics layer is intended to become a trusted analytical foundation that can later be used by:

- Databricks Genie
- another LLM
- a lightweight local model
- a custom application

The AI should not be the only place where business logic exists.

The SQL layer should encode verified, reusable analytical patterns that an AI system can reference and adapt for more specific natural-language questions.

Build each vertical slice (Sales & Revenue, then Customer) properly before expanding to other categories.
