# Setup (manual, without start-dev.sh)

## 1. Prerequisites
- Node.js 20+
- PostgreSQL 16 (or compatible)
- Redis 6+
- FFmpeg on `PATH`

## 2. Database
```bash
sudo service postgresql start
sudo -u postgres psql -c "CREATE DATABASE ai_motion_studio;"
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
psql -h localhost -U postgres -d ai_motion_studio -f database/001_init.sql
```

## 3. Redis
```bash
redis-server --daemonize yes
```

## 4. Backend
```bash
cd backend
cp .env.example .env
# Edit .env: set real JWT_ACCESS_SECRET / JWT_REFRESH_SECRET (long random strings),
# and DATABASE_URL if your Postgres isn't on localhost:5432 with the default creds above.
npm install
npx tsx prisma/seed.ts   # seeds plans, templates, avatars, voices (idempotent)
npm run dev               # API on :4000
```

In a second terminal:
```bash
cd backend
npm run worker            # consumes the generation queue
```

## 5. Frontend
Static files, no build step:
```bash
cd frontend
python3 -m http.server 8080
```
Open http://localhost:8080. If your API isn't on `http://localhost:4000`, set
`window.AMS_API_URL` in `frontend/index.html` (see the `<script>` near the top of the
`<body>`) before the `js/api/client.js` include.

## 6. Verify
```bash
curl http://localhost:4000/api/health
curl http://localhost:4000/api/plans
```
Both should return `{"success":true,...}`.

## Environment variables
See `.env.example` for the full list with comments. The important ones to know about:

| Variable | Default | What it does |
|---|---|---|
| `VIDEO_PROVIDER` / `VOICE_PROVIDER` / `AVATAR_PROVIDER` | `mock` | Set to a real provider name once you've implemented its adapter in `backend/src/providers/`. Leaving as `mock` renders real placeholder files via FFmpeg. |
| `PAYMENT_PROVIDER` | `mock` | Same pattern — `mock` simulates checkout+webhook locally so the upgrade flow is fully testable without a live payment account. |
| `STORAGE_DRIVER` | `local` | Writes rendered files to `backend/storage/`. Set to `s3` (after implementing `S3Storage` in `backend/src/lib/storage.ts`) for production. |
| `COOKIE_SECURE` | `false` | Set to `true` in production (HTTPS only). |

## Running tests
```bash
cd backend
npm test
```
Tests hit the real Postgres/Redis stack (not mocked) and expect the worker + Postgres
+ Redis to be reachable using the same `.env` as the dev server.
