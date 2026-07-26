# Deployment

This build is configured for local development. Nothing here is fake — the gaps below
are specifically the things that require infrastructure or credentials this sandbox
doesn't have (a live domain, cloud storage credentials, real provider API keys). Each
one is a config change or a small adapter, not a rewrite.

## 1. Database
- Point `DATABASE_URL` at your production Postgres (RDS, Cloud SQL, Supabase, etc).
- Apply `database/001_init.sql` once (it's plain SQL — run it via your migration tool
  of choice, or `psql -f`). If you later restore real network access to
  `binaries.prisma.sh`, you can regenerate an equivalent Prisma migration from
  `backend/prisma/schema.prisma` and swap the query layer back to `@prisma/client`
  without changing the schema.
- Enable connection pooling (PgBouncer or your provider's pooler) — the app uses a
  single long-lived `pg.Pool`, which is fine behind a pooler but won't itself pool
  across multiple backend instances.

## 2. Redis / Queue
- Point `REDIS_URL` at a managed Redis (ElastiCache, Upstash, Redis Cloud).
- Run `npm run worker:build` (compiled) as its own process/container — it must stay
  running independently of the API for jobs to be processed. Scale by running more
  worker replicas; BullMQ's `concurrency` option in `worker.ts` controls per-process
  parallelism.

## 3. Object storage (replace local disk)
`backend/src/lib/storage.ts` defines a `StorageDriver` interface with exactly four
methods (`put`, `getAbsolutePath`, `getPublicUrl`, `delete`, `exists`). To go to S3:

```ts
class S3Storage implements StorageDriver {
  // use @aws-sdk/client-s3 + @aws-sdk/s3-request-presigner
  // put() -> PutObjectCommand
  // getPublicUrl() -> getSignedUrl() with an expiry, or a public CDN URL if the bucket is public
  // delete() -> DeleteObjectCommand
  // exists() -> HeadObjectCommand
}
```
Set `STORAGE_DRIVER=s3` plus `STORAGE_ENDPOINT/BUCKET/REGION/ACCESS_KEY/SECRET_KEY`,
swap the export in `storage.ts`. No route code changes — every route calls the
interface, not the local implementation directly. Once this is live, `routes/files.ts`
becomes dead code (S3 URLs are served directly).

## 4. Real AI providers
`backend/src/providers/registry.ts` is the single switch point. For each of
`VIDEO_PROVIDER` / `VOICE_PROVIDER` / `AVATAR_PROVIDER`:
1. Implement a class satisfying `VideoProvider`/`VoiceProvider`/`AvatarProvider` from
   `providers/types.ts` (e.g. `RunwayVideoProvider`, `ElevenLabsVoiceProvider`).
2. Add a branch in the matching `getXProvider()` function keyed on the provider name.
3. Set the env var + its `*_API_KEY`.

Until you do this, setting a provider name other than `mock` without implementing the
adapter fails loudly with `503 PROVIDER_NOT_IMPLEMENTED` — it will never silently fall
back to mock and claim success. This is intentional (see the constitution's stance on
fake success responses).

## 5. Real payments
Same pattern in `routes/billing.ts`. Implement the provider's checkout-session
creation in `POST /checkout` (replacing the `PAYMENT_PROVIDER=mock` branch), and
verify real webhook signatures in `POST /webhook` (the HMAC verification scaffold is
already there, keyed on `PAYMENT_WEBHOOK_SECRET` — swap in the provider's actual
signature scheme, e.g. Stripe's `stripe-signature` header verification). The
idempotency handling (`WebhookEvent.eventId` unique constraint) doesn't need to change.

## 6. Secrets
Generate fresh `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` for production (never reuse
the dev ones committed nowhere but generated into your local `.env`). Set
`COOKIE_SECURE=true` once you're behind HTTPS — cookies won't be sent over plain HTTP
otherwise, which is correct but will look like broken auth if you forget to enable TLS
first.

## 7. Frontend
It's static files with zero build step — deploy `frontend/` to any static host (S3+CloudFront,
Netlify, Vercel static, Nginx). Set `window.AMS_API_URL` (top of `<body>` in
`index.html`) to your real API origin, and set `FRONTEND_URL` in the backend `.env` to
match exactly (CORS is origin-locked, not wildcard, since cookies are used).

## 8. Process management
Run `server.ts` (API) and `worker.ts` as separate, independently-restartable processes
(systemd units, separate ECS services/Kubernetes deployments, or `pm2`). Don't run the
worker inside the API process — a slow FFmpeg render blocking the event loop would
degrade API latency for everyone.

## 9. Observability
`pino` is already structured JSON logging (`pino-http` per-request). Ship
`logs`/stdout to your aggregator of choice. `AuditLog` and `UsageLog` tables exist but
aren't populated by every action yet — wire up the actions you care about tracking
(the tables and a straightforward `INSERT` are all that's needed).

## 10. Rate limiting at scale
The current rate limiter (`express-rate-limit`) is in-memory per-process — fine for a
single instance, but each replica behind a load balancer will have its own counter.
For multi-instance deployments, swap to `rate-limit-redis` as the store, pointed at the
same Redis used for the queue.
