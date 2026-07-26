# Limitations — what's simplified, stubbed, or out of scope, and why

Everything below is a deliberate, documented tradeoff — not an oversight. Nothing in
this app returns a fake "success" for something that didn't actually happen; where a
capability isn't implemented, it fails with a clear `503` rather than pretending.

## Prisma → raw SQL
**Why**: `binaries.prisma.sh` (Prisma's native query-engine CDN) isn't reachable from
this sandbox's network allowlist. Every `prisma migrate`/`generate` call failed with a
403. Rather than fake an ORM layer, the app uses real parameterized SQL via
`node-postgres`, against the same schema (kept as `schema.prisma` for documentation and
future migration). All the safety Prisma would have given you here — parameterized
queries, transactions, row locking — is present, just written by hand.

## AI generation providers are mocked
**Why**: no real video/voice-generation API keys were available to configure. The
`mock` provider is not a fake success responder — it genuinely invokes FFmpeg and
produces real, playable video/audio files (verified via `ffprobe` in testing) — but the
*content* is a placeholder (a gradient with the prompt burned in as text, or a tone for
audio) rather than actual generated video/speech. Swapping in a real provider is a
scoped adapter implementation (see `docs/deployment.md#4`), not a rewrite — every route,
the queue, the credit ledger, and the job lifecycle are already provider-agnostic.

## Payments are mocked
**Why**: no live Stripe/Razorpay account. `PAYMENT_PROVIDER=mock` simulates a
checkout + webhook round trip locally (`POST /billing/checkout` → `devCheckoutUrl` →
`POST /billing/dev-simulate-payment/:id` fires the exact same code path a real webhook
would). The webhook idempotency, signature-verification scaffold, and credit-granting
logic are real and tested; only the "redirect to a hosted checkout page" and "receive a
webhook from a real provider" parts are stand-ins.

## Video editor is a flat timeline blob, not a compositor
`Project.timeline` is an arbitrary JSON document the frontend can read/write via
`GET/PATCH /projects/:id/editor`. There's no server-side multi-track FFmpeg
compositing engine (overlaying text/transitions/effects onto the base render). `POST
/projects/:id/render` currently just re-surfaces the project's latest completed
generation as the "export." Building a real compositor (parsing the timeline JSON into
an FFmpeg filter graph) is a substantial project on its own and was out of scope here.

## Image-to-video doesn't actually analyze the uploaded image
The uploaded image is stored as a real `MediaAsset` and referenced on the job, but the
mock video provider doesn't read pixel data from it — same placeholder-gradient
renderer as text-to-video. A real provider adapter would pass the image through to
whatever generative API is configured.

## Voice "generation" is a tone, not speech synthesis
No TTS engine was available in this sandbox (checked for `espeak`/`espeak-ng`/`festival`
— none installed, and installing one would require reaching outside the network
allowlist). The mock voice provider renders a real WAV file (sine tone, duration scaled
to text length, with fade in/out) rather than actual synthesized speech. Voice *sample
previews* in the Voice Studio library use the same mechanism and are real, playable
files — just not speech.

## Duplicate project doesn't duplicate scenes/assets
`POST /projects/:id/duplicate` copies the `Project` row (title, type, duration,
resolution, timeline) but not its child `VideoScene`/`MediaAsset` rows. Marked 🟡 in
the mapping doc for this reason.

## No email delivery
Password reset and email verification tokens are generated and stored for real, but
nothing sends an email — there's no mail provider configured. In non-production,
`POST /auth/forgot-password` returns the token directly in the response
(`devResetToken`) specifically so the reset flow is end-to-end testable without a mail
server; this field is omitted when `NODE_ENV=production`.

## Rate limiting and audit logging are minimal
`express-rate-limit` is in-memory (see `docs/deployment.md#10` for the multi-instance
fix). `AuditLog`/`UsageLog` tables exist with a working schema but aren't populated by
every action — only where used today.

## No frontend build pipeline
The frontend is hand-written HTML/CSS/JS with Tailwind loaded from a CDN — not the
React/TypeScript stack the original spec asked for. This was a deliberate tradeoff to
keep the whole thing runnable with zero build step in a sandboxed environment. The API
contracts are the same regardless of what the frontend is written in; a React rewrite
would consume the exact same endpoints in `docs/api.md`.
