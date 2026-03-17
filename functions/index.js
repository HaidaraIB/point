/**
 * Firebase Cloud Functions (v2) — إشعارات مجدولة لتطبيق Point
 * يتطلب: إعداد SUPABASE_URL و SUPABASE_ANON_KEY في Firebase config أو بيئة التشغيل
 *
 * نشر الدوال: firebase deploy --only functions
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

function getSupabaseUrl() {
  return process.env.SUPABASE_URL || "";
}
function getSupabaseAnonKey() {
  return process.env.SUPABASE_ANON_KEY || "";
}

async function sendEmail(toEmail, title, body) {
  const url = getSupabaseUrl();
  const key = getSupabaseAnonKey();
  if (!url || !key || !toEmail) return;
  try {
    const res = await fetch(`${url}/functions/v1/send-notification-email`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({ toEmail, subject: title, body }),
    });
    if (!res.ok) console.warn("Email failed", res.status, await res.text());
  } catch (e) {
    console.warn("sendEmail error", e.message);
  }
}

async function sendFcmToEmployee(employeeId, title, body) {
  const emp = await db.collection("employees").doc(employeeId).get();
  if (!emp.exists) return;
  const data = emp.data();
  const token = data?.fcmToken;
  const email = data?.email;
  if (email) sendEmail(email, title, body);
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
    });
  } catch (e) {
    console.warn("FCM to employee", employeeId, e.message);
  }
}

async function sendFcmToClient(clientId, title, body) {
  const doc = await db.collection("clients").doc(clientId).get();
  if (!doc.exists) return;
  const data = doc.data();
  const token = data?.fcmToken;
  const email = data?.email;
  if (email) sendEmail(email, title, body);
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
    });
  } catch (e) {
    console.warn("FCM to client", clientId, e.message);
  }
}

async function getEmployeeIdsByRole(roles) {
  const snap = await db.collection("employees").where("role", "in", roles.slice(0, 10)).get();
  return snap.docs.map((d) => d.id).filter(Boolean);
}

async function getEmployeeIdsByDepartment(department) {
  const snap = await db.collection("employees").where("department", "==", department).get();
  return snap.docs.map((d) => d.id).filter(Boolean);
}

/** ⏳ اقتراب موعد التسليم + ⚠️ مهمة متأخرة — كل 6 ساعات */
exports.scheduledTaskReminders = onSchedule(
  { schedule: "every 6 hours", region: "europe-west1" },
  async () => {
    const now = new Date();
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const tasksSnap = await db.collection("tasks").get();
    for (const doc of tasksSnap.docs) {
      const t = doc.data();
      const raw = t.toDate;
      const toDate = raw && (typeof raw.toDate === "function" ? raw.toDate() : new Date(raw));
      if (!toDate || !t.assignedTo) continue;
      const title = t.title || "مهمة";

      if (toDate < now) {
        const emp = await db.collection("employees").doc(t.assignedTo).get();
        const empName = emp.exists ? emp.data()?.name || t.assignedTo : t.assignedTo;
        const managerIds = await getEmployeeIdsByRole(["admin", "supervisor"]);
        const body = `تجاوزت موعد التسليم: ${title} — الموظف: ${empName}`;
        for (const id of managerIds) await sendFcmToEmployee(id, "مهمة متأخرة", body);
      } else if (toDate <= in24h) {
        await sendFcmToEmployee(t.assignedTo, "⏳ اقتراب موعد التسليم", `المهمة: ${title}`);
      }
    }
  }
);

/** 🕐 محتوى بانتظار مراجعة العميل منذ أكثر من 24 ساعة — يومياً */
exports.scheduledContentPendingOver24h = onSchedule(
  { schedule: "every day 00:00", region: "europe-west1" },
  async () => {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const snap = await db
      .collection("contents")
      .where("status", "==", "status_under_revision")
      .get();

    for (const doc of snap.docs) {
      const c = doc.data();
      const raw = c.createdAt;
      const createdAt = raw && (typeof raw.toDate === "function" ? raw.toDate() : new Date(raw));
      if (!createdAt || createdAt > cutoff) continue;
      const clientId = c.clientId;
      const title = c.title || "محتوى";
      if (clientId) await sendFcmToClient(clientId, "لديك محتوى بانتظار المراجعة منذ أكثر من 24 ساعة", title);
    }
  }
);

/** ⏰ تذكير منشور خلال ساعة + تنبيه لا منشورات غداً — كل ساعة */
exports.scheduledPublishReminders = onSchedule(
  { schedule: "every 1 hours", region: "europe-west1" },
  async () => {
    const now = new Date();
    const in1h = new Date(now.getTime() + 60 * 60 * 1000);
    const tomorrowStart = new Date(now);
    tomorrowStart.setDate(tomorrowStart.getDate() + 1);
    tomorrowStart.setHours(0, 0, 0, 0);
    const tomorrowEnd = new Date(tomorrowStart.getTime() + 24 * 60 * 60 * 1000);

    const contentsSnap = await db.collection("contents").get();
    const publishDeptIds = new Set([
      ...(await getEmployeeIdsByRole(["admin", "supervisor"])),
      ...(await getEmployeeIdsByDepartment("cat6")),
    ]);

    for (const doc of contentsSnap.docs) {
      const c = doc.data();
      const rawPd = c.publishDate;
      const publishDate = rawPd && (typeof rawPd.toDate === "function" ? rawPd.toDate() : new Date(rawPd));
      if (!publishDate) continue;
      const title = c.title || "منشور";

      if (publishDate >= now && publishDate <= in1h) {
        const executorId = c.executor;
        const targetId = executorId || [...publishDeptIds][0];
        if (targetId) await sendFcmToEmployee(targetId, "تذكير: لديك منشور مجدول سيتم نشره خلال ساعة", title);
      }
    }

    const clientIdsWithTomorrow = new Set();
    for (const doc of contentsSnap.docs) {
      const c = doc.data();
      const rawPd2 = c.publishDate;
      const publishDate = rawPd2 && (typeof rawPd2.toDate === "function" ? rawPd2.toDate() : new Date(rawPd2));
      if (publishDate && publishDate >= tomorrowStart && publishDate < tomorrowEnd && c.clientId) {
        clientIdsWithTomorrow.add(c.clientId);
      }
    }

    const allClientIds = new Set();
    const clientsSnap = await db.collection("clients").get();
    clientsSnap.docs.forEach((d) => allClientIds.add(d.id));

    const clientsWithoutTomorrow = [...allClientIds].filter((id) => !clientIdsWithTomorrow.has(id));
    for (const clientId of clientsWithoutTomorrow) {
      const clientDoc = await db.collection("clients").doc(clientId).get();
      const clientName = clientDoc.exists ? clientDoc.data()?.name || clientId : clientId;
      for (const empId of publishDeptIds) {
        await sendFcmToEmployee(empId, "تنبيه: لا توجد منشورات مجدولة ليوم غد", `حساب العميل: ${clientName}`);
      }
    }
  }
);
