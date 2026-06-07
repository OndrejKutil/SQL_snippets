-- =============================================================================
-- TASK 6: Plugin Marketplace Engagement Rankings
-- =============================================================================
--
-- CONTEXT:
-- The Marketplace team is building a new Tableau dashboard to track plugin
-- ecosystem health. They need a query that ranks plugins by a composite score
-- combining downloads, ratings, and recent activity. The old Power BI report
-- used hardcoded thresholds — the new version should use percentiles.
--
-- SCHEMA:
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ plugins                                                                │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ plugin_id          │ INT (PK)       │ Unique plugin identifier         │
-- │ plugin_name        │ VARCHAR(150)   │ e.g. 'Lombok Support'           │
-- │ vendor_name        │ VARCHAR(100)   │ Author / publisher name          │
-- │ category           │ VARCHAR(50)    │ 'Code Tools', 'UI Themes',      │
-- │                    │                │ 'Version Control', 'Frameworks', │
-- │                    │                │ 'Languages'                      │
-- │ compatible_product │ VARCHAR(100)   │ e.g. 'IntelliJ IDEA'            │
-- │ first_published    │ DATE           │ When the plugin was published    │
-- │ is_paid            │ BOOLEAN        │ true = commercial plugin         │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ plugin_downloads                                                       │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ download_id        │ BIGINT (PK)    │ Unique download identifier       │
-- │ plugin_id          │ INT (FK)       │ References plugins               │
-- │ download_date      │ DATE           │ Day of download                  │
-- │ user_id            │ INT (FK)       │ References users                 │
-- │ product_id         │ INT (FK)       │ Which IDE was used               │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ plugin_ratings                                                         │
-- ├────────────────────┬────────────────┬──────────────────────────────────┤
-- │ rating_id          │ INT (PK)       │ Unique rating identifier         │
-- │ plugin_id          │ INT (FK)       │ References plugins               │
-- │ user_id            │ INT (FK)       │ References users                 │
-- │ rating             │ SMALLINT       │ 1 to 5 stars                     │
-- │ rating_date        │ DATE           │ When the rating was submitted    │
-- └────────────────────┴────────────────┴──────────────────────────────────┘
--
-- SAMPLE ROWS:
-- plugins:
--   (1, 'Lombok Support', 'Michail Plushnikov', 'Code Tools', 'IntelliJ IDEA', '2015-04-10', false)
--   (2, 'Material Theme UI', 'Atom Material', 'UI Themes', 'IntelliJ IDEA', '2017-08-22', true)
--
-- plugin_downloads:
--   (1, 1, '2025-01-05', 842, 1)
--   (2, 1, '2025-01-05', 900, 1)
--
-- plugin_ratings:
--   (1, 1, 842, 5, '2024-11-20')
--   (2, 1, 900, 4, '2024-12-03')
--
-- TASK:
-- For each plugin, compute:
--   - total_downloads: all-time download count
--   - downloads_last_90d: downloads in the last 90 days (relative to '2025-03-31')
--   - avg_rating: average rating rounded to 2 decimal places
--   - rating_count: number of ratings
--   - download_rank: rank by total_downloads (DENSE_RANK, desc)
--   - download_percentile: PERCENT_RANK of total_downloads within the plugin's
--     category, rounded to 2 decimals
--
-- Filter to only plugins with at least 10 downloads and at least 3 ratings.
-- Return: plugin_name, vendor_name, category, is_paid, total_downloads,
--         downloads_last_90d, avg_rating, rating_count, download_rank,
--         download_percentile
-- Order by total_downloads DESC.
-- =============================================================================

-- YOUR SOLUTION BELOW:
WITH plugin_stats AS (
    SELECT
        p.plugin_id
        ,COUNT(DISTINCT d.download_id) AS "total_downloads"
        ,ROUND(AVG(r.rating), 2) AS "avg_rating"
        ,COUNT(DISTINCT r.rating_id) AS "rating_count"
        ,COUNT(
            DISTINCT
            CASE
                WHEN d.download_date BETWEEN '2025-03-31'::DATE - INTERVAL '90 days' AND '2025-03-31' THEN d.download_id
            END
        ) AS "downloads_last_90d"

    FROM plugins p
    LEFT JOIN plugin_downloads d ON d.plugin_id = p.plugin_id
    LEFT JOIN plugin_ratings r ON p.plugin_id = r.plugin_id
    GROUP BY 1
)
SELECT
    p.plugin_name
    ,p.vendor_name
    ,p.category
    ,p.is_paid
    ,s.total_downloads
    ,s.downloads_last_90d
    ,s.avg_rating
    ,s.rating_count
    ,DENSE_RANK() OVER (ORDER BY total_downloads DESC) AS "download_rank"
    ,ROUND(
        PERCENT_RANK() OVER (PARTITION BY category ORDER BY total_downloads)
        , 2) AS "download_percentile"
FROM plugin_stats s
LEFT JOIN plugins p ON s.plugin_id = p.plugin_id
WHERE s.total_downloads >= 10 AND s.rating_count >= 3
ORDER BY s.total_downloads DESC
