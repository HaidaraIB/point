import "https://deno.land/std@0.177.0/http/server.ts";
import { buildEmailHtml } from "../send-notification-email/email-template.ts";

type ServiceAccountJson = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const RESEND_URL = "https://api.resend.com/emails";
const FROM_EMAIL = "Point Agency <no-reply@mail.point-iq.app>";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200, headers: corsHeaders() });
  if (req.method !== "POST") return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);

  try {
    const authHeader = req.headers.get("authorization") ?? "";
    const expected = Deno.env.get("CRON_SECRET") ?? "";
    if (expected && authHeader !== `Bearer ${expected}`) {
      return json({ errorCode: "ERR_UNAUTHORIZED" }, 401);
    }

    const sa = getServiceAccount();
    const accessToken = await getAccessToken(sa);
    const firestoreBase = `https://firestore.googleapis.com/v1/projects/${sa.project_id}/databases/(default)/documents`;
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    const now = new Date();

    const body = await req.json().catch(() => ({})) as { mode?: string };
    const mode = (body?.mode ?? "all").toLowerCase();

    // ملاحظة: Supabase Cron قد يفرض timeout 5000ms.
    // لذلك ندعم تشغيل جزء واحد عبر body.mode:
    // tasks | content24h | publish | all
    if (mode === "tasks" || mode === "all") {
      await handleTaskReminders({ accessToken, firestoreBase, fcmUrl, now, projectId: sa.project_id });
    }
    if (mode === "content24h" || mode === "all") {
      await handleContentPendingOver24h({ accessToken, firestoreBase, fcmUrl, now, projectId: sa.project_id });
    }
    if (mode === "publish" || mode === "all") {
      await handlePublishReminders({ accessToken, firestoreBase, fcmUrl, now, projectId: sa.project_id });
    }

    return json({ ok: true }, 200);
  } catch (e) {
    return json({ errorCode: "ERR_SERVER", details: String(e) }, 500);
  }
});

function getServiceAccount(): ServiceAccountJson {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON not set");
  const sa = JSON.parse(raw) as ServiceAccountJson;
  if (!sa?.project_id || !sa?.client_email || !sa?.private_key) {
    throw new Error("Invalid FIREBASE_SERVICE_ACCOUNT_JSON");
  }
  return sa;
}

async function getAccessToken(sa: ServiceAccountJson): Promise<string> {
  // JWT manually (RS256) using WebCrypto
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 55 * 60;
  const claim = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: TOKEN_URL,
    iat,
    exp,
  }));
  const unsigned = `${header}.${claim}`;
  const signature = await signRs256(unsigned, sa.private_key);
  const jwt = `${unsigned}.${signature}`;

  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Token error: ${JSON.stringify(data)}`);
  return data.access_token as string;
}

async function signRs256(unsigned: string, privateKeyPem: string): Promise<string> {
  const pkcs8 = pemToArrayBuffer(privateKeyPem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pkcs8,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  return base64url(new Uint8Array(sig));
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return bytes.buffer;
}

function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function listDocuments(accessToken: string, collection: string, firestoreBase: string) {
  const url = `${firestoreBase}/${collection}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  const data = await res.json();
  if (!res.ok) throw new Error(`Firestore list ${collection} error: ${JSON.stringify(data)}`);
  return (data.documents ?? []) as Array<{ name: string; fields: Record<string, unknown> }>;
}

function getStringField(fields: Record<string, unknown>, key: string): string | null {
  const v = (fields[key] as any)?.stringValue;
  return typeof v === "string" ? v : null;
}

async function runQuery({
  accessToken,
  projectId,
  structuredQuery,
}: {
  accessToken: string;
  projectId: string;
  structuredQuery: unknown;
}) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ structuredQuery }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Firestore runQuery error: ${JSON.stringify(data)}`);
  const out: Array<{ name: string; fields: Record<string, unknown> }> = [];
  for (const row of data as Array<any>) {
    if (row?.document?.name && row?.document?.fields) {
      out.push({ name: row.document.name, fields: row.document.fields });
    }
  }
  return out;
}

async function sendEmailIfPossible(toEmail: string | null, subject: string, body: string) {
  if (!toEmail) return;
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) return;
  const res = await fetch(RESEND_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: [toEmail],
      subject,
      text: body,
      html: buildEmailHtml(body),
    }),
  }).catch((err) => {
    console.error("sendEmailIfPossible network error", String(err));
    return null;
  });
  if (!res) return;
  if (!res.ok) {
    const out = await res.text().catch(() => "");
    console.error("sendEmailIfPossible failed", res.status, out.slice(0, 1400));
  }
}

function soundBaseForNotificationTypeCron(notificationType: string | undefined): string | null {
  if (!notificationType) return null;
  const t = notificationType.trim();
  if (!t) return null;
  const map: Record<string, string> = {
    chat_message: "notification_chat",
    employee_task_assigned: "notification_task_preview",
    employee_task_due_soon: "notification_task_deadline_soon",
    employee_task_edit_requested: "notification_task_comment",
    employee_task_rejected: "notification_content_status",
    employee_task_reopened: "notification_task_comment",
    employee_task_new_attachments: "notification_task_comment",
    employee_task_status_changed: "notification_content_status",
    manager_task_received: "notification_task_preview",
    manager_task_completed: "notification_task_preview",
    manager_task_edited: "notification_task_comment",
    manager_task_comment: "notification_task_comment",
    manager_content_submitted_by_client: "notification_content_status",
    manager_task_overdue: "notification_task_deadline",
    manager_new_task_department: "notification_task_preview",
    manager_client_notes: "notification_task_comment",
    manager_client_approved_content: "notification_task_approved",
    client_content_pending_approval: "notification_content_status",
    client_pending_over_24h: "notification_task_deadline_soon",
    client_approval_confirmed: "notification_task_approved",
    client_edits_done: "notification_task_comment",
    client_content_updated: "notification_content_status",
    client_content_scheduled: "notification_content_scheduled",
    publish_content_added: "notification_content_status",
    publish_client_edit_request: "notification_task_comment",
    publish_client_approved: "notification_task_approved",
    publish_client_rejected: "notification_content_status",
    publish_post_one_hour: "notification_content_scheduled",
    publish_post_not_confirmed_today: "notification_content_scheduled",
    publish_no_posts_tomorrow: "notification_task_deadline_soon",
    publish_post_published: "notification_promotion_status",
    publish_link_added: "notification_task_comment",
    publish_notes_after_publish: "notification_task_comment",
    publish_scheduled_cancelled: "notification_content_scheduled",
    admin_promotion_status_changed: "notification_promotion_status",
    admin_content_status_changed: "notification_content_status",
    promotion_new_published_content: "notification_promotion_status",
    broadcast_topic: "notification_task_preview",
  };
  return map[t] ?? null;
}

function fcmPlatformSoundPayloadsCron(soundBase: string | null): {
  apns: Record<string, unknown>;
  android?: Record<string, unknown>;
} {
  if (!soundBase) {
    return {
      apns: {
        headers: {
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };
  }
  const iosFile = `${soundBase}.wav`;
  const channelId = `point_sound_${soundBase}`;
  return {
    apns: {
      headers: {
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: iosFile,
        },
      },
    },
    android: {
      notification: {
        channel_id: channelId,
        sound: soundBase,
      },
    },
  };
}

async function sendFcm({
  accessToken,
  fcmUrl,
  token,
  title,
  body,
  notificationType,
}: {
  accessToken: string;
  fcmUrl: string;
  token: string | null;
  title: string;
  body: string;
  notificationType?: string;
}) {
  if (!token) return;
  const soundBase = soundBaseForNotificationTypeCron(notificationType);
  const platformSounds = fcmPlatformSoundPayloadsCron(soundBase);
  const dataPayload: Record<string, string> = {};
  if (notificationType && notificationType.trim().length > 0) {
    dataPayload.notificationType = notificationType.trim();
  }
  if (soundBase) {
    dataPayload.pushSoundBase = soundBase;
  }
  const res = await fetch(fcmUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        ...platformSounds,
        ...(Object.keys(dataPayload).length > 0 ? { data: dataPayload } : {}),
      },
    }),
  }).catch((err) => {
    console.error("sendFcm network error", String(err));
    return null;
  });
  if (!res) return;
  if (!res.ok) {
    const out = await res.text().catch(() => "");
    console.error("sendFcm failed", res.status, out.slice(0, 1400));
  }
}

async function patchTaskStringFields(
  accessToken: string,
  documentName: string,
  updates: Record<string, string>,
) {
  const keys = Object.keys(updates);
  if (keys.length === 0) return;
  const fields: Record<string, { stringValue: string }> = {};
  for (const [k, v] of Object.entries(updates)) {
    fields[k] = { stringValue: v };
  }
  const mask = keys.map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join("&");
  const url = `https://firestore.googleapis.com/v1/${documentName}?${mask}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    console.error("patchTaskStringFields failed", documentName, await res.text());
  }
}

/** مهام انتهت من ناحية سير العمل — لا نرسل تذكير اقتراب موعد. */
const TASK_ENDED_STATUSES = new Set([
  "status_approved",
  "status_published",
  "status_rejected",
]);

async function handleTaskReminders({
  accessToken,
  firestoreBase,
  fcmUrl,
  now,
  projectId,
}: {
  accessToken: string;
  firestoreBase: string;
  fcmUrl: string;
  now: Date;
  projectId: string;
}) {
  const employees = await listDocuments(accessToken, "employees", firestoreBase);
  const byEmpId = new Map<string, { name: string; email: string | null; fcmToken: string | null; role: string | null }>();
  for (const e of employees) {
    const id = e.name.split("/").pop() ?? "";
    byEmpId.set(id, {
      name: getStringField(e.fields, "name") ?? id,
      email: getStringField(e.fields, "email"),
      fcmToken: getStringField(e.fields, "fcmToken"),
      role: getStringField(e.fields, "role"),
    });
  }
  const managers = [...byEmpId.entries()].filter(([, v]) => v.role === "admin" || v.role === "supervisor").map(([id]) => id);

  const nowIso = now.toISOString();
  const in48hIso = new Date(now.getTime() + 48 * 60 * 60 * 1000).toISOString();
  const notifyStamp = now.toISOString();

  // Overdue: toDate < now
  const overdueTasks = await runQuery({
    accessToken,
    projectId,
    structuredQuery: {
      from: [{ collectionId: "tasks" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            { fieldFilter: { field: { fieldPath: "toDate" }, op: "LESS_THAN", value: { stringValue: nowIso } } },
            { fieldFilter: { field: { fieldPath: "assignedTo" }, op: "GREATER_THAN", value: { stringValue: "" } } },
          ],
        },
      },
      limit: 50,
    },
  });

  for (const t of overdueTasks) {
    const f = t.fields as any;
    const title = (f?.title?.stringValue as string) ?? "مهمة";
    const assignedTo = (f?.assignedTo?.stringValue as string) ?? "";
    if (!assignedTo) continue;
    const st = getStringField(f, "status") ?? "";
    if (TASK_ENDED_STATUSES.has(st)) continue;
    const emp = byEmpId.get(assignedTo);
    const empName = emp?.name ?? assignedTo;
    const msgBody = `تجاوزت موعد التسليم: ${title} — الموظف: ${empName}`;
    for (const id of managers) {
      const m = byEmpId.get(id);
      await sendEmailIfPossible(m?.email ?? null, "مهمة متأخرة", msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: m?.fcmToken ?? null,
        title: "مهمة متأخرة",
        body: msgBody,
        notificationType: "manager_task_overdue",
      });
    }
  }

  // تذكير قبل التسليم: نافذة 24 ساعة و 6 ساعات (شريحة ساعة واحدة لكل تشغيل كرون ساعي)، مع منع التكرار عبر حقول على المستند.
  const upcomingTasks = await runQuery({
    accessToken,
    projectId,
    structuredQuery: {
      from: [{ collectionId: "tasks" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            { fieldFilter: { field: { fieldPath: "toDate" }, op: "GREATER_THAN", value: { stringValue: nowIso } } },
            { fieldFilter: { field: { fieldPath: "toDate" }, op: "LESS_THAN_OR_EQUAL", value: { stringValue: in48hIso } } },
            { fieldFilter: { field: { fieldPath: "assignedTo" }, op: "GREATER_THAN", value: { stringValue: "" } } },
          ],
        },
      },
      limit: 100,
    },
  });

  for (const t of upcomingTasks) {
    const f = t.fields as any;
    const title = (f?.title?.stringValue as string) ?? "مهمة";
    const assignedTo = (f?.assignedTo?.stringValue as string) ?? "";
    const toDateStr = getStringField(f, "toDate");
    const status = getStringField(f, "status") ?? "";
    if (!assignedTo || !toDateStr) continue;
    if (TASK_ENDED_STATUSES.has(status)) continue;

    const toDate = new Date(toDateStr);
    if (Number.isNaN(toDate.getTime())) continue;

    const hoursUntil = (toDate.getTime() - now.getTime()) / (60 * 60 * 1000);
    const emp = byEmpId.get(assignedTo);
    const notified24 = getStringField(f, "dueSoonNotifiedAt24h");
    const notified6 = getStringField(f, "dueSoonNotifiedAt6h");

    // متبقي أكثر من 23 ساعة وأقل أو يساوي 24 ساعة
    if (hoursUntil <= 24 && hoursUntil > 23 && !notified24) {
      const msgTitle = "⏳ اقتراب موعد التسليم (24 ساعة)";
      const msgBody = `المهمة: ${title}`;
      await sendEmailIfPossible(emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: emp?.fcmToken ?? null,
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_due_soon",
      });
      await patchTaskStringFields(accessToken, t.name, { dueSoonNotifiedAt24h: notifyStamp });
    }

    if (hoursUntil <= 6 && hoursUntil > 5 && !notified6) {
      const msgTitle = "⏳ اقتراب موعد التسليم (6 ساعات)";
      const msgBody = `المهمة: ${title}`;
      await sendEmailIfPossible(emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: emp?.fcmToken ?? null,
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_due_soon",
      });
      await patchTaskStringFields(accessToken, t.name, { dueSoonNotifiedAt6h: notifyStamp });
    }
  }
}

async function handleContentPendingOver24h({
  accessToken,
  firestoreBase,
  fcmUrl,
  now,
  projectId,
}: {
  accessToken: string;
  firestoreBase: string;
  fcmUrl: string;
  now: Date;
  projectId: string;
}) {
  const clients = await listDocuments(accessToken, "clients", firestoreBase);
  const byClientId = new Map<string, { email: string | null; fcmToken: string | null }>();
  for (const c of clients) {
    const id = c.name.split("/").pop() ?? "";
    byClientId.set(id, {
      email: getStringField(c.fields, "email"),
      fcmToken: getStringField(c.fields, "fcmToken"),
    });
  }

  const cutoffIso = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
  const docs = await runQuery({
    accessToken,
    projectId,
    structuredQuery: {
      from: [{ collectionId: "contents" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            { fieldFilter: { field: { fieldPath: "status" }, op: "EQUAL", value: { stringValue: "status_under_revision" } } },
            { fieldFilter: { field: { fieldPath: "createdAt" }, op: "LESS_THAN_OR_EQUAL", value: { stringValue: cutoffIso } } },
          ],
        },
      },
      limit: 50,
    },
  });

  for (const doc of docs) {
    const f = doc.fields as any;
    const clientId = (f?.clientId?.stringValue as string) ?? "";
    const title = (f?.title?.stringValue as string) ?? "محتوى";
    if (!clientId) continue;
    const client = byClientId.get(clientId);
    const msgTitle = "لديك محتوى بانتظار المراجعة منذ أكثر من 24 ساعة";
    await sendEmailIfPossible(client?.email ?? null, msgTitle, title);
    await sendFcm({
      accessToken,
      fcmUrl,
      token: client?.fcmToken ?? null,
      title: msgTitle,
      body: title,
      notificationType: "client_pending_over_24h",
    });
  }
}

async function handlePublishReminders({
  accessToken,
  firestoreBase,
  fcmUrl,
  now,
  projectId,
}: {
  accessToken: string;
  firestoreBase: string;
  fcmUrl: string;
  now: Date;
  projectId: string;
}) {
  const employees = await listDocuments(accessToken, "employees", firestoreBase);
  const clients = await listDocuments(accessToken, "clients", firestoreBase);

  const byEmpId = new Map<string, { email: string | null; fcmToken: string | null; role: string | null; department: string | null }>();
  for (const e of employees) {
    const id = e.name.split("/").pop() ?? "";
    byEmpId.set(id, {
      email: getStringField(e.fields, "email"),
      fcmToken: getStringField(e.fields, "fcmToken"),
      role: getStringField(e.fields, "role"),
      department: getStringField(e.fields, "department"),
    });
  }
  const publishDept = [...byEmpId.entries()]
    .filter(([, v]) => v.department === "cat6" || v.role === "admin" || v.role === "supervisor")
    .map(([id]) => id);

  const byClientId = new Map<string, { name: string; }>();
  for (const c of clients) {
    const id = c.name.split("/").pop() ?? "";
    byClientId.set(id, { name: getStringField(c.fields, "name") ?? id });
  }

  const nowIso = now.toISOString();
  const in1hIso = new Date(now.getTime() + 60 * 60 * 1000).toISOString();

  // خلال ساعة (محدود)
  const nearPublish = await runQuery({
    accessToken,
    projectId,
    structuredQuery: {
      from: [{ collectionId: "contents" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            { fieldFilter: { field: { fieldPath: "publishDate" }, op: "GREATER_THAN_OR_EQUAL", value: { stringValue: nowIso } } },
            { fieldFilter: { field: { fieldPath: "publishDate" }, op: "LESS_THAN_OR_EQUAL", value: { stringValue: in1hIso } } },
          ],
        },
      },
      limit: 50,
    },
  });

  for (const doc of nearPublish) {
    const f = doc.fields as any;
    const title = (f?.title?.stringValue as string) ?? "منشور";
    const executor = (f?.executor?.stringValue as string) ?? "";
    const targetId = executor || publishDept[0];
    const target = targetId ? byEmpId.get(targetId) : null;
    if (!targetId || !target) continue;
    const msgTitle = "تذكير: لديك منشور مجدول سيتم نشره خلال ساعة";
    await sendEmailIfPossible(target.email ?? null, msgTitle, title);
    await sendFcm({
      accessToken,
      fcmUrl,
      token: target.fcmToken ?? null,
      title: msgTitle,
      body: title,
      notificationType: "publish_post_one_hour",
    });
  }

  // لا منشورات غداً لكل عميل
  const tomorrowStart = new Date(now);
  tomorrowStart.setDate(tomorrowStart.getDate() + 1);
  tomorrowStart.setHours(0, 0, 0, 0);
  const tomorrowEnd = new Date(tomorrowStart.getTime() + 24 * 60 * 60 * 1000);

  const tomorrowStartIso = tomorrowStart.toISOString();
  const tomorrowEndIso = tomorrowEnd.toISOString();
  const tomorrowDocs = await runQuery({
    accessToken,
    projectId,
    structuredQuery: {
      from: [{ collectionId: "contents" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            { fieldFilter: { field: { fieldPath: "publishDate" }, op: "GREATER_THAN_OR_EQUAL", value: { stringValue: tomorrowStartIso } } },
            { fieldFilter: { field: { fieldPath: "publishDate" }, op: "LESS_THAN", value: { stringValue: tomorrowEndIso } } },
          ],
        },
      },
      limit: 500,
    },
  });
  const clientsWithTomorrow = new Set<string>();
  for (const doc of tomorrowDocs) {
    const f = doc.fields as any;
    const clientId = (f?.clientId?.stringValue as string) ?? "";
    if (clientId) clientsWithTomorrow.add(clientId);
  }

  const allClientIds = new Set<string>();
  for (const c of clients) allClientIds.add(c.name.split("/").pop() ?? "");

  const clientsWithoutTomorrow = [...allClientIds].filter((id) => id && !clientsWithTomorrow.has(id));
  for (const clientId of clientsWithoutTomorrow) {
    const clientName = byClientId.get(clientId)?.name ?? clientId;
    const msgTitle = "تنبيه: لا توجد منشورات مجدولة ليوم غد";
    const msgBody = `حساب العميل: ${clientName}`;
    for (const empId of publishDept) {
      const emp = byEmpId.get(empId);
      await sendEmailIfPossible(emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: emp?.fcmToken ?? null,
        title: msgTitle,
        body: msgBody,
        notificationType: "publish_no_posts_tomorrow",
      });
    }
  }
}

function json(obj: unknown, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}
