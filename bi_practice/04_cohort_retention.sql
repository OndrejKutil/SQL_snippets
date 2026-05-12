-- =============================================================================
-- TASK 4: Customer Retention Cohorts
-- =============================================================================
--
-- CONTEXT:
-- Finance and Customer Success teams need a cohort retention matrix for the
-- Tableau migration. The existing Power BI report uses a custom DAX measure.
-- You need to rebuild this in SQL so Tableau can use a direct connection.
--
-- SCHEMA:
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ accounts                                                               │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ account_id         │ INT (PK)       │ Unique account identifier        │
-- │ company_name       │ VARCHAR(200)   │ e.g. 'Acme Corp'                │
-- │ industry           │ VARCHAR(50)    │ 'Technology', 'Finance', etc.    │
-- │ employee_count     │ INT            │ Company size                     │
-- │ region             │ VARCHAR(30)    │ 'EMEA', 'APAC', 'Americas'      │
-- │ first_purchase_date│ DATE           │ Date of very first purchase      │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ licenses                                                               │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ license_id         │ INT (PK)       │ Unique license identifier        │
-- │ account_id         │ INT (FK)       │ References accounts              │
-- │ product_id         │ INT (FK)       │ References products              │
-- │ license_type       │ VARCHAR(20)    │ 'new', 'renewal', 'upgrade'      │
-- │ purchase_date      │ DATE           │ When the license was purchased   │
-- │ amount_usd         │ DECIMAL(10,2)  │ Revenue in USD                   │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- SAMPLE ROWS:
-- accounts:
--   (10, 'DataWave GmbH', 'Technology', 120, 'EMEA', '2023-03-10')
--   (11, 'Nirvana Labs',  'Technology', 45,  'Americas', '2023-07-22')
--
-- licenses:
--   (2001, 10, 1, 'new',     '2023-03-10', 499.00)
--   (2002, 10, 1, 'renewal', '2024-03-09', 399.00)
--   (2003, 10, 2, 'new',     '2023-06-15', 199.00)
--   (2004, 11, 1, 'new',     '2023-07-22', 499.00)
--
-- TASK:
-- Build a cohort retention table where:
--   - Cohort is defined by the month of first_purchase_date (e.g. '2023-03')
--   - For each cohort, count how many accounts made at least one purchase 
--     (any license_type) in each subsequent month offset (month 0, 1, 2, ... 12)
--   - Month 0 = same month as first_purchase_date
--   - Month N = N months after the cohort month
--
-- Return:
--   - cohort_month (e.g. '2023-03')
--   - cohort_size (count of accounts in that cohort)
--   - month_offset (0 through 12)
--   - retained_accounts (count of accounts active in that offset month)
--   - retention_rate_pct (retained / cohort_size * 100, rounded to 1 decimal)
--
-- Only include cohorts from 2023. Order by cohort_month, month_offset.
-- =============================================================================

-- YOUR SOLUTION BELOW:
WITH base_table AS (
    SELECT
        TO_CHAR(cohort_month, 'YYYY-MM') AS "cohort_month",
        month_offset
    FROM 
        GENERATE_SERIES(
            '2023-01-01'::TIMESTAMP,
            '2023-12-01'::TIMESTAMP,
            '1 month'::INTERVAL
        ) AS cohort_month
    CROSS JOIN 
        GENERATE_SERIES(0, 12, 1) AS month_offset
)
,accounts_limited_to_2023 AS (
    SELECT
        account_id
        ,first_purchase_date
        ,TO_CHAR(first_purchase_date, 'YYYY-MM') AS "year_month"
    FROM accounts
    WHERE first_purchase_date BETWEEN '2023-01-01'::DATE AND '2023-12-31'::DATE
)
,cohort_sizes AS (
    SELECT 
        COUNT(DISTINCT account_id) AS "cohort_size"
        ,year_month
    FROM accounts_limited_to_2023
    GROUP BY year_month
)
,enhanced_base_table AS (
    SELECT 
        b.cohort_month
        ,c.cohort_size
        ,b.month_offset
    FROM base_table b
    LEFT JOIN cohort_sizes c ON c.year_month = b.cohort_month
)
,activity AS (
    SELECT 
        a.account_id
        ,a.first_purchase_date
        ,a.year_month
        ,(EXTRACT(YEAR FROM l.purchase_date) - EXTRACT(YEAR FROM a.first_purchase_date)) * 12 + (EXTRACT(MONTH FROM l.purchase_date) - EXTRACT(MONTH FROM a.first_purchase_date)) AS "offset_mon"
    FROM accounts_limited_to_2023 a
    LEFT JOIN licenses l ON l.account_id = a.account_id
)
,aggregated_activity AS (
    SELECT
        year_month
        ,offset_mon
        ,COUNT(DISTINCT account_id) AS "retained_accounts"
    FROM activity
    GROUP BY year_month, offset_mon
)
SELECT
    b.cohort_month
    ,COALESCE(b.cohort_size, 0) AS "cohort_size"
    ,b.month_offset
    ,COALESCE(a.retained_accounts, 0) AS "retained_accounts"
    ,ROUND(COALESCE((a.retained_accounts * 100.0) / NULLIF(b.cohort_size, 0), 0), 1) AS "retention_rate_pct"
FROM enhanced_base_table b
LEFT JOIN aggregated_activity a ON b.cohort_month = a.year_month AND b.month_offset = a.offset_mon
ORDER BY 1, 3 