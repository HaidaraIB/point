# Alqaseh Edge Functions

Admin settings via `alqaseh`; payment webhook/redirect via `alqaseh-webhook`.

## Deploy

```bash
supabase functions deploy alqaseh
supabase functions deploy alqaseh-webhook
supabase functions deploy card-payment
supabase functions deploy card-payment-status
```

`alqaseh-webhook` is public (`verify_jwt = false`) because Alqaseh sends webhook POSTs without a Supabase JWT. Settlement always re-fetches payment status from Alqaseh API before marking invoices paid.

## Webhook / redirect URLs

Configured automatically when creating a payment context:

- **Webhook:** `https://<PROJECT_REF>.supabase.co/functions/v1/alqaseh-webhook?firebaseProjectId=<FIREBASE_PROJECT_ID>`
- **Return:** `{base}/payment-result.html?provider=alqaseh&firebaseProjectId=...` (Alqaseh appends `payment_id`, `order_id`, `status` to the query string)

## Test environment

From [Alqaseh docs](https://docs.alqaseh.com/payment-api):

| Field | Value |
| --- | --- |
| API | `https://api-test.alqaseh.com/v1` |
| Payment page | `https://pay-test.alqaseh.com/pay/:token` |
| Client ID | `public_test` |
| Client Secret | `Lr10yWWmm1dXLoI7VgXCrQVnlq13c1G0` |
| Test card | `5341432900077803` / CVV `971` / EXP `01-2027` |

## Active provider

Only one card provider can be active at a time (`none`, `paytabs`, or `alqaseh`). Use OS Settings → Card payments, or the `card-payment` function `set-active` action.
