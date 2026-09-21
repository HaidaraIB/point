# os-whatsapp Edge Function

Admin-only Meta WhatsApp Cloud API settings; messaging-module users can list approved templates and send template messages.

## Deploy

```bash
supabase functions deploy os-whatsapp
```

## Auth

- Requires `x-firebase-id-token: Bearer <Firebase ID token>` (same as `paytabs`).
- Settings: admin only (`assertOsAdmin`).
- Send / list templates: admin or supervisor with `messaging` in `osModuleAccess`.

## Firestore

Secrets and IDs on `os_settings/default` (client read/write denied in rules):

- `whatsappAccessToken`, `whatsappPhoneNumberId`, `whatsappBusinessAccountId`
- `whatsappEnabled`, `whatsappDisplayPhoneNumber`, `whatsappVerifiedName`

Outbound audit: `os_whatsapp_logs/{id}` (written by this function).

## Actions

| action | Description |
|--------|-------------|
| `get-settings` | Masked status for admin settings UI |
| `save-settings` | Persist token / IDs / enabled flag |
| `test-connection` | Graph GET phone number; stores display name |
| `list-templates` | APPROVED WABA templates |
| `send-template` | Graph POST messages; writes log |
