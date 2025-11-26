-- Benchmark-ready SQL script that prints only execution timings.
-- psql prints the label via \echo + elapsed time via \timing.

\pset pager off
\pset tuples_only on
\timing on

\echo 'Running benchmark suite...'

------------------------------------------------------------
-- 1) Omen pressure analytics (non-recursive case)
------------------------------------------------------------

-- CTE version: single scan of the last 14 days of omens.
\echo ''
\echo 'CTE - Omen pressure analytics'
\o /dev/null
WITH recent AS (
    SELECT *
    FROM omens
    WHERE observed_at >= NOW() - INTERVAL '14 days'
),
region_density AS (
    SELECT region, COUNT(*) AS total_omens, AVG(severity) AS avg_severity
    FROM recent
    GROUP BY region
),
deity_region AS (
    SELECT deity_id, region, COUNT(*) AS omen_count, AVG(severity) AS avg_severity
    FROM recent
    GROUP BY deity_id, region
)
SELECT
    dr.deity_id,
    d.name,
    d.domain,
    dr.region,
    dr.omen_count,
    dr.avg_severity,
    rd.total_omens AS region_total,
    rd.avg_severity AS region_avg
FROM deity_region dr
JOIN deities d ON d.id = dr.deity_id
JOIN region_density rd ON rd.region = dr.region
ORDER BY dr.omen_count DESC
LIMIT 25;
\o

-- Non-CTE version: repeated subqueries trigger two scans of the filtered omens.
\echo ''
\echo 'Non-CTE - Omen pressure analytics'
\o /dev/null
SELECT
    dr.deity_id,
    d.name,
    d.domain,
    dr.region,
    dr.omen_count,
    dr.avg_severity,
    rd.total_omens AS region_total,
    rd.avg_severity AS region_avg
FROM (
    SELECT deity_id, region, COUNT(*) AS omen_count, AVG(severity) AS avg_severity
    FROM omens
    WHERE observed_at >= NOW() - INTERVAL '14 days'
    GROUP BY deity_id, region
) dr
JOIN deities d ON d.id = dr.deity_id
JOIN (
    SELECT region, COUNT(*) AS total_omens, AVG(severity) AS avg_severity
    FROM omens
    WHERE observed_at >= NOW() - INTERVAL '14 days'
    GROUP BY region
) rd ON rd.region = dr.region
ORDER BY dr.omen_count DESC
LIMIT 25;
\o

------------------------------------------------------------
-- 2) Hero quest performance rollup (non-recursive case)
------------------------------------------------------------

-- CTE version: the quests table is scanned once per purpose.
\echo ''
\echo 'CTE - Hero quest performance'
\o /dev/null
WITH hero_effort AS (
    SELECT hero_id, COUNT(*) AS quests_attempted, AVG(difficulty) AS avg_difficulty
    FROM quests
    GROUP BY hero_id
),
hero_success AS (
    SELECT hero_id, AVG(CASE WHEN success THEN 1 ELSE 0 END) AS success_rate
    FROM quests
    GROUP BY hero_id
),
recent_battles AS (
    SELECT hero_id, COUNT(*) AS recent_battles
    FROM battle_logs
    WHERE battle_ts >= NOW() - INTERVAL '365 days'
    GROUP BY hero_id
)
SELECT
    h.id,
    h.name,
    h.city_state,
    he.quests_attempted,
    he.avg_difficulty,
    hs.success_rate,
    COALESCE(rb.recent_battles, 0) AS battles_last_year
FROM heroes h
JOIN hero_effort he ON he.hero_id = h.id
JOIN hero_success hs ON hs.hero_id = h.id
LEFT JOIN recent_battles rb ON rb.hero_id = h.id
ORDER BY he.quests_attempted DESC
LIMIT 25;
\o

-- Non-CTE version: redefines the same aggregations inline, forcing extra scans.
\echo ''
\echo 'Non-CTE - Hero quest performance'
\o /dev/null
SELECT
    h.id,
    h.name,
    h.city_state,
    he.quests_attempted,
    he.avg_difficulty,
    hs.success_rate,
    COALESCE(rb.recent_battles, 0) AS battles_last_year
FROM heroes h
JOIN (
    SELECT hero_id, COUNT(*) AS quests_attempted, AVG(difficulty) AS avg_difficulty
    FROM quests
    GROUP BY hero_id
) he ON he.hero_id = h.id
JOIN (
    SELECT hero_id, AVG(CASE WHEN success THEN 1 ELSE 0 END) AS success_rate
    FROM quests
    GROUP BY hero_id
) hs ON hs.hero_id = h.id
LEFT JOIN (
    SELECT hero_id, COUNT(*) AS recent_battles
    FROM battle_logs
    WHERE battle_ts >= NOW() - INTERVAL '365 days'
    GROUP BY hero_id
) rb ON rb.hero_id = h.id
ORDER BY he.quests_attempted DESC
LIMIT 25;
\o

------------------------------------------------------------
-- 3) Pantheon lineage (recursive case)
------------------------------------------------------------

-- Recursive CTE: explores arbitrary lineage depth.
\echo ''
\echo 'CTE - Pantheon lineage depth >= 8'
\o /dev/null
WITH RECURSIVE lineage AS (
    SELECT
        id,
        name,
        parent_id,
        domain,
        0 AS depth,
        name::TEXT AS lineage_path
    FROM deities
    WHERE parent_id IS NULL
    UNION ALL
    SELECT
        d.id,
        d.name,
        d.parent_id,
        d.domain,
        lineage.depth + 1 AS depth,
        lineage.lineage_path || ' > ' || d.name AS lineage_path
    FROM deities d
    JOIN lineage ON d.parent_id = lineage.id
)
SELECT *
FROM lineage
WHERE depth >= 8
ORDER BY depth DESC, name
LIMIT 50;
\o

-- Non-CTE approximation: fixed-depth self joins; expensive and limited.
\echo ''
\echo 'Non-CTE - Pantheon lineage via self joins'
\o /dev/null
SELECT
    d0.id   AS root_id,
    d6.id   AS node_id,
    d6.name AS node_name,
    CONCAT_WS(' > ', d0.name, d1.name, d2.name, d3.name, d4.name, d5.name, d6.name) AS lineage_path
FROM deities d0
LEFT JOIN deities d1 ON d1.parent_id = d0.id
LEFT JOIN deities d2 ON d2.parent_id = d1.id
LEFT JOIN deities d3 ON d3.parent_id = d2.id
LEFT JOIN deities d4 ON d4.parent_id = d3.id
LEFT JOIN deities d5 ON d5.parent_id = d4.id
LEFT JOIN deities d6 ON d6.parent_id = d5.id
WHERE d0.parent_id IS NULL
  AND d6.id IS NOT NULL
ORDER BY d6.id DESC
LIMIT 50;
\o

\timing off
\echo ''
\echo 'Benchmark suite complete.'

