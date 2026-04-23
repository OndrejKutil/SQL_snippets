# JetBrains BI Analyst — SQL Practice Tasks

Practice queries designed to simulate real-world scenarios for a BI Analyst internship focused on **Power BI → Tableau migration**. All tasks are **read-only** (SELECT) — focused on data retrieval and transformation, not DDL or DML.

## Tasks Overview

| # | File | Topic | Key SQL Skills |
|---|------|-------|---------------|
| 1 | `01_license_revenue_by_product.sql` | Monthly revenue trends for Sales dashboard | `DATE_TRUNC`, `SUM`, `LAG` window function, MoM growth |
| 2 | `02_trial_conversion_funnel.sql` | Trial-to-paid conversion for Growth team | `LEFT JOIN` with date conditions, conditional aggregation, `FILTER` |
| 3 | `03_rolling_active_users.sql` | DAU/WAU stickiness for Product Analytics | Rolling `COUNT DISTINCT`, window frames, self-join approach |
| 4 | `04_cohort_retention.sql` | Customer retention cohorts for Finance | Date arithmetic, cohort grouping, `CROSS JOIN` + filtering |
| 5 | `05_revenue_waterfall.sql` | New/Expansion/Contraction/Churn breakdown | `FULL OUTER JOIN`, `COALESCE`, `CASE` classification |
| 6 | `06_plugin_marketplace_rankings.sql` | Plugin ecosystem health dashboard | `DENSE_RANK`, `PERCENT_RANK`, multi-table aggregation |
| 7 | `07_support_ticket_sla.sql` | SLA compliance for Support ops | `INTERVAL` arithmetic, `PERCENTILE_CONT`, timestamp math |
| 8 | `08_dbt_incremental_merge.sql` | dbt-style incremental model logic | `UNION ALL`, `ROW_NUMBER` deduplication, merge simulation |
| 9 | `09_cross_team_kpi_summary.sql` | Executive KPI scorecard | `UNION ALL` unpivoting, reaggregation from heterogeneous sources |
| 10 | `10_product_adoption_paths.sql` | Multi-product cross-sell analysis | Self-joins, `STRING_AGG`, pair counting, adoption sequences |

## How to Use

Each `.sql` file contains:
- **Context** — which team owns the dashboard and why the query matters
- **Schema** — complete table definitions with column names and types
- **Sample rows** — so you can reason about expected output
- **Task description** — exactly what to return, with hints where helpful

Write your solution below `-- YOUR SOLUTION BELOW:` in each file.

## Assumed Dialect

Queries are designed for **PostgreSQL** (common in dbt + analytics stacks), but most patterns transfer directly to BigQuery, Snowflake, or Redshift.
