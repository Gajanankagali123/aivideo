# Frontend → Backend Mapping — AI Motion Studio

Audit of `frontend/index.html` (single-file prototype) and the API each feature now binds to.
All endpoints are prefixed `/api`. Auth = required unless marked Public.

## Legend
- 🟢 Fully wired to real DB/queue/FFmpeg in this build
- 🟡 Real endpoint + DB model exists, minimal implementation (documented in README limitations)
- ⚪ Endpoint scaffolded, provider requires real credentials to go live

| Frontend Feature | Element(s) | Endpoint | Method | Request Body | Response | DB Tables | Auth | Status |
|---|---|---|---|---|---|---|---|---|
| Sign up | `#auth-signup` | `/auth/register` | POST | `{name,email,password}` | `{user}` + sets cookies | User, CreditWallet, Subscription, UserSettings | Public | 🟢 |
| Log in | `#auth-login` | `/auth/login` | POST | `{email,password}` | `{user}` + sets cookies | User, Session | Public | 🟢 |
| Log out | user menu | `/auth/logout` | POST | — | `{success}` | Session | Yes | 🟢 |
| Refresh session | api client (silent) | `/auth/refresh` | POST | cookie `refreshToken` | new access cookie | Session | Cookie | 🟢 |
| Get current user | app boot | `/auth/me` | GET | — | `{user}` | User | Yes | 🟢 |
| Forgot password | `#auth-forgot` | `/auth/forgot-password` | POST | `{email}` | `{success}` | PasswordResetToken | Public | 🟢 |
| Reset password | (email link, not in UI) | `/auth/reset-password` | POST | `{token,password}` | `{success}` | PasswordResetToken | Public | 🟢 |
| Update profile | `#sv-settings` name/email fields | `/users/me` | PATCH | `{name,email}` | `{user}` | User | Yes | 🟢 |
| Change password | Settings | `/users/me/password` | PATCH | `{currentPassword,newPassword}` | `{success}` | User | Yes | 🟢 |
| Delete account | Settings | `/users/me` | DELETE | — | `{success}` | User (cascade) | Yes | 🟢 |
| Dashboard stats | `#sv-dashboard` stat cards | `/dashboard/summary` | GET | — | `{videosGenerated,videosThisWeek,credits,storageUsedMb,storageLimitMb,plan,renewsAt,recentProjects[]}` | Project, VideoGenerationJob, CreditWallet, MediaAsset, Subscription | Yes | 🟢 |
| Credit pill / balance | `.credit-pill`, sidebar plan card | `/credits/balance` | GET | — | `{balance,plan}` | CreditWallet | Yes | 🟢 |
| Credit history | (not yet in UI, API ready) | `/credits/transactions` | GET | — | `{transactions[]}` | CreditTransaction | Yes | 🟢 |
| Plans list | Pricing section | `/plans` | GET | — | `{plans[]}` | Plan | Public | 🟢 |
| Text to Video form | `#tab-text`, `#text-prompt`, style/ratio pills, duration/res selects, sliders | `/generations/text-to-video` | POST | `{prompt,style,aspectRatio,duration,resolution,cameraMovement,visualStyle,motionStrength,creativity,projectTitle}` | `{jobId,projectId,status,creditsReserved}` | Project, VideoGenerationJob, CreditTransaction | Yes | 🟢 |
| Image to Video form | `#tab-image`, `#drop-zone`, `#img-input` | `/generations/image-to-video` | POST (multipart) | `image` file + `{motionPrompt,cameraMovement,duration}` | `{jobId,projectId,status,creditsReserved}` | Project, VideoGenerationJob, MediaAsset | Yes | 🟢 |
| Script to Video form | `#tab-script` | `/generations/script-to-video` | POST | `{title,script,voiceStyle,visualStyle,music,subtitleStyle}` | `{jobId,projectId,status,creditsReserved}` | Project, VideoGenerationJob, VideoScene | Yes | 🟢 |
| Generation progress overlay | `#gen-overlay`, `#gen-progress`, `#gen-stages` | `/generations/jobs/:id` | GET (polled) | — | `{status,progress,stage,resultAssetId?,error?}` | VideoGenerationJob | Yes | 🟢 |
| Cancel generation | Cancel button | `/generations/jobs/:id/cancel` | POST | — | `{success}` | VideoGenerationJob | Yes | 🟢 |
| Result modal (download/share) | `#result-modal` | `/assets/:id/download-url` | GET | — | `{url}` | MediaAsset | Yes | 🟢 |
| My Projects grid | `#projects-grid` | `/projects` | GET | query `?search=&status=` | `{projects[]}` | Project | Yes | 🟢 |
| Open/rename project | project card actions | `/projects/:id` | GET / PATCH | `{title}` | `{project}` | Project | Yes | 🟢 |
| Delete project | project card actions | `/projects/:id` | DELETE | — | `{success}` | Project (cascade) | Yes | 🟢 |
| Duplicate project | project card actions | `/projects/:id/duplicate` | POST | — | `{project}` | Project | Yes | 🟡 |
| Templates grid + category filter | `#templates-grid`, `#template-cats` | `/templates` | GET | query `?category=` | `{templates[]}` | Template | Public | 🟢 |
| Use template | "Use Template" button | `/templates/:id/use` | POST | — | `{prefill}` (routes into create-video) | Template | Yes | 🟢 |
| AI Avatars grid | `#avatar-grid` | `/avatars` | GET | — | `{avatars[]}` | Avatar | Yes | 🟢 |
| Generate avatar video | Avatars page button | `/generations/avatar-video` | POST | `{avatarId,script,language,voiceId}` | `{jobId,projectId,status,creditsReserved}` | Project, VideoGenerationJob | Yes | 🟢 (mock provider, FFmpeg render) |
| Upload custom avatar | "Upload custom avatar" | `/avatars/custom` | POST (multipart) | `image` file | `{avatar}` | Avatar, MediaAsset | Yes | 🟡 |
| Voice list | `#voice-list` | `/voices` | GET | — | `{voices[]}` | Voice | Yes | 🟢 |
| Voice preview play | play buttons in voice list | `/voices/:id/preview` | GET | — | audio stream/url | Voice, MediaAsset | Yes | 🟡 (static sample, real TTS is ⚪) |
| Generate voiceover | Voice Studio "Generate Voiceover" | `/generations/voiceover` | POST | `{text,language,accent,speed,pitch,emotion,voiceId}` | `{jobId,status,creditsReserved}` | VideoGenerationJob, AudioGeneration | Yes | 🟢 (mock TTS via FFmpeg tone+text, real provider ⚪) |
| Assets grid | `#sv-assets`, `#assets-grid` | `/assets` | GET | query `?type=` | `{assets[]}` | MediaAsset | Yes | 🟢 |
| Upload asset | (asset upload control) | `/assets` | POST (multipart) | file | `{asset}` | MediaAsset | Yes | 🟢 |
| Delete asset | asset actions | `/assets/:id` | DELETE | — | `{success}` | MediaAsset | Yes | 🟢 |
| Editor load | `#sv-editor` | `/projects/:id/editor` | GET | — | `{timeline}` | VideoScene, Project | Yes | 🟡 |
| Editor save | editor toolbar actions | `/projects/:id/editor` | PATCH | `{timeline}` | `{success}` | VideoScene, Project | Yes | 🟡 |
| Editor render/export | (export action) | `/projects/:id/render` | POST | `{}` | `{exportJobId}` | VideoExport, VideoGenerationJob | Yes | 🟡 (FFmpeg concat of existing clip, real multi-layer compositing is out of scope for this build) |
| List exports | — | `/projects/:id/exports` | GET | — | `{exports[]}` | VideoExport | Yes | 🟢 |
| Pricing page plan cards | `#pricing` | `/plans` | GET | — | `{plans[]}` | Plan | Public | 🟢 |
| Checkout / upgrade | "Upgrade plan" / "Go Pro" | `/billing/checkout` | POST | `{planId}` | `{checkoutUrl}` or `{payment}` | Payment | Yes | ⚪ (no live Stripe key — provider abstraction + dev-mode simulated webhook only) |
| Subscription info | Settings | `/billing/subscription` | GET | — | `{subscription}` | Subscription | Yes | 🟢 |
| Cancel subscription | Settings | `/billing/cancel` | POST | — | `{subscription}` | Subscription | Yes | 🟢 |
| Payment webhook | (server-to-server) | `/billing/webhook` | POST | provider payload | `{received:true}` | Payment, WebhookEvent, CreditTransaction | Signed, not cookie | ⚪ real signature verification implemented; needs live provider secret |
| Notifications bell | `.btn-icon` (bell) | `/notifications` | GET | — | `{notifications[]}` | Notification | Yes | 🟡 |
| Settings — notification prefs | Settings | `/users/me/settings` | PATCH | `{emailNotifications,...}` | `{settings}` | UserSettings | Yes | 🟢 |

## What "🟡" and "⚪" mean concretely
- 🟡 items have real tables, real endpoints, and return real data — but the underlying capability is intentionally minimal (e.g. duplicate = deep-copy row, editor = flat JSON timeline blob rather than a full multi-track compositor).
- ⚪ items are built as complete, real provider-abstraction interfaces (`backend/src/providers/*`) with a working **mock adapter**. They fail loudly (`503 PROVIDER_NOT_CONFIGURED`) instead of faking success when a real key isn't present, per the "no fake success responses" requirement. Swapping in a real key in `.env` activates the real adapter with no code changes to routes.

## No frontend feature is backed by hard-coded JS data after this build
Everything previously generated by `frontend/index.html`'s inline `<script>` (`projectNames[]`, `templates[]`, `avatarNames[]`, `voices[]`, the `setInterval` fake progress bar, the fake `128 / 212 / 6.4GB` dashboard numbers) is replaced by calls through `frontend/js/api/*.js` into the endpoints above.
