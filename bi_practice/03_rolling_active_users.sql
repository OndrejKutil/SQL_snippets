-- =============================================================================
-- TASK 3: Rolling 7-Day Active Users per IDE (DAU/WAU)
-- =============================================================================
--
-- CONTEXT:
-- The Product Analytics team tracks engagement via daily/weekly active users.
-- Their Power BI report uses pre-aggregated tables; the Tableau migration needs
-- the raw SQL to be re-validated. This query feeds the engagement trends chart.
--
-- SCHEMA:
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ products                                                               │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ product_id         │ INT (PK)       │ Unique product identifier        │
-- │ product_name       │ VARCHAR(100)   │ e.g. 'GoLand'                   │
-- │ product_family     │ VARCHAR(50)    │ e.g. 'IDE'                      │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ usage_events                                                           │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ event_id           │ BIGINT (PK)    │ Unique event identifier          │
-- │ user_id            │ INT (FK)       │ References users                 │
-- │ product_id         │ INT (FK)       │ References products              │
-- │ event_date         │ DATE           │ Day the event occurred           │
-- │ event_type         │ VARCHAR(30)    │ 'session_start', 'file_open',    │
-- │                    │                │ 'build_run', 'debug_start',      │
-- │                    │                │ 'plugin_install'                 │
-- │ session_duration_s │ INT            │ Session length in seconds        │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- SAMPLE ROWS:
-- usage_events:
--   (1, 842, 4, '2025-01-15', 'session_start', 3600)
--   (2, 842, 4, '2025-01-15', 'build_run',     NULL)
--   (3, 900, 4, '2025-01-15', 'session_start', 1800)
--   (4, 842, 4, '2025-01-16', 'session_start', 7200)
--
-- TASK:
-- For each product and each day in January 2025:
--   1. Compute the DAU (distinct users with at least one event that day)
--   2. Compute the rolling 7-day active users (WAU): distinct users who had
--      at least one event in the current day or preceding 6 days (7-day window)
--   3. Compute the DAU/WAU ratio (also called "stickiness"), rounded to 2
--      decimal places
--
-- Return: product_name, event_date, dau, wau_7d, stickiness
-- Order by product_name, event_date
-- =============================================================================

-- YOUR SOLUTION BELOW:
WITH jan_days AS (
    SELECT 
        GENERATE_SERIES(
            '2025-01-01'::DATE,
            '2025-01-31'::DATE,
            '1 day'::INTERVAL
        )::DATE AS "days"
)
,base_table AS (
    SELECT d.days, p.product_id, p.product_name
    FROM jan_days d
    CROSS JOIN products p
)
,usage_events_filtered AS (
    SELECT *
    FROM usage_events
    WHERE event_date::date BETWEEN '2025-01-01'::DATE AND '2025-01-31'::DATE
)
,dau AS (
    SELECT
        event_date
        ,product_id
        ,COUNT(DISTINCT user_id) AS "dau"
    FROM usage_events_filtered
    GROUP BY 1, 2
)
/* 
Joining on the BETWEEN clause creates 7 rows per one day X product combination
(Given all previous 6 days are present in the data)
Then by group by we collapse it again to one row per the combination (combined with COUNT())
 */
,wau AS (
    SELECT
        b.days
        ,b.product_id
        ,COUNT(DISTINCT u.user_id) AS "wau_7d"
    FROM base_table b
    LEFT JOIN usage_events u ON b.product_id = u.product_id
        AND u.event_date BETWEEN b.days - INTERVAL '6 days' AND b.days
        -- casting to INTERVAL as many engines may not support just 'b.days - 6'
    GROUP BY 1, 2
)
SELECT
    b.product_name
    ,b.days
    ,COALESCE(d.dau, 0)
    ,COALESCE(w.wau_7d, 0)
    ,ROUND(COALESCE(d.dau * 100.0 / NULLIF(w.wau_7d, 0), 0), 2) AS "stickiness"
    -- if we divide by 0, engine trows fatal error, if we divide by NULL, engine evaluates it to NULL
FROM base_table b
LEFT JOIN dau d ON d.event_date = b.days AND d.product_id = b.product_id
LEFT JOIN wau w ON w.event_date = b.days AND w.product_id = b.product_id
ORDER BY 1, 2

