-- =============================================================================
-- TASK 5: Revenue Waterfall — New / Expansion / Contraction / Churn
-- =============================================================================
--
-- CONTEXT:
-- The Finance team's most important Power BI dashboard is the revenue waterfall.
-- It categorizes each account's year-over-year revenue change into New, Expansion,
-- Contraction, or Churn. This is core to how JetBrains tracks subscription health.
-- Rebuild the logic in SQL for the Tableau migration.
--
-- SCHEMA:
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ accounts                                                               │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ account_id         │ INT (PK)       │ Unique account identifier        │
-- │ company_name       │ VARCHAR(200)   │ Company name                     │
-- │ region             │ VARCHAR(30)    │ 'EMEA', 'APAC', 'Americas'      │
-- │ segment            │ VARCHAR(20)    │ 'Enterprise', 'SMB',             │
-- │                    │                │ 'Individual'                     │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ annual_revenue                                                         │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ account_id         │ INT (FK)       │ References accounts              │
-- │ fiscal_year        │ INT            │ e.g. 2023, 2024, 2025            │
-- │ total_revenue_usd  │ DECIMAL(12,2)  │ Total revenue from this account  │
-- │ license_count      │ INT            │ Number of active licenses        │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- SAMPLE ROWS:
-- accounts:
--   (10, 'DataWave GmbH',   'EMEA',     'Enterprise')
--   (11, 'Nirvana Labs',    'Americas',  'SMB')
--   (12, 'Solo Dev Studio', 'Americas',  'Individual')
--
-- annual_revenue:
--   (10, 2023, 15000.00, 25)   -- existing customer in 2023
--   (10, 2024, 18500.00, 30)   -- expanded in 2024
--   (11, 2023, 3200.00,   8)   -- existing customer in 2023
--   (11, 2024,    0.00,   0)   -- churned in 2024 (or row might be missing entirely)
--   (12, 2024, 1200.00,   4)   -- new in 2024
--
-- TASK:
-- Compare fiscal years 2023 and 2024 to classify each account's revenue change:
--
--   Category definitions:
--     - 'New':          Account has revenue in 2024 but NOT in 2023
--     - 'Churned':      Account has revenue in 2023 but NOT in 2024 (or 0)
--     - 'Expansion':    Account has revenue in both years and 2024 > 2023
--     - 'Contraction':  Account has revenue in both years and 2024 < 2023
--     - 'Flat':         Account has revenue in both years and 2024 = 2023
--
-- Return:
--   - revenue_category
--   - account_count
--   - revenue_2023 (total for that category)
--   - revenue_2024 (total for that category)
--   - net_change (revenue_2024 - revenue_2023)
--
-- Also write a second query that lists the top 10 accounts by absolute net
-- change (either positive or negative), including company_name, region,
-- segment, revenue_2023, revenue_2024, net_change, and revenue_category.
-- =============================================================================

-- YOUR SOLUTION BELOW:

/*
First query
*/
WITH both_year_revenues AS (
    SELECT
        a.account_id
        ,a.company_name
        ,a.region
        ,a.segment
        ,COALESCE(r2023.total_revenue_usd, 0) AS "revenue_2023"
        ,COALESCE(r2024.total_revenue_usd, 0) AS "revenue_2024"
    FROM accounts a
    LEFT JOIN annual_revenue r2023 ON a.account_id = r2023.account_id AND r2023.fiscal_year = 2023
    LEFT JOIN annual_revenue r2024 ON a.account_id = r2024.account_id AND r2024.fiscal_year = 2024
)
,categories AS (
    SELECT
        account_id
        ,company_name
        ,region
        ,segment
        ,revenue_2023
        ,revenue_2024
        ,CASE
            WHEN revenue_2023 = 0 AND revenue_2024 <> 0 THEN 'New'
            WHEN revenue_2023 <> 0 AND revenue_2024 = 0 THEN 'Churned'
            WHEN revenue_2023 <> 0 AND revenue_2024 <> 0 AND revenue_2023 = revenue_2024 THEN 'Flat'
            WHEN revenue_2023 <> 0 AND revenue_2024 <> 0 AND revenue_2023 > revenue_2024 THEN 'Contraction'
            WHEN revenue_2023 <> 0 AND revenue_2024 <> 0 AND revenue_2023 < revenue_2024 THEN 'Expansion'
            ELSE 'Unknown'
        END AS "revenue_category"
    FROM both_year_revenues
)
SELECT
    revenue_category
    ,COUNT(DISTINCT account_id) AS "account_count"
    ,SUM(revenue_2023) AS "revenue_2023"
    ,SUM(revenue_2024) AS "revenue_2024"
    ,SUM(revenue_2024) - SUM(revenue_2023) AS "net_change"
FROM categories
WHERE revenue_category <> 'Unknown'
GROUP BY revenue_category;

/*
Second query
Needs the same CTEs again repeated, but for simplicity not repeated here
CTEs only live until the next ";"
*/
SELECT
    company_name
    ,region
    ,segment
    ,revenue_2023
    ,revenue_2024
    ,revenue_2024 - revenue_2023 AS "net_change"
    ,revenue_category
FROM categories
WHERE revenue_category <> 'Unknown'
ORDER BY ABS(net_change) DESC
LIMIT 10;
