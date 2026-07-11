# R2 presign Worker

Issues short-lived **presigned PUT** URLs for Cloudflare R2 so the Flutter app can upload without R2 secrets. Verifies **Firebase ID tokens** (same project as the app).

## One-time: R2 bucket and public URL

1. Cloudflare Dashboard → **R2** → Create bucket (e.g. `point`).
2. Enable **public access** for the bucket:
   - Either connect a **custom domain** (recommended for production), or
   - Use the bucket’s **`*.r2.dev`** public URL (fine for testing; rate limits apply).
3. Note the **public base URL** with **no trailing slash**, e.g. `https://pub-xxxxx.r2.dev` or `https://cdn.example.com`.
4. Create an **R2 API token** with read/write on that bucket. Save:
   - Account ID (R2 overview)
   - Access Key ID
   - Secret Access Key

## R2 bucket CORS (required for Flutter **web** uploads)

Dashboard → bucket → **Settings** → **CORS policy**, e.g.:

```json
[
  {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "PUT", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag", "Content-Length"],
    "MaxAgeSeconds": 3600
  }
]
```

**Do not add `OPTIONS`** to `AllowedMethods`. Cloudflare R2 only allows **`GET`, `PUT`, `POST`, `HEAD`, `DELETE`** in the dashboard schema; including `OPTIONS` makes the policy **invalid** and it will not save correctly. R2 still handles **preflight** when `PUT` (and your origins/headers) are allowed — see [Configure CORS](https://developers.cloudflare.com/r2/buckets/cors/).

`AllowedOrigins` values must be valid origins only — **no trailing path** (not `https://example.com/`).

Tighten `AllowedOrigins` from `"*"` to your real origins in production.

## Worker secrets

From `workers/r2-presign/`:

```bash
npm install
npx wrangler secret put R2_ACCOUNT_ID
npx wrangler secret put R2_ACCESS_KEY_ID
npx wrangler secret put R2_SECRET_ACCESS_KEY
npx wrangler secret put R2_BUCKET
npx wrangler secret put R2_PUBLIC_BASE_URL
npx wrangler secret put FIREBASE_PROJECT_IDS
```

`R2_PUBLIC_BASE_URL` must match the public URL users load files from (same as Flutter `--dart-define=R2_PUBLIC_BASE_URL=...`).

**Firebase project IDs (`FIREBASE_PROJECT_IDS`, required):** comma-separated allowlist of every Firebase project whose users may upload (Google JWKS verify; token `aud` must match one of these). Include both **production** (`default` in [`.firebaserc`](../.firebaserc)) and **legacy** (`legacy`) if you use both.

Example:

```txt
point-agency-production,point-f33cb
```

### Verify `FIREBASE_PROJECT_IDS` (intermittent `invalid_token` / some users fail)

If uploads fail at **0% progress** for some users only, the presign step likely rejected their Firebase token (`aud` not in the allowlist).

From `workers/r2-presign/`:

```bash
npx wrangler secret list
# Re-set if missing or wrong (comma-separated, no spaces required):
npx wrangler secret put FIREBASE_PROJECT_IDS
# paste: point-agency-production,point-f33cb
```

Must include **every** project id shipped in app builds (see repo [`.firebaserc`](../../.firebaserc): `default` = production, `legacy` = test/debug).

**Client-side audit trail:** failed uploads write to Firestore `upload_diagnostics` (manager read). Query by `errorCode`, `stage`, `firebaseProjectId`, `uid`. **Worker logs:** Cloudflare dashboard → Workers → r2-presign → Logs; look for JSON lines `{"event":"sign_upload_fail","error":"invalid_token",...}`.

## Deploy

```bash
npx wrangler deploy
```

Set Flutter `--dart-define=R2_SIGNER_URL=...` to the worker base URL (no trailing slash), e.g. `https://r2-presign.your-account.workers.dev`. The app does not need a separate public-base define: the worker returns the full `publicUrl` using its `R2_PUBLIC_BASE_URL` secret.

## Troubleshooting: `InvalidArgument` / access key length

If R2 returns **`Credential access key has length 64, should be 32`**, the Worker secrets are wrong: **`R2_ACCESS_KEY_ID` must be the 32-character Access Key ID**, and **`R2_SECRET_ACCESS_KEY` the 64-character Secret Access Key** from R2 → **Manage R2 API Tokens**. The values are easy to swap when running `wrangler secret put`. Redeploy is not required after fixing secrets.

## Troubleshooting: Flutter **web** upload

If the app logs **XHR / status=0** when uploading, the presign step usually worked but the browser **blocked the PUT** to R2. Fix **R2 bucket CORS**:

- Add the **exact** `Origin` you run the app from (DevTools → Network → failed request → **Request Headers** → `Origin`). Use a **fixed** `--web-port` so the origin stays stable (e.g. `8080`, or `5555` on Windows when Hyper-V/WSL excludes `8080` — then add `http://localhost:5555` to `AllowedOrigins`).
- Allowed methods: **`GET`**, **`PUT`**, **`HEAD`** only (plus **`DELETE`** if you need it). **Never `OPTIONS`** — invalid in R2’s CORS JSON.
- **`AllowedHeaders`**: use `["*"]` or list `Content-Type`, `Content-Disposition`, etc.

**Quick check:** upload the same file from **Android/iOS/desktop** (non-web). If that works but web fails, it is **CORS**.

Wait up to ~30s after saving CORS (propagation). In **Chrome DevTools → Network**, inspect **OPTIONS** then **PUT** to `r2.cloudflarestorage.com`.

## API

`POST /sign-upload`

- Headers: `Authorization: Bearer <Firebase ID token>`
- JSON body: `{ "contentType": "video/mp4", "ext": ".mp4", "friendlyDownloadName": "optional.pdf" }`
- Response: `{ "ok": true, "uploadUrl", "headers", "publicUrl", "key" }` or `{ "ok": false, "error": "..." }`

The client must send a **PUT** to `uploadUrl` with exactly the returned `headers` and the raw file bytes.
