# Point storage migration (VPS package)

Self-contained tool to migrate legacy **Supabase Storage** URLs in Firestore to **Cloudflare R2**.  
Run this on a **VPS** so ~1.7 GB of files transfer over datacenter bandwidth (Supabase → VPS → R2), not your home internet.

## What you need

- Linux VPS with **Node.js 18+**
- Firebase **service account** JSON (Firestore read/write)
- R2 API keys (same as `workers/r2-presign`)
- Supabase **service role** key (for purge only; copy uses public URLs)

## 1. Zip on your PC (Windows)

From this folder:

```powershell
cd scripts\point-storage-migration
.\pack.ps1
```

Creates `point-storage-migration.zip` (no secrets, no `node_modules`).

Also prepare separately (do **not** put in git):

- `firebase-sa.json` — Firebase service account for `point-agency-production`
- `.env` — copy from [`.env.example`](.env.example) and fill in secrets

Optional: if you already ran a **scan**, keep `.migration-cache/<project-id>/` in this folder (includes `scan-report.json`) so you can `--skip-scan`.

## 2. Upload to VPS

```bash
scp point-storage-migration.zip firebase-sa.json .env user@YOUR_VPS:/opt/point-migration/
ssh user@YOUR_VPS
cd /opt/point-migration
unzip point-storage-migration.zip
npm install
chmod +x run.sh   # optional; see commands below
```

## 3. Run on VPS (use `screen` or `tmux`)

**Prefer `npm run migrate` or `node migrate.mjs`** — avoids `run.sh` / Windows CRLF shebang issues (`bash\r`).

```bash
npm run migrate -- --project point-agency-production --page-size 50 --delay-ms 200
# same as:
node migrate.mjs --project point-agency-production --page-size 50 --delay-ms 200
```

`./run.sh` is optional (auto-runs `npm install` if needed). If you see `bash\r: No such file or directory`:

```bash
sed -i 's/\r$//' run.sh && chmod +x run.sh
```

**Full migration** — use the [one-day migration](#one-day-migration-minimal-firestore-quota) steps (scan, then copy, then `--rewrite-from-hits`). Do not use `--copy --rewrite` in one command.

**Scan only** (low Firestore reads — use throttling if quota errors):

```bash
npm run migrate -- --project point-agency-production --page-size 25 --delay-ms 500
```

**Purge** Supabase + clear Firestore URLs (no R2 copy):

```bash
npm run migrate -- --project point-agency-production --purge --confirm-purge --skip-scan
```

## 4. Download results (optional)

Copy cache back to your PC for records:

```bash
scp -r user@YOUR_VPS:/opt/point-migration/.migration-cache ./migration-backup
```

Contains `url-map.json`, `scan-report.json`, `changes.jsonl`, etc.

## One-day migration (minimal Firestore quota)

Production has **~85K+ document reads** if you scan every collection. Spark free tier allows **50K reads/day**, so you **must upgrade to Blaze** before a one-day production migration (pay-as-you-go; typically a few dollars for this job).

Run as **three separate commands** (do not combine scan + rewrite in one run).

```bash
cd /opt/point-migration
screen -S migrate

# 0) After quota reset (~midnight Pacific) OR on Blaze — scan ONCE (~85K reads on Blaze)
npm run migrate -- --project point-agency-production --page-size 50 --delay-ms 200

# 1) Copy Supabase → R2 — ZERO Firestore reads
npm run migrate -- --project point-agency-production --skip-scan --copy --concurrency 8

# 2) Rewrite only docs in scan-report — ~hundreds of reads, NOT a full rescan
npm run migrate -- --project point-agency-production --rewrite-from-hits
```

If copy stops midway, rerun step 1 only (`--skip-scan --copy`); `url-map.json` resumes.

**Never use plain `--rewrite`** after migration scan — it rescans every document (~85K reads again). Always use **`--rewrite-from-hits`**.

While migration runs: avoid heavy app usage (employees/clients using the app adds Firestore reads).

## Commands reference

| Flag | Purpose |
|------|---------|
| `--project point-agency-production` | Required Firebase project |
| `--copy` | Supabase → R2 (uses VPS bandwidth) |
| `--rewrite-from-hits` | Rewrite only docs in `scan-report.json` (minimal reads) |
| `--rewrite` | Full collection rescan + rewrite (avoid; ~85K reads) |
| `--skip-scan` | Use existing `.migration-cache/.../scan-report.json` |
| `--purge` / `--confirm-purge` | Delete Supabase files + clear Firestore URLs |
| `--concurrency 5` | Parallel R2 uploads (default 3) |
| `--page-size 25` `--delay-ms 300` | Throttle Firestore reads |
| `--resume` | Continue interrupted scan |

## Environment (`.env`)

See [`.env.example`](.env.example). Minimum for copy + rewrite:

```env
GOOGLE_APPLICATION_CREDENTIALS=./firebase-sa.json
R2_ACCOUNT_ID=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=point
R2_PUBLIC_BASE_URL=https://pub-xxxxx.r2.dev
```

## Output

All state under `.migration-cache/<project-id>/`:

- `scan-report.json` — URLs found
- `url-map.json` — Supabase → R2 mapping (resume-safe)
- `changes.jsonl` — Firestore rewrites audit
- `failures.jsonl` — failed copies/deletes

## Security

- Delete `.env` and `firebase-sa.json` from the VPS when finished.
- Never commit secrets or zip them into the public archive.
