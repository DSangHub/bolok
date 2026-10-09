# BoloKaam on Vercel

Static homepage plus Node.js API functions. No build command or output directory is needed; use the Other framework and repository root.

## Configuration
Set BOLOK_API_TOKEN (a strong random server-to-server token), GOOGLE_SERVICE_ACCOUNT_JSON (Google service-account JSON with Speech-to-Text access), RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in the Bolok Vercel project. Never put these values in the browser or Git.

## API
GET /api/health (also /health). POST /api/voice/process accepts multipart audio and language; use WebM/Opus or WAV, max 4MB. POST /api/payment/create-order accepts amount in INR and jobId UUID. POST /api/payment/verify checks checkout signatures only; it does not confirm capture or activate jobs. All POST endpoints require Authorization: Bearer <BOLOK_API_TOKEN>. /v1 aliases /api for existing clients.

Import postman/BoloKaam.postman_collection.json in Postman and set baseUrl and apiToken locally. This collection was imported from BoloKaam API in D Sang's Workspace and adapted for Vercel. The unmodified export is preserved at postman/BoloKaam.original.postman_collection.json. Saved responses are illustrative examples, not live test results.

The original extensionless files are source notes. Job/profile persistence, authenticated user onboarding, captured-payment webhooks and the notification worker are not implemented by this deployment repair. The original draft OpenAPI includes planned jobs endpoints; these return 404 until implemented.
