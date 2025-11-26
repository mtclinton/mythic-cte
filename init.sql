-- Massive Greek mythology themed seed script for stressing recursive vs non-recursive CTEs.
-- Place this file in docker-entrypoint-initdb.d/ to auto-load when the Postgres volume is empty.

\timing on

CREATE TABLE deities (
    id          SERIAL PRIMARY KEY,
    name        TEXT        NOT NULL,
    epithet     TEXT        NOT NULL,
    domain      TEXT        NOT NULL,
    parent_id   INT REFERENCES deities(id),
    generation  INT         NOT NULL,
    origin      TEXT        NOT NULL
);

CREATE TABLE heroes (
    id               SERIAL PRIMARY KEY,
    name             TEXT        NOT NULL,
    city_state       TEXT        NOT NULL,
    patron_deity_id  INT REFERENCES deities(id),
    fame_rank        INT         NOT NULL,
    birth_era        INT         NOT NULL
);

CREATE TABLE myths (
    id                SERIAL PRIMARY KEY,
    title             TEXT        NOT NULL,
    hero_id           INT REFERENCES heroes(id) NOT NULL,
    primary_deity_id  INT REFERENCES deities(id) NOT NULL,
    era               TEXT        NOT NULL,
    disaster_index    INT         NOT NULL,
    origin_region     TEXT        NOT NULL
);

CREATE TABLE quests (
    id            BIGSERIAL PRIMARY KEY,
    hero_id       INT REFERENCES heroes(id) NOT NULL,
    quest_type    TEXT        NOT NULL,
    success       BOOLEAN     NOT NULL,
    difficulty    INT         NOT NULL,
    started_at    TIMESTAMPTZ NOT NULL,
    completed_at  TIMESTAMPTZ,
    region        TEXT        NOT NULL
);

CREATE TABLE omens (
    id           BIGSERIAL PRIMARY KEY,
    deity_id     INT REFERENCES deities(id) NOT NULL,
    region       TEXT        NOT NULL,
    omen_type    TEXT        NOT NULL,
    severity     INT         NOT NULL,
    observed_at  TIMESTAMPTZ NOT NULL,
    interpreter  TEXT        NOT NULL
);

CREATE TABLE battle_logs (
    id                 BIGSERIAL PRIMARY KEY,
    hero_id            INT REFERENCES heroes(id) NOT NULL,
    opposing_deity_id  INT REFERENCES deities(id) NOT NULL,
    location           TEXT        NOT NULL,
    casualties         INT         NOT NULL,
    outcome            TEXT        NOT NULL,
    battle_ts          TIMESTAMPTZ NOT NULL
);

CREATE INDEX ON deities (parent_id);
CREATE INDEX ON heroes (patron_deity_id);
CREATE INDEX ON myths (hero_id);
CREATE INDEX ON myths (primary_deity_id);
CREATE INDEX ON quests (hero_id);
CREATE INDEX ON quests (started_at);
CREATE INDEX ON omens (deity_id);
CREATE INDEX ON omens (observed_at);
CREATE INDEX ON battle_logs (hero_id);
CREATE INDEX ON battle_logs (opposing_deity_id);

-- Canonical Olympians & primordial figures
INSERT INTO deities (id, name, epithet, domain, parent_id, generation, origin) VALUES
    (1,  'Chaos',      'Gaping Void',       'Primordial', NULL, 0, 'Cosmos'),
    (2,  'Gaia',       'All-Mother',        'Earth',      1,    1, 'Cosmos'),
    (3,  'Uranus',     'Star-Father',       'Sky',        1,    1, 'Cosmos'),
    (4,  'Cronus',     'Time-Keeper',       'Harvest',    2,    2, 'Mount Othrys'),
    (5,  'Rhea',       'Flowing Queen',     'Fertility',  2,    2, 'Mount Othrys'),
    (6,  'Zeus',       'Cloud-Gatherer',    'Sky',        4,    3, 'Olympus'),
    (7,  'Hera',       'Protector',         'Marriage',   4,    3, 'Olympus'),
    (8,  'Poseidon',   'Earthshaker',       'Sea',        4,    3, 'Sea'),
    (9,  'Hades',      'Unseen One',        'Underworld', 4,    3, 'Underworld'),
    (10, 'Demeter',    'Green-Thumbed',     'Harvest',    4,    3, 'Eleusis'),
    (11, 'Hestia',     'Hearth-Keeper',     'Hearth',     4,    3, 'Olympus'),
    (12, 'Athena',     'Grey-Eyed',         'Wisdom',     6,    4, 'Athens'),
    (13, 'Apollo',     'Far-Darter',        'Sun',        6,    4, 'Delphi'),
    (14, 'Artemis',    'Huntress',          'Hunt',       6,    4, 'Delos'),
    (15, 'Ares',       'Spear-Blood',       'War',        7,    4, 'Thrace'),
    (16, 'Aphrodite',  'Foam-Born',         'Love',       3,    4, 'Cythera'),
    (17, 'Hermes',     'Guide of Souls',    'Travel',     6,    4, 'Olympus'),
    (18, 'Dionysus',   'Liberator',         'Revelry',    6,    4, 'Nysa');

-- Extend the pantheon with thousands of synthetic deities for recursive workloads
INSERT INTO deities (id, name, epithet, domain, parent_id, generation, origin)
SELECT
    18 + gs AS id,
    'Minor Deity #' || gs AS name,
    (ARRAY['Storm-Bearer','Earth-Shaper','Light-Warden','Deep-Seer','Harbor-Keeper','Wind-Tamer','Frost-Weaver','Flame-Singer'])[1 + (random() * 7)::INT] AS epithet,
    (ARRAY['Sky','Sea','Earth','Craft','War','Love','Hunt','Harvest','Justice','Medicine','Music'])[1 + (random() * 10)::INT] AS domain,
    CASE
        WHEN gs <= 1000 THEN 1 + (random() * 17)::INT
        ELSE 18 + (random() * (gs - 1))::INT
    END AS parent_id,
    4 + (gs / 5000) AS generation,
    (ARRAY['Olympus','Delphi','Athens','Sparta','Thrace','Crete','Lesbos','Rhodes','Syracuse','Alexandria'])[1 + (random() * 9)::INT] AS origin
FROM generate_series(1, 120000) AS gs;

SELECT setval(pg_get_serial_sequence('deities', 'id'), (SELECT MAX(id) FROM deities));

-- Famous heroes to anchor lookups
INSERT INTO heroes (id, name, city_state, patron_deity_id, fame_rank, birth_era) VALUES
    (1, 'Heracles',     'Thebes',   6,  1, -1260),
    (2, 'Perseus',      'Argos',    6,  5, -1300),
    (3, 'Odysseus',     'Ithaca',  17,  3, -1200),
    (4, 'Theseus',      'Athens',  12,  4, -1280),
    (5, 'Jason',        'Iolcos',   6,  6, -1300),
    (6, 'Achilles',     'Phthia',  13,  2, -1180),
    (7, 'Atalanta',     'Arcadia', 14, 12, -1280),
    (8, 'Bellerophon',  'Corinth', 13,  7, -1400),
    (9, 'Orpheus',      'Thrace',  13, 10, -1350),
    (10,'Cadmus',       'Thebes',  12,  8, -1500),
    (11,'Medea',        'Colchis', 14, 11, -1300),
    (12,'Hippolyta',    'Themyscira',15, 9, -1250);

SELECT setval(pg_get_serial_sequence('heroes', 'id'), (SELECT MAX(id) FROM heroes));

WITH deity_bounds AS (SELECT MAX(id) AS deity_max FROM deities)
INSERT INTO heroes (name, city_state, patron_deity_id, fame_rank, birth_era)
SELECT
    'Heroic Figure #' || gs,
    (ARRAY['Athens','Sparta','Thebes','Argos','Corinth','Rhodes','Lesbos','Delphi','Miletus','Ephesus','Byzantion','Pergamon'])[1 + (random() * 11)::INT],
    (random() * (deity_bounds.deity_max - 1))::INT + 1,
    (random() * 100)::INT + 1,
    -1600 + (gs % 900)
FROM generate_series(1, 150000) AS gs, deity_bounds;

WITH hero_bounds AS (SELECT MAX(id) AS hero_max FROM heroes),
     deity_bounds AS (SELECT MAX(id) AS deity_max FROM deities)
INSERT INTO myths (title, hero_id, primary_deity_id, era, disaster_index, origin_region)
SELECT
    'Mythic Cycle #' || gs,
    (random() * (hero_bounds.hero_max - 1))::INT + 1,
    (random() * (deity_bounds.deity_max - 1))::INT + 1,
    (ARRAY['Bronze Age','Heroic Age','Classical','Hellenistic'])[1 + (random() * 3)::INT],
    (random() * 100)::INT,
    (ARRAY['Peloponnese','Ionia','Thrace','Crete','Macedon','Lycia','Phrygia','Cyprus'])[1 + (random() * 7)::INT]
FROM generate_series(1, 400000) AS gs, hero_bounds, deity_bounds;

WITH hero_bounds AS (SELECT MAX(id) AS hero_max FROM heroes)
INSERT INTO quests (hero_id, quest_type, success, difficulty, started_at, completed_at, region)
SELECT
    (random() * (hero_bounds.hero_max - 1))::INT + 1,
    (ARRAY['labour','trial','voyage','oracle','siege','rescue','hunt','pilgrimage'])[1 + (random() * 7)::INT],
    random() < 0.62,
    (random() * 10)::INT + 1,
    NOW() - (gs % 2000) * INTERVAL '1 day' - (gs % 86400) * INTERVAL '1 second',
    CASE
        WHEN random() < 0.8 THEN NOW() - (gs % 1980) * INTERVAL '1 day'
        ELSE NULL
    END,
    (ARRAY['Ionia','Peloponnese','Thrace','Crete','Asia Minor','Aegean','Egypt','Sicily','Black Sea','Libya'])[1 + (random() * 9)::INT]
FROM generate_series(1, 1500000) AS gs, hero_bounds;

WITH deity_bounds AS (SELECT MAX(id) AS deity_max FROM deities)
INSERT INTO omens (deity_id, region, omen_type, severity, observed_at, interpreter)
SELECT
    (random() * (deity_bounds.deity_max - 1))::INT + 1,
    (ARRAY['Dodona','Delphi','Athens','Sparta','Olympia','Pergamon','Knossos','Alexandria','Carthage','Byblos'])[1 + (random() * 9)::INT],
    (ARRAY['eclipse','comet','dream','oracle','sacrifice','storm','earthquake','plague','meteor'])[1 + (random() * 8)::INT],
    (random() * 10)::INT,
    NOW() - (gs % 365) * INTERVAL '1 day' - (gs % 86400) * INTERVAL '1 second',
    (ARRAY['Pythia','Sibyl','Oracle of Trophonius','Augur Lysander','Seeress Dione','Interpreter Melas','Prophetess Corycia'])[1 + (random() * 6)::INT]
FROM generate_series(1, 2000000) AS gs, deity_bounds;

WITH hero_bounds AS (SELECT MAX(id) AS hero_max FROM heroes),
     deity_bounds AS (SELECT MAX(id) AS deity_max FROM deities)
INSERT INTO battle_logs (hero_id, opposing_deity_id, location, casualties, outcome, battle_ts)
SELECT
    (random() * (hero_bounds.hero_max - 1))::INT + 1,
    (random() * (deity_bounds.deity_max - 1))::INT + 1,
    (ARRAY['Phlegra','Marathon','Troy','Thermopylae','Pylos','Nemea','Delos','Aegina'])[1 + (random() * 7)::INT],
    (random() * 5000)::INT,
    (ARRAY['victory','defeat','stalemate','pact'])[1 + (random() * 3)::INT],
    NOW() - (gs % 2500) * INTERVAL '1 day'
FROM generate_series(1, 500000) AS gs, hero_bounds, deity_bounds;

-- Recursive CTE showcase: full lineage expansion
CREATE OR REPLACE VIEW vw_pantheon_lineage AS
WITH RECURSIVE lineage AS (
    SELECT
        id,
        name,
        parent_id,
        domain,
        generation,
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
        d.generation,
        lineage.depth + 1 AS depth,
        lineage.lineage_path || ' > ' || d.name AS lineage_path
    FROM deities d
    JOIN lineage ON d.parent_id = lineage.id
)
SELECT id, name, domain, generation, depth, lineage_path
FROM lineage;

-- Non-recursive, multi-CTE analytics for omens
CREATE OR REPLACE VIEW vw_recent_omen_pressure AS
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
JOIN region_density rd ON rd.region = dr.region;

-- Non-recursive CTE comparison for hero quest performance
CREATE OR REPLACE VIEW vw_hero_quest_success AS
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
LEFT JOIN recent_battles rb ON rb.hero_id = h.id;

ANALYZE;

