# AI Motion Studio

A full-stack AI video generation SaaS: landing page, auth, credits/billing, a real
generation pipeline (text/image/script-to-video, AI avatars, voice studio), a project
library, and a browser-based editor shell.

This is a **real, running application**, not a mockup:
- PostgreSQL for all data (22 tables — users, sessions, credits ledger, projects, jobs, assets, plans, payments, templates, avatars, voices, notifications, audit log...)
- Redis + BullMQ for the generation job queue, consumed by a standalone worker process
- FFmpeg renders real, playable MP4/WAV files (mock content — a real generative model isn't wired up — but the render pipeline, job lifecycle, and files are real)
- Every credit deduction is an atomic, row-locked ledger transaction — see `docs/api.md#credits`

## One important note on the stack

The spec called for Prisma. This environment's network could not reach
`binaries.prisma.sh`, which Prisma needs to download its native query engine, so the
database layer uses **raw parameterized SQL via `node-postgres` (`pg`)** instead.
`backend/prisma/schema.prisma` is kept as the canonical, documented data model — the
real tables in `database/001_init.sql` are a direct 1:1 translation of it. If you have
unrestricted network access, migrating this to real Prisma is a mechanical change:
regenerate a matching Prisma migration from `schema.prisma` and swap the query layer.

## Quickstart

Requires: Node 20+, PostgreSQL 16, Redis, FFmpeg (all pre-installed in this sandbox).

```bash
bash scripts/start-dev.sh
```

This starts Postgres, Redis, applies the schema, seeds reference data (plans,
templates, avatars, voices), and boots the API server (`:4000`), the worker, and the
static frontend (`:8080`).

Open **http://localhost:8080**, sign up (free, 15 starting credits), and generate a
video from the Create Video page — it runs a real job through the real queue and
gives you back a real downloadable MP4.

## Manual setup

See `docs/setup.md` for step-by-step instructions if you're not using the script, and
`docs/deployment.md` for what changes in a real production deployment (S3, a real
payment provider, a real video-generation provider, TLS, etc).

## Project layout

```
backend/     Express + TypeScript API, worker, provider adapters, tests
database/    SQL schema (source of truth for the live DB)
frontend/    Static HTML/CSS/JS app (no build step) + js/api/* client modules
docs/        API reference, database docs, setup/deployment guides, this mapping
scripts/     start-dev.sh
```

## Docs index

- `docs/frontend-backend-mapping.md` — every UI feature mapped to its endpoint, with an honest status marker (🟢 real / 🟡 minimal / ⚪ needs real provider credentials)
- `docs/api.md` — full API reference
- `docs/database.md` — schema reference and the credit-ledger invariants
- `docs/setup.md` — manual local setup
- `docs/deployment.md` — what to change for production
- `docs/limitations.md` — everything intentionally simplified or stubbed, and why

## Tests

```bash
cd backend
npm test
```

19 integration tests run against the real Postgres/Redis/FFmpeg stack (not mocks) —
registration, login/session, credit reservation/insufficient-credit rejection,
ownership isolation, a full text-to-video job through the real worker producing a real
file, webhook idempotency for billing.
