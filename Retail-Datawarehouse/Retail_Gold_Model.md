# Olist Retail Data Warehouse / Lakehouse
## Gold Business Layer - Locked Conceptual Model

**Status:** Conceptual Gold model locked  
**Next phase:** Implement in `04_gold_business_layer.ipynb` → validate → document → push to GitHub

---

# 1. Locked Gold scope

The Gold business layer will contain exactly **6 tables**:

### Facts
1. `fact_orders`
2. `fact_order_items`
3. `fact_payments`

### Dimensions
4. `dim_customer`
5. `dim_product`
6. `dim_seller`

### Intentionally excluded from Gold
- Reviews
- Geolocation

Bronze and Silver are already complete and are not being redesigned.

---

# 2. Modeling principles

- Grain comes before table design.
- Keep facts separate when their grains differ.
- Do not combine orders, order items, and payments into one giant fact.
- Use clear business/source keys where appropriate.
- Keep Gold business-friendly and NLP-friendly.
- Avoid unnecessary joins and duplicated attributes.
- `customer_unique_id` is the primary analytical customer identity.
- `customer_id` identifies the order-associated customer record and is retained for traceability.
- Gold should expose authoritative sources for business metrics.
- Timestamps remain timestamps in Gold. Date/time splitting can be handled later by AI/BI/query layers when needed.

---

# 3. Final naming convention

## Table naming

Use lowercase `snake_case` with a role prefix:

```text
fact_orders
fact_order_items
fact_payments

dim_customer
dim_product
dim_seller
```

Do not use uppercase table names such as `FACT_ORDERS`.

## Column naming

Use lowercase `snake_case`.

Rules:

- `_id` for identifiers.
- `_timestamp` for timestamp fields.
- `_date` only when the field is actually a date.
- Use descriptive business names.
- Correct source naming/typos when presenting the Gold layer.
- Do not blindly preserve source-system naming inconsistencies.

Example:

```text
product_name_length
product_description_length
```

The Gold layer is the clean business-facing schema even when Silver preserves source conventions.

---

# 4. Final schemas

## `fact_orders`

### Grain
**1 row per order**

### Key
`order_id`

### Final schema

| Column | Role |
|---|---|
| `order_id` | Order business/source key |
| `customer_unique_id` | Primary analytical customer identity |
| `customer_id` | Order-associated customer record / source traceability |
| `order_status` | Order lifecycle status |
| `order_purchase_timestamp` | Purchase timestamp |
| `order_approved_at` | Approval timestamp |
| `order_delivered_carrier_date` | Carrier handoff timestamp |
| `order_delivered_customer_date` | Customer delivery timestamp |
| `order_estimated_delivery_date` | Estimated delivery timestamp |

---

## `fact_order_items`

### Grain
**1 row per order item**

### Key
`(order_id, order_item_id)`

### Final schema

| Column | Role |
|---|---|
| `order_id` | Order key |
| `order_item_id` | Item sequence within order |
| `product_id` | Product key |
| `seller_id` | Seller key |
| `shipping_limit_date` | Shipping deadline |
| `price` | Item price |
| `freight_value` | Freight amount |

---

## `fact_payments`

### Grain
**1 row per payment record within an order**

### Key
`(order_id, payment_sequential)`

### Final schema

| Column | Role |
|---|---|
| `order_id` | Order key |
| `payment_sequential` | Payment sequence within order |
| `payment_type` | Payment method |
| `payment_installments` | Installment count |
| `payment_value` | Payment amount |

---

## `dim_customer`

### Grain
**1 row per `customer_id`**

### Key
`customer_id`

### Business identity
`customer_unique_id`

### Final schema

| Column | Role |
|---|---|
| `customer_id` | Customer-record identifier |
| `customer_unique_id` | Real/business customer identity |
| `customer_zip_code_prefix` | Customer regional attribute |
| `customer_city` | Customer city |
| `customer_state` | Customer state |

### Customer identity rule

```text
customer_unique_id
        |
        +---- customer_id A
        +---- customer_id B
        +---- customer_id C
```

`customer_unique_id` is the field to use for customer-level analytics such as:

- unique customer count
- orders per customer
- revenue per customer
- customer-level behavior

`customer_id` is retained to identify the specific customer record associated with an order and for source traceability.

For order-specific customer attributes:

```text
fact_orders.customer_id
        |
        v
dim_customer.customer_id
```

---

## `dim_product`

### Grain
**1 row per product**

### Key
`product_id`

### Final schema

| Column | Role |
|---|---|
| `product_id` | Product key |
| `product_category_name` | Original product category |
| `product_category_name_english` | English category translation |
| `product_name_length` | Product-name length |
| `product_description_length` | Product-description length |
| `product_photos_qty` | Number of product photos |
| `product_weight_g` | Product weight |
| `product_length_cm` | Product length |
| `product_height_cm` | Product height |
| `product_width_cm` | Product width |

The category translation remains an enrichment inside `dim_product`. No separate category dimension is created.

---

## `dim_seller`

### Grain
**1 row per seller**

### Key
`seller_id`

### Final schema

| Column | Role |
|---|---|
| `seller_id` | Seller key |
| `seller_zip_code_prefix` | Seller regional attribute |
| `seller_city` | Seller city |
| `seller_state` | Seller state |

---

# 5. Final relationship model

```text
                         dim_customer
                              |
                              | 1 : many
                              | customer_id
                              v
                         fact_orders
                         /          \
                        /            \
               1 : many                1 : many
                    /                      \
                   v                        v
          fact_order_items            fact_payments
              /        \
             /          \
            v            v
       dim_product   dim_seller
```

## Cardinalities

| Relationship | Cardinality | Key |
|---|---|---|
| `dim_customer` → `fact_orders` | 1 : many | `customer_id` |
| `fact_orders` → `fact_order_items` | 1 : many | `order_id` |
| `fact_orders` → `fact_payments` | 1 : many | `order_id` |
| `dim_product` → `fact_order_items` | 1 : many | `product_id` |
| `dim_seller` → `fact_order_items` | 1 : many | `seller_id` |

---

# 6. Customer analytical model

There are deliberately two customer identifiers with different purposes.

```text
customer_unique_id
        ↓
Who is the real customer?
```

```text
customer_id
        ↓
Which source/order-associated customer record is this?
```

Customer-level analytics should normally use:

```sql
GROUP BY customer_unique_id
```

Example:

```sql
SELECT
    customer_unique_id,
    COUNT(DISTINCT order_id) AS order_count
FROM fact_orders
GROUP BY customer_unique_id;
```

The model does not require us to reconstruct unique customer identity by grouping `customer_id` first.

---

# 7. Geography decision

A separate `dim_geography` is **not** part of Gold.

Reason:

Customer and seller business tables already contain the geography required for the project's regional use cases:

```text
dim_customer
-------------
customer_zip_code_prefix
customer_city
customer_state
```

```text
dim_seller
----------
seller_zip_code_prefix
seller_city
seller_state
```

The project wants regional business analysis rather than exact geographic coordinates.

The Silver `geolocation` table is large and does not provide a clean one-to-one `zip_code_prefix -> city/state` mapping, so forcing it into Gold would add complexity without enough business value.

### NLP rule

```text
Customer geography → dim_customer
Seller geography   → dim_seller
```

No separate geography join is required.

The Silver geolocation table can remain available for future specialized analysis or enrichment.

---

# 8. Review decision

A review fact was considered but intentionally excluded from Gold.

Silver validation showed:

```text
total_reviews           = 99,145
distinct_review_ids     = 98,332
duplicate_review_ids    = 788
orders_with_reviews     = 98,594
orders_with_multiple_reviews = 547
orders_without_reviews = 847
orphan_reviews          = 0
```

The relationship was confirmed as:

```text
fact_orders
    1
    |
    | 0..many
    v
reviews
```

However, `review_id` was not unique in the available Silver data, and review text would introduce additional cleaning and semantic complexity.

For the current project scope, reviews remain in Silver but are not promoted to Gold.

---

# 9. Why multiple facts are intentional

The facts have different grains:

```text
fact_orders
    1 row / order

fact_order_items
    1 row / order item

fact_payments
    1 row / payment record
```

They must remain separate.

Example:

```text
1 order
3 order items
2 payments
```

A naive join can create:

```text
3 × 2 = 6 rows
```

and multiply additive measures.

Therefore:

- order metrics come from `fact_orders`
- item metrics come from `fact_order_items`
- payment metrics come from `fact_payments`

---

# 10. Metric policy for the first Gold implementation

No additional derived business metrics will be added at this stage.

The first implementation will establish clean, trustworthy Gold grains and relationships.

Derived metrics can be introduced afterward once the core layer is working and validated.

---

# 11. Timestamp policy

Timestamp columns remain as timestamps.

Examples:

```text
order_purchase_timestamp
order_approved_at
order_delivered_carrier_date
order_delivered_customer_date
order_estimated_delivery_date
shipping_limit_date
```

We will not split them into separate date/hour fields during this Gold build.

AI/BI tools or later semantic/query layers can derive date/time components when needed.

---

# 12. Transformation policy

The Silver → Gold transformation and join rules will be implemented directly in:

```text
Retail-datawarehouse/
└── 04_gold_business_layer.ipynb
```

The exact transformation logic will be finalized during implementation.

Because the Gold schemas are now locked, implementation should focus on:

- selecting required Silver columns
- renaming to Gold naming convention
- applying the required joins
- preserving the declared grain
- writing Delta Gold tables

---

# 13. Validation policy

Gold validation will happen after the transformations are implemented.

Validation should confirm at minimum:

- declared grain is preserved
- primary/business keys are unique
- expected row counts are reasonable
- joins do not multiply rows
- foreign-key relationships resolve
- no unexpected nulls are introduced in important keys
- metric totals reconcile with Silver where appropriate

---

# 14. Implementation handoff

The conceptual work is now complete.

## Locked decisions

- [x] Six Gold tables
- [x] `fact_orders`
- [x] `fact_order_items`
- [x] `fact_payments`
- [x] `dim_customer`
- [x] `dim_product`
- [x] `dim_seller`
- [x] Reviews excluded from Gold
- [x] Geolocation excluded from Gold
- [x] No separate category dimension
- [x] `customer_unique_id` = analytical customer identity
- [x] `customer_id` retained for customer-record/order traceability
- [x] Customer/seller geography stored directly in their dimensions
- [x] No additional derived metrics for first implementation
- [x] Timestamps remain timestamps
- [x] Lowercase `snake_case` naming convention
- [x] Gold schemas locked

## Next implementation sequence

```text
1. Open 04_gold_business_layer.ipynb
2. Load required Silver tables
3. Build dim_customer
4. Build dim_product
5. Build dim_seller
6. Build fact_orders
7. Build fact_order_items
8. Build fact_payments
9. Validate grains, keys, joins, and counts
10. Document Gold layer
11. Commit/push to GitHub
```

**No conceptual redesign is planned unless implementation exposes a genuine data inconsistency or broken assumption.**

---

# 15. Coding Agent Handoff

## Purpose

The conceptual Gold model and final schemas are locked.

The immediate goal is to use **OpenCode** to generate the boilerplate and transformation code for:

```text
Retail-datawarehouse/04_gold_business_layer.ipynb
```

OpenCode should make implementation and review easier, not replace the human review process.

## Agent responsibilities

1. Read this file before modifying the notebook.
2. Inspect the repository and the existing `04_gold_business_layer.ipynb`.
3. Inspect existing Silver notebooks/code and follow established conventions.
4. Write the PySpark/SQL boilerplate and transformations for the six locked Gold tables.
5. Keep the declared grains, keys, relationships, and final columns unchanged.
6. Organize the notebook into clear, logical cells.
7. Run code where useful to catch obvious syntax or transformation errors.
8. Do not redesign the conceptual model or add tables/metrics without explicit approval.

## Human review workflow

The intended workflow is:

```text
OpenCode
   ↓
Generate / edit notebook
   ↓
Review locally
   ↓
Push to GitHub
   ↓
Sync/pull into Databricks
   ↓
Review each cell
   ↓
Run cells in Databricks
   ↓
Validate Gold tables
```

OpenCode may run code during development. The final notebook execution and business validation will be confirmed manually in Databricks.

## Guardrails

- Bronze and Silver are complete.
- Do not modify Bronze or Silver.
- Do not redesign the Gold model.
- Do not add `fact_reviews`.
- Do not add `dim_geography`.
- Do not add a separate category dimension.
- Do not introduce derived business metrics in the first Gold build.
- Keep timestamps as timestamps.
- Use lowercase `snake_case`.
- Preserve table grains.
- Avoid joins that can multiply fact rows.
- Use `customer_unique_id` for customer-level analytical aggregation.
- Retain `customer_id` for the customer-record/order relationship and traceability.

## Locked Gold tables

```text
fact_orders
fact_order_items
fact_payments
dim_customer
dim_product
dim_seller
```

## Implementation sequence

```text
1. Load Silver sources
2. Build dim_customer
3. Build dim_product
4. Build dim_seller
5. Build fact_orders
6. Build fact_order_items
7. Build fact_payments
8. Validate
```

The agent should ask before making any architectural change that conflicts with this document.
