-- =============================================================================
-- TASK 2: Trial-to-Paid Conversion Funnel
-- =============================================================================
--
-- CONTEXT:
-- The Growth team wants to move their conversion funnel dashboard from Power BI
-- to Tableau. The key metric is trial-to-paid conversion rate segmented by
-- product and region. This query feeds both the funnel chart and the heatmap.
--
-- SCHEMA:
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ products                                                               │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ product_id         │ INT (PK)       │ Unique product identifier        │
-- │ product_name       │ VARCHAR(100)   │ e.g. 'WebStorm'                 │
-- │ product_family     │ VARCHAR(50)    │ e.g. 'IDE', 'Team Tools'        │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ trials                                                                 │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ trial_id           │ INT (PK)       │ Unique trial identifier          │
-- │ user_id            │ INT (FK)       │ References users                 │
-- │ product_id         │ INT (FK)       │ References products              │
-- │ trial_start_date   │ DATE           │ Start of the trial period        │
-- │ trial_end_date     │ DATE           │ End of 30-day trial              │
-- │ activation_source  │ VARCHAR(50)    │ 'website', 'ide_prompt',         │
-- │                    │                │ 'email_campaign', 'partner'      │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ users                                                                  │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ user_id            │ INT (PK)       │ Unique user identifier           │
-- │ email              │ VARCHAR(150)   │ User email                       │
-- │ country            │ VARCHAR(60)    │ e.g. 'Germany', 'Japan'          │
-- │ region             │ VARCHAR(30)    │ 'EMEA', 'APAC', 'Americas'      │
-- │ account_type       │ VARCHAR(20)    │ 'individual', 'organization'     │
-- │ signup_date        │ DATE           │ When they registered             │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ licenses                                                               │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ license_id         │ INT (PK)       │ Unique license identifier        │
-- │ user_id            │ INT (FK)       │ References users                 │
-- │ product_id         │ INT (FK)       │ References products              │
-- │ license_type       │ VARCHAR(20)    │ 'new', 'renewal', 'upgrade'      │
-- │ purchase_date      │ DATE           │ When the license was purchased   │
-- │ amount_usd         │ DECIMAL(10,2)  │ Revenue in USD                   │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- SAMPLE ROWS:
-- trials:
--   (1, 200, 3, '2024-09-01', '2024-09-30', 'website')
--   (2, 201, 3, '2024-09-05', '2024-10-04', 'ide_prompt')
--
-- licenses:
--   (5001, 200, 3, 'new', '2024-09-28', 249.00)
--
-- TASK:
-- For each product and region, calculate:
--   - total_trials: count of trials started in Q3 2024 (Jul–Sep)
--   - converted_trials: count of those trials where the SAME user bought
--     a 'new' license for the SAME product within 45 days of trial_start_date
--   - conversion_rate_pct: (converted_trials / total_trials) * 100, rounded
--     to 1 decimal
--   - avg_days_to_convert: average number of days between trial_start_date
--     and purchase_date for converted trials, rounded to 0 decimals
--
-- Only include rows where total_trials >= 5.
-- Order by conversion_rate_pct DESC.
-- =============================================================================

-- YOUR SOLUTION BELOW:
/* Prepare base table with all combinations of region x product */
WITH base_table AS (
    SELECT r.region, p.*
    FROM (
        SELECT DISTINCT region
        FROM users
    ) r
    CROSS JOIN (
        SELECT product_id, product_name
        FROM products
        GROUP BY 1, 2 -- Technically does not need to be here, as product_id should be unique. Safety net
    ) p
)
/* Filter trial_start_date to Q3 2024 (Jul–Sep) and add user region */
,trials_started_in_q3 AS (
    SELECT 
        t1.trial_id
        ,t1.product_id
        ,t1.user_id
        ,t1.trial_start_date
        ,u.region
    FROM trials t1
    LEFT JOIN users u ON t1.user_id = u.user_id
    WHERE t1.trial_start_date >= '2024-07-01' AND t1.trial_start_date <= '2024-09-30'
)
/* Add started trials count to the base table */
,total_trials_add AS (
    SELECT 
        b.region
        ,b.product_id
        ,b.product_name
        ,COUNT(DISTINCT t.trial_id) AS "total_trials"
    FROM base_table b
    LEFT JOIN trials_started_in_q3 t ON t.product_id = b.product_id AND t.region = b.region
    GROUP BY 1, 2, 3
)
/* First find, then add in another CTE */
,were_trials_converted AS (
    SELECT
        t.region
        ,t.product_id
        ,COUNT(DISTINCT t.trial_id) AS "converted_trials"
        ,ROUND(AVG(l.purchase_date - t.trial_start_date), 0) AS "avg_days_to_convert"
    FROM trials_started_in_q3 t
    INNER JOIN licenses l ON l.user_id = t.user_id AND l.product_id = t.product_id
    WHERE l.license_type = 'new'
        AND l.purchase_date >= t.trial_start_date
        AND l.purchase_date - t.trial_start_date <= 45
    GROUP BY 1, 2
)
/* Add converted trials amount */
,converted_trials_add AS (
    SELECT t1.*, t2.converted_trials, t2.avg_days_to_convert
    FROM total_trials_add t1
    LEFT JOIN were_trials_converted t2 ON t1.region = t2.region AND t1.product_id = t2.product_id
)
SELECT 
    region,
    product_id,
    product_name,
    total_trials,
    COALESCE(converted_trials, 0) AS converted_trials, -- converts nulls to specified value, here 0
    ROUND((COALESCE(converted_trials, 0) * 100.0 / total_trials), 1) AS "conversion_rate_pct", -- multiplies by 100.0 to prevent integer division dropping decimals
    avg_days_to_convert
FROM converted_trials_add
WHERE total_trials >= 5
ORDER BY conversion_rate_pct DESC

