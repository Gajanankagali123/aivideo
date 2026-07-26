# API Reference

Base URL: `http://localhost:4000/api` (dev). All responses use a consistent envelope:

```json
{ "success": true, "data": { ... } }
{ "success": false, "error": { "code": "SOME_CODE", "message": "Human readable.", "details": [] } }
```

Auth uses two httpOnly cookies (`ams_access`, 15 min; `ams_refresh`, 30 days) set on
register/login. The frontend API client (`frontend/js/api/client.js`) auto-refreshes
on a 401 once, transparently. All authenticated routes require `credentials: 'include'`
on fetch and matching CORS origin (`FRONTEND_URL` in `.env`).

## Auth — `/auth`
| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/register` | `{name,email,password}` | Creates user + Free plan subscription + 15-credit wallet grant, sets cookies |
| POST | `/login` | `{email,password}` | Rate-limited: 15 attempts / 10 min per IP |
| POST | `/logout` | — | Revokes the current session |
| POST | `/refresh` | — (uses refresh cookie) | Issues a new access token |
| GET | `/me` | — | Current user |
| POST | `/forgot-password` | `{email}` | Always returns success (no email enumeration). In non-production, response includes `devResetToken` so the flow is testable without a mail server. |
| POST | `/reset-password` | `{token,password}` | Also revokes all existing sessions |
| POST | `/verify-email` | `{token}` | |

## Users — `/users` (auth required)
| Method | Path | Body |
|---|---|---|
| PATCH | `/me` | `{name?,email?}` |
| PATCH | `/me/password` | `{currentPassword,newPassword}` — revokes all sessions |
| PATCH | `/me/settings` | `{emailNotifications?,productUpdates?,language?}` |
| DELETE | `/me` | Soft-delete (sets `deletedAt`, anonymizes email) |

## Credits — `/credits` (auth required)
| Method | Path | Returns |
|---|---|---|
| GET | `/balance` | `{balance, reserved, plan}` |
| GET | `/transactions` | Full ledger, newest first |

### Pricing (server-authoritative — see `docs/database.md#credits`)
Base cost by duration bucket: 5s→16, 10s→32, 15s→48, 30s→90. Multipliers: 4K ×1.8,
720p ×0.7, avatar-video ×1.25 on top of the duration base. Voiceover is a flat 8. The
frontend shows an estimate (`updateCost()` in `index.html`) purely for UX — the backend
recomputes independently in `calculateGenerationCost()` and rejects any client-supplied
cost field.

## Plans — `/plans` (public)
`GET /` → seeded Free / Creator / Pro plans with `monthlyCredits`, `maxResolution`, `watermark`, `priceCents`, `features[]`.

## Dashboard — `/dashboard` (auth required)
`GET /summary` → `{videosGenerated, videosThisWeek, credits, creditsReserved, storageUsedMb, storageLimitMb, plan, recentProjects[]}` — all computed live from the DB, nothing hard-coded.

## Projects — `/projects` (auth required, ownership-enforced on every route)
| Method | Path | Notes |
|---|---|---|
| GET | `/` | `?search=&status=` |
| GET | `/:id` | 403 if not owner |
| PATCH | `/:id` | `{title}` |
| DELETE | `/:id` | Soft delete |
| POST | `/:id/duplicate` | Deep-copies title/type/duration/resolution/timeline |
| GET | `/:id/editor` | `{timeline, scenes}` |
| PATCH | `/:id/editor` | `{timeline}` — flat JSON blob, see `docs/limitations.md` |
| POST | `/:id/render` | Creates a `VideoExport`; reuses the project's latest completed render (no multi-layer compositor in this build) |
| GET | `/:id/exports` | Export history |

## Generations — `/generations` (auth required)
All five creation endpoints follow the same contract: validate → server computes
credit cost → atomically reserve credits → create `Project` + `VideoGenerationJob` →
enqueue on BullMQ → return `{jobId, projectId, status:'queued', creditsReserved}`.
On insufficient balance: `402 INSUFFICIENT_CREDITS`, nothing is created.

| Method | Path | Body |
|---|---|---|
| POST | `/text-to-video` | `{prompt, style, aspectRatio, duration, resolution, cameraMovement?, visualStyle?, motionStrength?, creativity?, projectTitle?}` |
| POST | `/image-to-video` | multipart: `image` file + `{motionPrompt?, cameraMovement?, duration}` |
| POST | `/script-to-video` | `{title, script, voiceStyle?, visualStyle?, music?, subtitleStyle?}` — auto-splits `script` into one `VideoScene` per paragraph |
| POST | `/avatar-video` | `{avatarId, script, language?, voiceId?}` |
| POST | `/voiceover` | `{text, language?, accent?, speed?, pitch?, emotion?, voiceId?}` |
| GET | `/jobs/:id` | `{status, stage, progress, resultAssetId, error}` — poll this |
| POST | `/jobs/:id/cancel` | Only while `queued`/`processing`; refunds reserved credits |

**Job lifecycle**: `queued → processing → completed|failed|canceled`. Stages emitted
by the worker: `ANALYZING PROMPT → GENERATING SCENES → CREATING VISUALS → ADDING
MOTION → RENDERING VIDEO → FINALIZING YOUR CREATION`. On `failed`, credits are
refunded automatically (see `worker.ts`'s catch block).

## Assets — `/assets` (auth required)
| Method | Path |
|---|---|
| GET | `/?type=image\|video\|audio` |
| POST | `/` (multipart `file`) |
| GET | `/:id/download-url` |
| DELETE | `/:id` |

## Library — `/templates`, `/avatars`, `/voices`
- `GET /templates?category=` — public
- `POST /templates/:id/use` — auth; returns `{prefill}` for the create-video form
- `GET /avatars` — auth; system avatars (`userId=null`) + your custom ones
- `POST /avatars/custom` — auth, multipart `image`
- `GET /voices` — auth; includes `previewUrl` pointing at a real seeded sample file
- `GET /voices/:id/preview` — auth

## Billing — `/billing` (auth required unless noted)
| Method | Path | Notes |
|---|---|---|
| GET | `/subscription` | Current plan + period end |
| POST | `/checkout` | `{planId}` → creates a pending `Payment`. With `PAYMENT_PROVIDER=mock` (default), also returns `devCheckoutUrl` |
| POST | `/dev-simulate-payment/:paymentId` | Dev-only: fires the same code path a real webhook would |
| POST | `/cancel` | Sets `cancelAtPeriodEnd=true` |
| POST | `/webhook` | Public but signature-verified via `PAYMENT_WEBHOOK_SECRET` (HMAC-SHA256) when set; idempotent via `WebhookEvent.eventId` unique constraint |

## Notifications — `/notifications` (auth required)
`GET /`, `POST /:id/read`

## Files — `/files/:key`
Serves whatever `storage.put()` wrote locally. In production with `STORAGE_DRIVER=s3`
this route is unused — clients get signed URLs straight from S3 instead.

## Error codes reference
`VALIDATION_ERROR` (400) · `UNAUTHENTICATED` (401) · `INVALID_CREDENTIALS` (401) ·
`FORBIDDEN` (403) · `NOT_FOUND` (404) · `EMAIL_TAKEN` (409) · `INVALID_STATE` (400) ·
`INSUFFICIENT_CREDITS` (402) · `PROVIDER_NOT_CONFIGURED` / `PROVIDER_NOT_IMPLEMENTED` (503) ·
`INTERNAL_ERROR` (500)
