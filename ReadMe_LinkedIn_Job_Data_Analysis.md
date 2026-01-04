# 📌 Skill Intelligence from Job Postings (Databricks + Spark)

## 🔍 Project Overview

This project builds an **end-to-end skill intelligence pipeline** using large-scale job posting data date from the year 2024 to analyze **Data Engineer skill demand**, **skill relationships**, and **capability clusters**.

Instead of treating skills as isolated keywords, the project focuses on:
- **Skill normalization**
- **Co-occurrence analysis**
- **Similarity-based clustering**

to uncover **real-world capability bundles** within Data Engineering roles.

The entire workflow is implemented on **Databricks using Apache Spark**, following scalable data engineering and analytics best practices.

---

## 🎯 Objectives

- Extract technical skills from job descriptions using NLP
- Normalize skill variants into canonical capabilities
- Identify which skills frequently appear together
- Reduce popularity bias using Jaccard similarity
- Reveal hidden skill clusters within Data Engineering roles

---

## 📊 Dataset

- **Source:** LinkedIn job postings (Parquet format) year 2024
- **Size:** ~200 MB, millions of rows
- **Storage:** Databricks Unity Catalog Volume
- **Key Fields Used:**
  - `job_id`
  - `title`
  - `description`
  - `skills_desc` (optional)

---

## 🏗️ Architecture & Pipeline

- Raw Job Postings (Parquet)

- Data Cleaning & Deduplication

- Role Filtering (Data Engineer)

- Text Preprocessing (NLP)

- Skill Extraction (Regex-based)

- Skill Normalization (Ontology)

- Skill Co-occurrence Analysis

- Jaccard Similarity Computation

- Skill Clustering & Insights


---

## 🔧 Key Techniques Used

### 1. Skill Extraction
- Regex-based detection of predefined technical skills
- Whole-word matching to avoid false positives
- Spark UDF applied at scale

---

### 2. Skill Normalization (Ontology Layer)

Canonical skills were created to group multiple variants under a single capability.

**Example:**

| Canonical Skill | Variants |
|----------------|----------|
| Spark | spark, pyspark, apache spark |
| AWS | aws, s3, ec2, redshift |
| SQL | sql, postgresql, mysql |

This prevents double counting and improves analytical accuracy.

---

### 3. Skill Co-occurrence Analysis

- Job descriptions converted into **binary skill vectors**
- Self-join on job IDs to generate all skill pairs
- Counts how often two skills appear in the same job

This answers:
> *Which skills are typically required together?*

---

### 4. Jaccard Similarity (Bias Reduction)

Raw co-occurrence counts are biased toward popular skills (e.g., SQL).

To correct this, **Jaccard similarity** is used:
J(A, B) = |A ∩ B| / |A ∪ B|


This measures **relationship strength**, not popularity.

---

## Example Insights

- Python, Spark, and AWS form the strongest capability bundle
- SQL is ubiquitous but not always a strong differentiator
- Analytics engineering tools form a distinct skill cluster
- Platform skills appear mainly in infrastructure-focused roles

---


