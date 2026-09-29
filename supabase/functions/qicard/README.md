# Qi Card (Point OS invoices)

Edge Functions:

- `qicard` — admin settings (`get-settings`, `save-settings`, `refund`, `cancel`)
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

Stable link: `https://agency.point-iq.app/pay.html?t=<payLinkToken>` (legacy URLs with `p=` still work)

Return URL after Qi checkout: `payment-result.html?provider=qicard&ref=<requestId>&p=...&t=...`

## Admin refund / cancel (certification)

OS admin Firebase ID token in `x-firebase-id-token`. Replace placeholders.

```bash
curl -sS -X POST "https://<SUPABASE_PROJECT>.supabase.co/functions/v1/qicard" \
  -H "Content-Type: application/json" \
  -H "x-firebase-id-token: <FIREBASE_ID_TOKEN>" \
  -d '{"action":"refund","paymentId":"<QICARD_PAYMENT_ID>","amount":1000,"message":"certification test"}'

curl -sS -X POST "https://<SUPABASE_PROJECT>.supabase.co/functions/v1/qicard" \
  -H "Content-Type: application/json" \
  -H "x-firebase-id-token: <FIREBASE_ID_TOKEN>" \
  -d '{"action":"cancel","paymentId":"<QICARD_PAYMENT_ID>"}'
```

## QiCard certification checklist

1. Run three sandbox payments from `https://agency.point-iq.app/pay.html?t=<token>` (not localhost).
2. Success: pay with sandbox test card; note `qicardPaymentId` on the invoice.
3. Refund: pay a second invoice, then `action: refund` with that `paymentId` and invoice `total` as `amount`.
4. Cancel: open checkout for a third invoice, do not pay, then `action: cancel` with its `paymentId` (status `CREATED`).
5. Email QiCard: payment IDs, refund `refundId` if returned, plus:

- `finishPaymentUrl`: `https://agency.point-iq.app/payment-result.html?provider=qicard&...`
- `notificationUrl`: `https://<SUPABASE_PROJECT>.supabase.co/functions/v1/qicard-webhook?firebaseProjectId=<FIREBASE_PROJECT_ID>`
- Framework: **Flutter** (hosted web checkout today; request Flutter SDK for optional in-app checkout).
- Request: production API host, terminal credentials, webhook RSA public key (PEM).

### Certification run (sandbox, prod URLs)

| Case | `requestId` | `paymentId` | Notes |
|------|-------------|-------------|--------|
| Success | `a6b89af4-7547-4c1b-9114-8b40894620ea` | `20396d53-b82e-4d00-9be3-9f144a9873ff` | `status=SUCCESS`, 1000 IQD |
| Refund | `305c46dd-fa87-4596-b1ee-12aa0ed7d3ba` | `20396d53-b82e-4d00-9be3-9f144a9873ff` | `refundId=298bfb99-455d-4db7-bb13-f0539a706f70` |
| Cancel | `317449df-01a5-41ab-b289-f261dc5820e1` | `dfc36df0-20d7-43c4-92c5-b48a110ad8ce` | `canceled=true` before pay |

URLs used on every create:

- `finishPaymentUrl`: `https://agency.point-iq.app/payment-result.html?provider=qicard&ref=<requestId>&p=point-agency-production&t=cert`
- `notificationUrl`: `https://nbyhcxhdkxrathjaacvj.supabase.co/functions/v1/qicard-webhook?firebaseProjectId=point-agency-production`
