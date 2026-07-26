# Database

PostgreSQL, real SQL in `database/001_init.sql` (see `README.md` for why this is raw
SQL + `pg` instead of Prisma in this build). `backend/prisma/schema.prisma` documents
the same model in Prisma DSL for future migration.

## Entity groups

**Auth/Users**: `User`, `Session`, `PasswordResetToken`, `EmailVerificationToken`, `UserSettings`
**Billing**: `Plan`, `Subscription`, `Payment`, `WebhookEvent`
**Credits**: `CreditWallet`, `CreditTransaction`
**Projects/Generation**: `Project`, `VideoGenerationJob`, `VideoScene`, `MediaAsset`, `VideoExport`
**Library**: `Template`, `Avatar`, `Voice`, `AudioGeneration`
**Misc**: `Notification`, `UsageLog`, `AuditLog`

Full column list: see `database/001_init.sql` (readable, ~300 lines) or `backend/prisma/schema.prisma`.

## The credit ledger — the one part of this schema you should read carefully

`CreditWallet` has two numbers:
- `balance` — credits the user can still spend right now
- `reserved` — credits held against jobs that are currently in flight (already subtracted from `balance`)

Every single mutation to either number writes a row to `CreditTransaction`
(`type` ∈ `reserve|commit|refund|grant|expire`, with `balanceAfter` recorded). There is
no code path that changes a wallet without a matching ledger row — this is what makes
`GET /credits/transactions` a complete audit trail, not just a log.

State machine per job:
1. **reserve** (job created): `balance -= cost`, `reserved += cost`
2. Either:
   - **commit** (job completes): `reserved -= cost`, `balance` unchanged (the spend already happened at reserve time)
   - **refund** (job fails or is canceled): `balance += cost`, `reserved -= cost` — full reversal

All four ledger operations (`reserveCredits`, `commitCredits`, `refundCredits`,
`addCredits` in `backend/src/services/creditService.ts`) run inside a Postgres
transaction using `SELECT ... FOR UPDATE` to lock the wallet row, so concurrent
requests for the same user can't race past each other and overspend. This is exercised
by `backend/src/__tests__/credits.test.ts`.

Pricing itself (`calculateGenerationCost`) lives only in this service — the client
never supplies a cost, and any `cost`/`creditsReserved` field sent in a request body is
silently ignored by the Zod schema (extra keys aren't in the shape, so they're dropped).

## Indexes
Every foreign-keyed "belongs to a user" table (`Session`, `PasswordResetToken`,
`CreditTransaction`, `Project`, `VideoGenerationJob`, `MediaAsset`) has an index on
`userId` for the common "list mine" queries. `VideoGenerationJob` also indexes
`projectId`.

## Soft deletes
`User`, `Project` use `deletedAt` rather than hard deletes, so generation history and
audit trails survive account/project deletion. All list/read queries filter
`WHERE "deletedAt" IS NULL`.
