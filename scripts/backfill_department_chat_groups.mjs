/**
 * Backfill: إنشاء/تعبئة Department chat groups
 *
 * ينشئ:
 *  - chats/group_{department} لكل department في StorageKeys.departments
 *  - participants = كل admin + كل supervisor + كل employee في نفس department
 *
 * التشغيل:
 *   npm install firebase-admin
 *   set GOOGLE_APPLICATION_CREDENTIALS="C:\path\serviceAccount.json"   (أو firebase-adminsdk.json)
 *   node scripts/backfill_department_chat_groups.mjs
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

const departments = [
  "promotion",
  "design",
  "photography",
  "content-writing",
  "montage",
  "publishing",
  "programming",
];

function isElevatedRole(role) {
  const r = (role ?? "").toString().trim().toLowerCase();
  return r === "admin" || r === "supervisor";
}

async function main() {
  const snap = await db.collection("employees").get();

  const adminsSupervisors = [];
  const byDept = new Map();

  for (const doc of snap.docs) {
    const d = doc.data() || {};
    const empId = doc.id;
    const role = d.role ?? "employee";
    const dept = d.department ?? null;

    if (isElevatedRole(role)) {
      adminsSupervisors.push(empId);
      continue;
    }

    if (!dept) continue;
    const normalizedDept = dept.toString().trim();
    if (!departments.includes(normalizedDept)) continue;

    if (!byDept.has(normalizedDept)) byDept.set(normalizedDept, []);
    byDept.get(normalizedDept).push(empId);
  }

  const elevatedSet = new Set(adminsSupervisors);
  let totalGroups = 0;
  let totalUpdated = 0;

  for (const dept of departments) {
    const groupId = `group_${dept}`;
    const groupRef = db.collection("chats").doc(groupId);

    const deptEmployees = byDept.get(dept) ?? [];
    const participants = Array.from(new Set([...elevatedSet, ...deptEmployees]));

    const existing = await groupRef.get();
    totalGroups++;
    await groupRef.set(
      {
        isGroup: true,
        // العنوان هنا نخليه dept key (promotion/design/...) لأن .tr هي ترجمة Flutter.
        // UI يمكنه التعامل معه.
        title: dept,
        participants,
        lastMessage: "",
        lastUpdated: new Date(),
        createdAt: existing.exists ? existing.data().createdAt ?? new Date() : new Date(),
      },
      { merge: false }
    );
    totalUpdated++;
    console.log(`group backfilled: ${groupId} (${participants.length} participants)`);
  }

  console.log(`Backfill done. groups=${totalGroups} updated=${totalUpdated}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

