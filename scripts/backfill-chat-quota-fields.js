/**
 * One-shot backfill for Firestore chat quota fields:
 * - unreadCount_<participantId> = 0 for each participant (if missing)
 * - lastMessageMeta from lastMessage text when missing
 *
 * Usage (from repo root):
 *   node scripts/backfill-chat-quota-fields.js
 *   node scripts/backfill-chat-quota-fields.js --dry-run
 *   node scripts/backfill-chat-quota-fields.js --service-account firebase-adminsdk.json
 */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const repoRoot = path.join(__dirname, '..');

function resolveServiceAccountPath(arg) {
  if (!arg) {
    return path.join(repoRoot, 'firebase-adminsdk.json');
  }
  if (path.isAbsolute(arg)) {
    return arg;
  }
  const fromCwd = path.resolve(process.cwd(), arg);
  if (fs.existsSync(fromCwd)) {
    return fromCwd;
  }
  return path.join(repoRoot, arg);
}

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const saFlag = args.indexOf('--service-account');
const serviceAccountPath = resolveServiceAccountPath(
  saFlag >= 0 ? args[saFlag + 1] : null,
);

if (!fs.existsSync(serviceAccountPath)) {
  console.error('Service account not found:', serviceAccountPath);
  console.error('Run from repo root, or pass an absolute path.');
  process.exit(1);
}

const serviceAccount = JSON.parse(
  fs.readFileSync(serviceAccountPath, 'utf8'),
);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

async function backfillChat(doc) {
  const data = doc.data() || {};
  const participants = Array.isArray(data.participants)
    ? data.participants.map((p) => String(p).trim()).filter(Boolean)
    : [];
  const patch = {};

  for (const pid of participants) {
    const unreadKey = `unreadCount_${pid}`;
    if (data[unreadKey] === undefined) {
      patch[unreadKey] = 0;
    }
  }

  if (!data.lastMessageMeta && data.lastMessage) {
    const preview = String(data.lastMessage).trim();
    if (preview) {
      patch.lastMessageMeta = {
        previewText: preview,
        subtitleLine: preview,
      };
    }
  }

  if (Object.keys(patch).length === 0) return false;
  if (!dryRun) {
    await doc.ref.update(patch);
  }
  return true;
}

async function main() {
  console.log(dryRun ? 'DRY RUN — no writes' : 'LIVE — writing patches');
  console.log('Service account:', serviceAccountPath);

  const snap = await db.collection('chats').get();
  let updated = 0;
  for (const doc of snap.docs) {
    const changed = await backfillChat(doc);
    if (changed) {
      updated++;
      console.log('patched', doc.id);
    }
  }
  console.log(`Done. ${updated} / ${snap.size} chat docs patched.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
