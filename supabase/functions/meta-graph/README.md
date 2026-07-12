# meta-graph

Server-side proxy for Meta Graph **read** calls from the Point web app.

Browsers cannot call `https://graph.facebook.com` directly (CORS). Flutter web routes
`GET /me/accounts` (and token verify) through this function instead.

## Deploy

Uses the same Supabase secrets as `send-fcm` / `claim-fcm-token`:

- `FIREBASE_SERVICE_ACCOUNT_JSON` (prod)
- `FIREBASE_SERVICE_ACCOUNT_JSON_TEST` (optional test Firebase project)

```bash
supabase functions deploy meta-graph --project-ref YOUR_REF
```

No extra secrets required beyond existing Firebase service accounts.

## Auth

- Requires `x-firebase-id-token: Bearer <Firebase ID token>` (same header as `send-fcm`).
- Caller must be admin/supervisor (checked via Firestore `authRoles` + `employees`).

## Allowed paths

- `GET /me/accounts` — list Facebook Pages + linked Instagram accounts
- `GET /me` — reserved for future token debug
