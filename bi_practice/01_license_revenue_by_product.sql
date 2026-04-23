-- =============================================================================
-- TASK 1: Monthly License Revenue by Product (with MoM Growth)
-- =============================================================================
-- 
-- CONTEXT:
-- The Sales team is migrating their "Revenue Overview" Power BI dashboard to
-- Tableau. They need a base query that feeds the monthly revenue trend chart,
-- broken down by product. The Tableau worksheet expects month-level granularity
-- with month-over-month growth calculated server-side.
--
-- SCHEMA:
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ products                                                               │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ product_id         │ INT (PK)       │ Unique product identifier        │
-- │ product_name       │ VARCHAR(100)   │ e.g. 'IntelliJ IDEA Ultimate'   │
-- │ product_family     │ VARCHAR(50)    │ e.g. 'IDE', 'Team Tools', '.NET'│
-- │ release_year       │ INT            │ Year of first release            │
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
-- │ expiry_date        │ DATE           │ When the license expires         │
-- │ amount_usd         │ DECIMAL(10,2)  │ Revenue in USD                   │
-- │ currency_original  │ VARCHAR(3)     │ Original purchase currency       │
-- │ amount_original    │ DECIMAL(10,2)  │ Revenue in original currency     │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- SAMPLE ROWS:
-- products:
--   (1, 'IntelliJ IDEA Ultimate', 'IDE', 2001)
--   (2, 'PyCharm Professional',   'IDE', 2010)
--   (3, 'TeamCity Cloud',         'Team Tools', 2021)
--
-- licenses:
--   (1001, 55, 1, 'new',     '2024-03-15', '2025-03-14', 499.00, 'EUR', 459.00)
--   (1002, 55, 1, 'renewal', '2025-03-15', '2026-03-14', 399.00, 'EUR', 369.00)
--   (1003, 78, 2, 'new',     '2024-06-01', '2025-05-31', 199.00, 'USD', 199.00)
--
-- TASK:
-- Write a query that returns monthly revenue per product for 2024 and 2025.
-- Include:
--   - month (as first day of month, e.g. '2024-01-01')
--   - product_name
--   - product_family
--   - total_revenue (sum of amount_usd)
--   - license_count (number of licenses sold)
--   - mom_growth_pct (month-over-month revenue growth as a percentage,
--     NULL for the first month of each product)
--
-- Order by product_name, then month.
-- =============================================================================

-- YOUR SOLUTION BELOW:

WITH licenses_filtered AS (
    SELECT *
    FROM licenses
    WHERE purchase_date >= '2024-01-01' AND purchase_date <= '2025-12-31'
)
,monthly_revenue_per_product AS (
    SELECT 
        p.product_id
        ,DATE_TRUNC('month', l.purchase_date) AS "month_purchase_r"
        ,SUM(l.amount_usd) AS "revenue"
    FROM licenses_filtered l
    JOIN products p ON p.product_id = l.product_id
    GROUP BY 1, 2
)
,monthly_license_count_per_product AS (
    SELECT 
        p.product_id
        ,DATE_TRUNC('month', l.purchase_date) AS "month_purchase_l"
        ,COUNT(DISTINCT l.license_id) AS "license_count"
    FROM licenses_filtered l
    JOIN products p ON p.product_id = l.product_id
    GROUP BY 1, 2
)
,months AS (
    SELECT GENERATE_SERIES('2024-01-01'::DATE
                            ,'2025-12-01'::DATE
                            ,'1 month'::INTERVAL)::DATE AS month
)
,base_table AS (
    SELECT 
        m.month,
        p.product_id,
        p.product_name,
        p.product_family
    FROM months m
    CROSS JOIN products p
)
SELECT
    b.month
    ,b.product_name
    ,b.product_family
    ,COALESCE(r.revenue, 0) AS "total_revenue" -- COALESCE to return 0 instead of NULL
    ,COALESCE(l.license_count, 0) AS "license_count" -- COALESCE to return 0 instead of NULL
    -- NULLIF(x, y) returns NULL if x = y
    -- LAG() safely returns NULL if previous value is not found
    ,((
        COALESCE(r.revenue, 0)  
        /
        NULLIF(LAG(COALESCE(r.revenue, 0)) OVER (PARTITION BY b.product_id ORDER BY b.month), 0)
    ) - 1) * 100 AS "mom_growth_pct"  -- multiply by 100 to get a percentage  
FROM base_table b
LEFT JOIN monthly_revenue_per_product r ON r.month_purchase_r = b.month AND r.product_id = b.product_id
LEFT JOIN monthly_license_count_per_product l ON l.month_purchase_l = b.month AND l.product_id = b.product_id
ORDER BY b.product_name, b.month


    