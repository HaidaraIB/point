# PayTabs Edge Function

Admin-only actions for PayTabs settings and hosted checkout sessions.

## Deploy

```bash
supabase functions deploy paytabs
supabase functions deploy paytabs-ipn
```

`paytabs-ipn` is public (`verify_jwt = false` in `supabase/config.toml`) because PayTabs sends IPN/callback requests with an HMAC `Signature` header instead of a Supabase JWT.

## Dashboard IPN

Configure in PayTabs → Developers → Payment Notifications:

- **Type:** Default Web
- **URL:** `https://<PROJECT_REF>.supabase.co/functions/v1/paytabs-ipn`
- **Allowed Events:** Sale on; others off
- **Enabled:** on
- **With Callback:** on
