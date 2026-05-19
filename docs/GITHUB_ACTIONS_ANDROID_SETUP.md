# GitHub Actions — Android build & Google Drive upload (Point)

On push to `master`, builds release APK/AAB and uploads to Google Drive as:

- `Point {version}({build}).apk` — e.g. `Point 1.9.0(22).apk`
- `Point {version}({build}).aab` — e.g. `Point 1.9.0(22).aab`

Workflow: `[.github/workflows/android-build-drive.yml](../.github/workflows/android-build-drive.yml)`

## Build config (same secrets as web deploy)

CI uses `--dart-define=...` with the **same GitHub Actions secrets** as [deploy-hostinger-web.yml](../.github/workflows/deploy-hostinger-web.yml):


| Secret                      | `--dart-define`             |
| --------------------------- | --------------------------- |
| (fixed)                     | `USE_FIREBASE_PROD=true`    |
| `SUPABASE_URL`              | `SUPABASE_URL`              |
| `SUPABASE_ANON_KEY`         | `SUPABASE_ANON_KEY`         |
| `SUPABASE_STORAGE_BASE_URL` | `SUPABASE_STORAGE_BASE_URL` |
| `R2_SIGNER_URL`             | `R2_SIGNER_URL`             |
| `R2_PUBLIC_BASE_URL`        | `R2_PUBLIC_BASE_URL`        |


No extra `BUILD_DOTENV` secret is required if these are already set for web deploy.

## Local build

Locally you can keep using `.env`:

```bash
flutter build appbundle --release --dart-define-from-file=.env
flutter build apk --release --dart-define-from-file=.env
```

Or pass the same defines explicitly (equivalent to CI).

## Android-only secrets


| Secret                      | Description                                                 |
| --------------------------- | ----------------------------------------------------------- |
| `ANDROID_KEYSTORE_BASE64`   | Base64 of `android/app/point_agency.jks`                    |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password                                           |
| `ANDROID_KEY_PASSWORD`      | Key password                                                |
| `ANDROID_KEY_ALIAS`         | `upload`                                                    |
| `GOOGLE_SERVICES_JSON`      | (Recommended) Production `android/app/google-services.json` |


Encode keystore (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\ASUS\Desktop\point\android\app\point_agency.jks"))
```

## Google Drive (OAuth)

Reuse **upload_to_meta_bot** OAuth credentials:


| Secret                       | Value                                |
| ---------------------------- | ------------------------------------ |
| `GDRIVE_AUTH_MODE`           | `oauth`                              |
| `GDRIVE_OAUTH_CLIENT_ID`     | From bot `credentials.json`          |
| `GDRIVE_OAUTH_CLIENT_SECRET` | From bot `credentials.json`          |
| `GDRIVE_OAUTH_REFRESH_TOKEN` | From bot `refresh_token.txt`         |
| `GDRIVE_FOLDER_ID`           | Target Drive folder for Point builds |


## Verify

1. Ensure web deploy secrets exist (`SUPABASE_`*, `R2_*`).
2. Add Android signing + Drive secrets.
3. Push to `master` or run **Actions → Android Release to Google Drive**.

## Troubleshooting


| Issue                           | Fix                                                       |
| ------------------------------- | --------------------------------------------------------- |
| `storageQuotaExceeded` on Drive | Use OAuth, not service account on My Drive                |
| Signing failed                  | Check keystore secrets; alias `upload`                    |
| Missing Supabase at runtime     | Set `SUPABASE_`* / `R2_*` secrets (same as Hostinger web) |
| Wrong Firebase project          | CI sets `USE_FIREBASE_PROD=true` automatically            |


