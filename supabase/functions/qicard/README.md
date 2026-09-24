# Qi Card (Point OS invoices)

Edge Functions:

- `qicard` — admin settings (`get-settings`, `save-settings`)
- `qicard-webhook` — public webhook (`verify_jwt = false`)
- Shared logic: `supabase/functions/_shared/qicard.ts`

## Deploy

```bash
supabase functions deploy qicard
supabase functions deploy qicard-webhook
```

Ensure `config.toml` has `[functions.qicard-webhook] verify_jwt = false`.

## Webhook URL

Register in Qi dashboard or rely on per-payment `notificationUrl`:

```
https://<SUPABASE_PROJECT>.supabase.co/functions/v1/qicard-webhook?firebaseProjectId=<FIREBASE_PROJECT_ID>
```

## Webhook signature (recommended)

Request Qi support for the Payment Gateway RSA public key (PEM). Paste it in OS Settings → Qi Card → webhook public key. When set, `X-Signature` is verified on each webhook.

## Sandbox

- API base: `https://uat-sandbox-3ds-api.qi.iq/api/v1`
- Docs: https://developers-gate.qi.iq/docs/api-auth/sandbox-test
- Test terminal and Basic Auth credentials are documented on that page.
- Test card (web): `5213720304238582`, CVV `642`, expiry `01/32`, OTP `123123`

## Live

Store live API base URL in settings (`qicardLiveApiBase`). Qi provides production host at onboarding.

## Client payment flow

Stable link: `https://agency.point-iq.app/pay.html?p=<firebaseProjectId>&t=<payLinkToken>`

Return URL after Qi checkout: `payment-result.html?provider=qicard&ref=<requestId>&p=...&t=...`
