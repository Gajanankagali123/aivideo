-- AI Motion Studio — initial schema
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE "User" (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL,
  email              TEXT NOT NULL UNIQUE,
  "passwordHash"     TEXT NOT NULL,
  "emailVerifiedAt"  TIMESTAMPTZ,
  "createdAt"        TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt"        TIMESTAMPTZ NOT NULL DEFAULT now(),
  "deletedAt"        TIMESTAMPTZ
);

CREATE TABLE "Session" (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"       UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "refreshToken" TEXT NOT NULL UNIQUE,
  "userAgent"    TEXT,
  ip             TEXT,
  "createdAt"    TIMESTAMPTZ NOT NULL DEFAULT now(),
  "expiresAt"    TIMESTAMPTZ NOT NULL,
  "revokedAt"    TIMESTAMPTZ
);
CREATE INDEX ON "Session" ("userId");

CREATE TABLE "PasswordResetToken" (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"    UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  token       TEXT NOT NULL UNIQUE,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "expiresAt" TIMESTAMPTZ NOT NULL,
  "usedAt"    TIMESTAMPTZ
);
CREATE INDEX ON "PasswordResetToken" ("userId");

CREATE TABLE "EmailVerificationToken" (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"    UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  token       TEXT NOT NULL UNIQUE,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "expiresAt" TIMESTAMPTZ NOT NULL,
  "usedAt"    TIMESTAMPTZ
);
CREATE INDEX ON "EmailVerificationToken" ("userId");

CREATE TABLE "UserSettings" (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"              UUID NOT NULL UNIQUE REFERENCES "User"(id) ON DELETE CASCADE,
  "emailNotifications"  BOOLEAN NOT NULL DEFAULT true,
  "productUpdates"      BOOLEAN NOT NULL DEFAULT true,
  language              TEXT NOT NULL DEFAULT 'en',
  "updatedAt"           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Plan" (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key              TEXT NOT NULL UNIQUE,
  name             TEXT NOT NULL,
  "monthlyCredits" INTEGER NOT NULL,
  "maxResolution"  TEXT NOT NULL,
  watermark        BOOLEAN NOT NULL,
  "priceCents"     INTEGER NOT NULL,
  currency         TEXT NOT NULL DEFAULT 'usd',
  features         JSONB NOT NULL,
  "createdAt"      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Subscription" (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"            UUID NOT NULL UNIQUE REFERENCES "User"(id) ON DELETE CASCADE,
  "planId"            UUID NOT NULL REFERENCES "Plan"(id),
  status              TEXT NOT NULL DEFAULT 'active',
  "currentPeriodEnd"  TIMESTAMPTZ NOT NULL,
  "cancelAtPeriodEnd" BOOLEAN NOT NULL DEFAULT false,
  "createdAt"         TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt"         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Payment" (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"      UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "planId"      UUID REFERENCES "Plan"(id),
  provider      TEXT NOT NULL,
  "providerRef" TEXT UNIQUE,
  "amountCents" INTEGER NOT NULL,
  currency      TEXT NOT NULL DEFAULT 'usd',
  status        TEXT NOT NULL,
  "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "WebhookEvent" (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider      TEXT NOT NULL,
  "eventId"     TEXT NOT NULL UNIQUE,
  payload       JSONB NOT NULL,
  "processedAt" TIMESTAMPTZ,
  "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "CreditWallet" (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"    UUID NOT NULL UNIQUE REFERENCES "User"(id) ON DELETE CASCADE,
  balance     INTEGER NOT NULL DEFAULT 0,
  reserved    INTEGER NOT NULL DEFAULT 0,
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "CreditTransaction" (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"       UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  type           TEXT NOT NULL,
  amount         INTEGER NOT NULL,
  reason         TEXT NOT NULL,
  "jobId"        UUID,
  "balanceAfter" INTEGER NOT NULL,
  "createdAt"    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ON "CreditTransaction" ("userId");

CREATE TABLE "Project" (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"      UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  type          TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'draft',
  "durationSec" INTEGER NOT NULL DEFAULT 10,
  resolution    TEXT NOT NULL DEFAULT '1080p',
  timeline      JSONB,
  "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt"   TIMESTAMPTZ NOT NULL DEFAULT now(),
  "deletedAt"   TIMESTAMPTZ
);
CREATE INDEX ON "Project" ("userId");

CREATE TABLE "VideoGenerationJob" (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"          UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "projectId"       UUID NOT NULL REFERENCES "Project"(id) ON DELETE CASCADE,
  type              TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'queued',
  stage             TEXT NOT NULL DEFAULT 'QUEUED',
  progress          INTEGER NOT NULL DEFAULT 0,
  input             JSONB NOT NULL,
  "creditsReserved" INTEGER NOT NULL,
  "resultAssetId"   UUID,
  error             TEXT,
  "createdAt"       TIMESTAMPTZ NOT NULL DEFAULT now(),
  "startedAt"       TIMESTAMPTZ,
  "completedAt"     TIMESTAMPTZ
);
CREATE INDEX ON "VideoGenerationJob" ("userId");
CREATE INDEX ON "VideoGenerationJob" ("projectId");

CREATE TABLE "VideoScene" (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "projectId"   UUID NOT NULL REFERENCES "Project"(id) ON DELETE CASCADE,
  "order"       INTEGER NOT NULL,
  text          TEXT,
  "visualDesc"  TEXT,
  "durationSec" INTEGER NOT NULL DEFAULT 5,
  "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "MediaAsset" (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"      UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "projectId"   UUID REFERENCES "Project"(id) ON DELETE SET NULL,
  type          TEXT NOT NULL,
  filename      TEXT NOT NULL,
  "storageKey"  TEXT NOT NULL,
  "mimeType"    TEXT NOT NULL,
  "sizeBytes"   INTEGER NOT NULL,
  "durationSec" DOUBLE PRECISION,
  "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ON "MediaAsset" ("userId");

CREATE TABLE "VideoExport" (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "projectId"   UUID NOT NULL REFERENCES "Project"(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'queued',
  resolution    TEXT NOT NULL,
  "storageKey"  TEXT,
  "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT now(),
  "completedAt" TIMESTAMPTZ
);

CREATE TABLE "Template" (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  category    TEXT NOT NULL,
  prefill     JSONB NOT NULL,
  "thumbSeed" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Avatar" (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"     UUID REFERENCES "User"(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  "isCustom"   BOOLEAN NOT NULL DEFAULT false,
  "storageKey" TEXT,
  "createdAt"  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Voice" (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT NOT NULL,
  language    TEXT NOT NULL DEFAULT 'en',
  gender      TEXT NOT NULL DEFAULT 'neutral',
  "sampleKey" TEXT
);

CREATE TABLE "AudioGeneration" (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "jobId"      UUID NOT NULL UNIQUE,
  text         TEXT NOT NULL,
  "voiceId"    UUID NOT NULL,
  "storageKey" TEXT,
  "createdAt"  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Notification" (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"    UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  "readAt"    TIMESTAMPTZ,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "UsageLog" (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"    UUID NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  action      TEXT NOT NULL,
  metadata    JSONB,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "AuditLog" (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"    UUID REFERENCES "User"(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,
  entity      TEXT,
  "entityId"  TEXT,
  ip          TEXT,
  metadata    JSONB,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
