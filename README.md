# Greek Mythology CTE Benchmark

This project ships a Postgres image preloaded with a large, mythology-themed dataset (hundreds of thousands of deities, heroes, myths, quests, omens, and battle logs). It is tuned for tutorials that contrast CTE-based SQL with equivalent non-CTE patterns so you can measure real runtime differences.

## Prerequisites

- Docker (24.x or newer recommended)
- ~4 GB free disk for the image and initialized volume
- Optional: `psql` client for running queries locally

## Build & Run

```bash
docker build -t mythic-cte .
docker run --rm \
  -p 5432:5432 \
  --name myth-db \
  -e POSTGRES_PASSWORD=supersecret \
  mythic-cte
```

On first startup, Postgres executes `init.sql`, which:
- Enables `\timing on` in the session so query durations are reported automatically.
- Creates the mythology schema, indexes, and seed data (millions of rows).
- Defines helper views (`vw_pantheon_lineage`, `vw_recent_omen_pressure`, `vw_hero_quest_success`).

Stopping and re-running the container reuses the seeded volume unless you mounted an external data directory. Delete the container or run with `-v /path/to/data:/var/lib/postgresql/data` if you need persistence across rebuilds.

## Connect and Explore

Default credentials match the `Dockerfile`, except the password must be supplied at runtime:

- DB: `app_db`
- User: `app_user`
- Password: whatever you pass via `POSTGRES_PASSWORD`

Connect with `psql`:

```bash
psql postgresql://app_user:supersecret@localhost:5432/app_db
```

`init.sql` already enables timing, but you can toggle manually with `\timing on`.

## Benchmark Queries

Use `benchmark_queries.sql` for ready-made pairs of CTE vs non-CTE statements:

```bash
psql postgresql://app_user:app_password@localhost:5432/app_db -f /home/max/projects/learning-cte/benchmark_queries.sql
```

Each section contains:
- Omen pressure analytics (multi-CTE vs repeated subqueries)
- Hero quest rollups (multi-CTE vs repeated subqueries)
- Pantheon lineage traversal (recursive CTE vs stacked self-joins)

To capture execution plans and timings, wrap any block with `EXPLAIN (ANALYZE, BUFFERS) ...`.

## Resetting the Data

If you need to rerun the seed from scratch:

1. Stop the container: `docker stop myth-db`
2. Remove any bound volume directory (if used) or run a new container with a fresh anonymous volume.
3. Restart via the `docker run` command above—the entrypoint will reapply `init.sql`.

