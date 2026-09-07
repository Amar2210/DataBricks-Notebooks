# Task: Implement Sales & Revenue SQL Analytics Layer

## Project Context

I am building a production-oriented Data + AI portfolio project using the Olist Brazilian E-commerce dataset.

Architecture:

Raw Olist Data
→ BRONZE
→ SILVER
→ GOLD BUSINESS / DIMENSIONAL LAYER
→ SQL ANALYTICS
→ DATabricks Genie / Natural Language Interface

The Gold layer is already implemented, validated, committed, pushed to GitHub, and synchronized with Databricks.

The next task is to implement the **Sales & Revenue** portion of the SQL Analytics layer.

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

These definitions are already agreed and MUST be followed.

## Sales Date

Use:

`fact_orders.order_purchase_timestamp`

This represents when the customer placed the order.

Do not use approval, delivery, carrier, or estimated delivery timestamps for Sales & Revenue period filtering unless a specific future analytical question explicitly requires them.

## Revenue

For this project, define Revenue as:

> Total `payment_value` associated with orders purchased during the selected period.

The canonical calculation is based on `fact_payments.payment_value`, linked to orders through `order_id`.

Do NOT substitute:

- `fact_order_items.price`
- `fact_order_items.freight_value`

for Revenue.

Those are separate measures and may be used in future analytics.

## Orders

Orders means:

`COUNT(DISTINCT order_id)`

based on `fact_orders.order_purchase_timestamp`.

## AOV

Average Order Value:

`Revenue / COUNT(DISTINCT order_id)`

Revenue and order count must use the same selected order population.

## Important Join Warning

An order may have:

- multiple order items
- multiple payment records

Therefore, do NOT blindly join `fact_order_items` and `fact_payments` at row level and then sum payment values. This can multiply rows and overstate revenue.

For Sales & Revenue queries, only join tables required for the analytical question, and preserve the correct grain.

---

# Sales & Revenue Questions

Implement these 7 canonical analytical SQL scripts.

## Q1 — Total Revenue for a Selected Period

Business question:

> What is the total revenue for a selected date range?

Expected result:

A single KPI-style value.

Expected conceptual inputs:

- start date
- end date

Date filter must use:

`fact_orders.order_purchase_timestamp`

Revenue must be calculated from:

`fact_payments.payment_value`

---

## Q2 — Revenue Trend Over Time

Business question:

> How does revenue trend over a selected period?

Expected result:

A time-series table suitable for a line chart.

Example output structure:

| period | revenue |
|---|---:|
| 2017-01 | ... |
| 2017-02 | ... |
| 2017-03 | ... |

Use a sensible time grain such as month.

The query should support a selected date range.

Use `order_purchase_timestamp` for the time dimension.

---

## Q3 — Order Count for a Selected Period

Business question:

> How many orders were placed during a selected period?

Expected result:

A single KPI-style value.

Use:

`COUNT(DISTINCT fact_orders.order_id)`

Filter by:

`fact_orders.order_purchase_timestamp`

Do not count rows from `fact_order_items` or `fact_payments`.

---

## Q4 — Average Order Value

Business question:

> What is the Average Order Value for a selected period?

Expected result:

A single KPI-style value.

Definition:

`Revenue / Distinct Orders`

Revenue and distinct orders must be calculated over the same order population and date range.

Avoid division-by-zero errors.

---

## Q5 — Revenue by Product Category

Business question:

> Which product categories generate the most revenue?

Expected result:

A table such as:

| product_category | revenue |
|---|---:|
| ... | ... |
| ... | ... |

Use product category from `dim_product`.

The query should support a selected date range where appropriate.

Important modeling consideration:

An order can contain multiple products and multiple payments.

Do NOT create a many-to-many multiplication between `fact_order_items` and `fact_payments`.

You must design the query so payment values are not duplicated when attributing revenue to product category.

If attribution requires an explicit business assumption, document that assumption clearly in the SQL file comments rather than silently choosing one.

Also support the dataset's possible null / unknown product category values appropriately.

---

## Q6 — Order Volume by Product Category

Business question:

> Which product categories have the highest order volume?

Expected result:

| product_category | order_count |
|---|---:|
| ... | ... |

Use distinct `order_id`.

Be careful because an order can contain multiple products/items, so do not count item rows as orders.

Use `dim_product` to obtain the product category.

Support a selected date range.

---

## Q7 — Revenue by Customer State

Business question:

> Which customer states generate the most revenue?

Expected result:

| customer_state | revenue |
|---|---:|
| SP | ... |
| RJ | ... |
| ... | ... |

Use customer state from `dim_customer`.

Use `order_purchase_timestamp` for the selected date range.

Again, avoid payment duplication caused by joining multiple order items or multiple payment rows.

If revenue attribution across a relationship requires an explicit assumption, document it.

---

# Parameterization Requirements

Where a date range is relevant, make the query parameterized for:

- start date
- end date

Use the parameter syntax supported by the project's intended Databricks SQL execution environment.

Do not invent unsupported parameter syntax.

Before finalizing, inspect the repository for existing SQL/notebook conventions and follow the project's established style if one exists.

For category/state analytical queries, parameters may be added where genuinely useful, but do not over-parameterize the queries.

Do not create separate SQL files for individual months, years, categories, or states.

The goal is reusable analytical logic.

---

# Repository / File Structure

First inspect the existing repository structure.

Create the SQL Analytics layer following the project's existing naming conventions.

Preferred structure if no established convention conflicts:

`05_sql_analytics/sales_revenue/`

with:

- `revenue.sql`
- `revenue_trend.sql`
- `order_count.sql`
- `aov.sql`
- `category_revenue.sql`
- `category_order_volume.sql`
- `state_revenue.sql`

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

Use clear aliases and CTEs where they improve readability.

Do not over-engineer the queries with unnecessary CTEs.

Add concise comments for important business logic, especially:

- Revenue definition
- date semantics
- grain
- duplicate-payment/order-item risks
- any unavoidable attribution assumptions

Do not add technologies or abstractions just for portfolio appearance.

---

# Validation Requirements

Do not merely write syntactically valid SQL.

For each query, determine how it can be validated against the Gold data.

Where possible, create a small validation SQL/notebook section or clearly document validation queries separately, following the repository's conventions.

At minimum verify:

1. Revenue is not inflated by duplicate joins.
2. Order count is based on distinct orders.
3. AOV equals Revenue / Orders.
4. Date filtering uses `order_purchase_timestamp`.
5. Category revenue does not double-count payment values.
6. Category order volume counts distinct orders.
7. State revenue does not double-count payment values.

Use the existing Gold validation results as context but do not assume analytical correctness merely because Gold passed data-quality validation.

---

# Very Important: Investigate Before Coding

Before creating the seven scripts:

1. Inspect the repository structure.
2. Inspect existing Gold notebook/table creation code if needed.
3. Inspect naming conventions.
4. Confirm the exact catalog/schema/table references used by the project.
5. Determine the Databricks SQL parameter syntax appropriate to the project's environment.
6. Understand the Olist data relationships relevant to payment-to-order and item-to-order attribution.

Do not guess table names, schemas, or parameter syntax if the repository already establishes them.

---

# Important Analytical Challenge: Category Revenue

Q5 deserves special attention.

We need revenue by product category, but:

- `fact_payments` is at payment grain
- `fact_order_items` is at order-item grain

An order can have multiple items and multiple payments.

Therefore a naïve:

`fact_orders → fact_order_items → fact_payments`

join can multiply payment rows.

Before implementing `category_revenue.sql`, reason explicitly about the correct attribution method.

The goal is not merely to produce SQL that runs.

The goal is to produce a defensible analytical definition.

If the source data does not support a mathematically exact allocation of order-level payment value to individual categories without an assumption, do not hide that fact.

Choose a defensible approach, document it, and make the limitation clear.

The same principle applies to Q7 if joins introduce duplication.

---

# Scope Boundary

Do NOT:

- configure Genie
- create a Genie Space/Agent
- create an NLP layer
- introduce LangChain
- create a frontend
- implement customer analytics
- implement product analytics beyond what is required for Q5/Q6
- implement seller analytics
- implement payment analytics
- implement delivery analytics
- implement geographic analytics beyond Q7
- modify the Gold layer unless a genuine blocking issue is discovered

If you discover a problem in Gold that affects these queries, stop and report it rather than silently changing Gold.

---

# Expected Deliverable

At the end:

1. Seven SQL scripts exist under the appropriate Sales & Revenue SQL Analytics directory.
2. Each script has a clear business purpose.
3. Each query follows the agreed metric definitions.
4. Duplicate counting risks are addressed.
5. Parameters are implemented appropriately.
6. Validation approach/results are documented.
7. No unrelated architecture or technology is introduced.

Do NOT commit or push automatically unless explicitly asked.

After implementation, report:

- files created
- key design decisions
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

Build the first Sales & Revenue vertical slice properly before expanding to other categories.
