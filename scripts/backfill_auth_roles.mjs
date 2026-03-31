/**
 * One-off backfill: authRoles/{authUid} من employees (حيث يوجد authUid).
 * يتطلب: npm install firebase-admin
 * التشغيل: set GOOGLE_APPLICATION_CREDENTIALS=مسار\serviceAccount.json
 *          node scripts/backfill_auth_roles.mjs
 */
import { initializeApp, cert, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync, existsSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectId = process.env.FIREBASE_PROJECT_ID || "point-f33cb";

try {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    initializeApp({ credential: applicationDefault(), projectId });
  } else {
    const p = join(__dirname, "serviceAccount.json");
    if (!existsSync(p)) {
      throw new Error("Missing GOOGLE_APPLICATION_CREDENTIALS or scripts/serviceAccount.json");
    }
    const raw = readFileSync(p, "utf8");
    initializeApp({ credential: cert(JSON.parse(raw)), projectId });
  }
} catch (e) {
  console.error(e.message || e);
  process.exit(1);
}

const db = getFirestore();

async function main() {
  const snap = await db.collection("employees").get();
  let n = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    const uid = d.authUid?.toString?.()?.trim?.();
    if (!uid) continue;
    const role = d.role || "employee";
    await db.collection("authRoles").doc(uid).set(
      {
        role,
        employeeId: doc.id,
        clientId: null,
        department: d.department ?? null,
        updatedAt: new Date(),
      },
      { merge: true }
    );
    n++;
  }
  console.log(`authRoles backfill done: ${n} documents.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
