#!/usr/bin/env bash
# Starts Postgres, Redis, the API server, the worker, and the static frontend.
# Usage: bash scripts/start-dev.sh
set -e

echo "==> Starting PostgreSQL..."
service postgresql start || true
sleep 1

echo "==> Starting Redis..."
redis-cli ping > /dev/null 2>&1 || redis-server --daemonize yes --save "" --appendonly no
sleep 1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying database schema (idempotent)..."
PGPASSWORD=postgres psql -h localhost -U postgres -d ai_motion_studio -f "$ROOT/database/001_init.sql" > /dev/null 2>&1 || true

echo "==> Installing backend dependencies (skips if already installed)..."
cd "$ROOT/backend"
[ -d node_modules ] || npm install

echo "==> Seeding reference data (plans, templates, avatars, voices)..."
npx tsx prisma/seed.ts || true

mkdir -p "$ROOT/logs"

echo "==> Starting API server on :4000..."
setsid nohup npx tsx src/server.ts > "$ROOT/logs/server.log" 2>&1 < /dev/null &

echo "==> Starting worker..."
setsid nohup npx tsx src/worker.ts > "$ROOT/logs/worker.log" 2>&1 < /dev/null &

echo "==> Starting frontend on :8080..."
cd "$ROOT/frontend"
setsid nohup python3 -m http.server 8080 > "$ROOT/logs/frontend.log" 2>&1 < /dev/null &

sleep 2
echo ""
echo "==> Ready:"
echo "    Frontend: http://localhost:8080"
echo "    API:      http://localhost:4000/api/health"
echo "    Logs:     $ROOT/logs/{server,worker,frontend}.log"
