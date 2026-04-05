import "https://deno.land/std@0.177.0/http/server.ts";
import type { ServiceAccountJson } from "../_shared/firebase-edge.ts";
import { resolveServiceAccountForScheduledCron } from "../_shared/firebase-edge.ts";
import { buildEmailHtml } from "../send-notification-email/email-template.ts";

// نطاق يغطي Firestore REST و FCM v1؛ `firebase.messaging` وحدها تسبب 403 على list/query في Firestore.
const GOOGLE_ACCESS_SCOPE = "https://www.googleapis.com/auth/cloud-platform";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const RESEND_URL = "https://api.resend.com/emails";
const FROM_EMAIL = "Point Agency <no-reply@mail.point-iq.app>";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200, headers: corsHeaders() });
  if (req.method !== "POST") return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);

  try {
    // بوابة Supabase تتطلب JWT صالحاً في Authorization (مثل anon key). لا تضع CRON_SECRET وحده في Authorization.
    // الطريقة الموصى بها: Authorization: Bearer <SUPABASE_ANON_KEY> + apikey + x-cron-secret: <CRON_SECRET>
    // للتوافق: Authorization: Bearer <CRON_SECRET> فقط (قد يفشل عند البوابة).
    const authHeader = req.headers.get("authorization") ?? "";
    const expected = Deno.env.get("CRON_SECRET") ?? "";
    if (expected) {
      const xCron = (req.headers.get("x-cron-secret") ?? "").trim();
      const legacyBearerOnly = authHeader === `Bearer ${expected}`;
      const cronViaHeader = xCron === expected;
      if (!cronViaHeader && !legacyBearerOnly) {
        return json({ errorCode: "ERR_UNAUTHORIZED" }, 401);
      }
    }

    const body = await req.json().catch(() => ({})) as {
      mode?: string;
      firebaseProjectId?: string;
    };
    const sa = resolveServiceAccountForScheduledCron(body.firebaseProjectId);
    const accessToken = await getAccessToken(sa);
    const firestoreBase = `https://firestore.googleapis.com/v1/projects/${sa.project_id}/databases/(default)/documents`;
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    const now = new Date();

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

async function getAccessToken(sa: ServiceAccountJson): Promise<string> {
  // JWT manually (RS256) using WebCrypto
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 55 * 60;
  const claim = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: GOOGLE_ACCESS_SCOPE,
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

function getDoubleField(fields: Record<string, unknown>, key: string): number | null {
  const v = fields[key] as any;
  if (v?.doubleValue != null && typeof v.doubleValue === "number") return v.doubleValue;
  if (v?.integerValue != null) {
    const n = Number(v.integerValue);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

/** أحدث نشاط: من `fromDate` أو آخر حدث في timelineEvents (نص ISO أو timestamp). */
function getLatestActivityMs(fields: Record<string, unknown>): number {
  const fromStr = getStringField(fields, "fromDate");
  let max = fromStr ? new Date(fromStr).getTime() : 0;
  if (Number.isNaN(max)) max = 0;
  const te = (fields as any).timelineEvents?.arrayValue?.values;
  if (!Array.isArray(te)) return max;
  for (const item of te) {
    const map = item?.mapValue?.fields;
    if (!map) continue;
    const tField = (map as any).timestamp;
    const ts =
      typeof tField?.stringValue === "string"
        ? tField.stringValue
        : typeof tField?.timestampValue === "string"
          ? tField.timestampValue
          : null;
    if (!ts) continue;
    const n = new Date(ts).getTime();
    if (!Number.isNaN(n) && n > max) max = n;
  }
  return max;
}

function hoursSinceIso(iso: string | null, now: Date): number {
  if (!iso) return 1e9;
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return 1e9;
  return (now.getTime() - t) / (60 * 60 * 1000);
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

/** مُنسَّق مع [lib/Services/notification_email_policy.dart] — حافظ على التزامن يدوياً. */
const PUSH_ONLY_NOTIFICATION_TYPES_EMAIL = new Set<string>([
  "chat_message",
  "employee_task_due_soon",
  "employee_task_followup",
  "employee_task_due_soon_1h",
  "employee_task_start_reminder",
  "employee_task_stale_update",
  "employee_task_no_progress_yet",
  "employee_progress_quarter",
  "employee_progress_half",
  "employee_progress_three_quarter",
  "employee_progress_finished",
  "employee_progress_reminder_0",
  "employee_progress_reminder_25",
  "employee_progress_reminder_50",
  "employee_progress_reminder_75_a",
  "employee_progress_reminder_75_b",
  "employee_progress_reminder_100",
  "employee_task_status_changed",
  "manager_task_progress_updated",
  "manager_task_edited",
  "manager_task_comment",
  "client_pending_over_24h",
  "client_content_updated",
  "manager_content_submitted_by_client",
  "client_content_pending_approval",
  "publish_content_added",
  "publish_post_one_hour",
  "publish_post_not_confirmed_today",
  "publish_no_posts_tomorrow",
  "publish_link_added",
  "publish_notes_after_publish",
]);

function shouldSendEmailForNotificationTypeCron(notificationType: string | undefined): boolean {
  const t = (notificationType ?? "").trim();
  if (!t) return true;
  return !PUSH_ONLY_NOTIFICATION_TYPES_EMAIL.has(t);
}

async function sendEmailIfPolicyAllows(
  notificationType: string | undefined,
  toEmail: string | null,
  subject: string,
  body: string,
) {
  if (!shouldSendEmailForNotificationTypeCron(notificationType)) return;
  await sendEmailIfPossible(toEmail, subject, body);
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
    employee_task_new_comment: "notification_task_comment",
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
    employee_task_start_reminder: "notification_task_deadline_soon",
    employee_task_stale_update: "notification_task_comment",
    employee_task_followup: "notification_task_deadline_soon",
    employee_task_overdue: "notification_task_deadline",
    employee_task_due_soon_1h: "notification_task_deadline_soon",
    employee_task_no_progress_yet: "notification_task_preview",
    manager_task_progress_updated: "notification_task_preview",
    manager_task_no_action: "notification_content_status",
    manager_task_progress_stalled: "notification_task_deadline",
    employee_progress_quarter: "notification_task_preview",
    employee_progress_half: "notification_task_preview",
    employee_progress_three_quarter: "notification_task_deadline_soon",
    employee_progress_finished: "notification_task_approved",
    employee_progress_reminder_0: "notification_task_preview",
    employee_progress_reminder_25: "notification_task_preview",
    employee_progress_reminder_50: "notification_task_preview",
    employee_progress_reminder_75_a: "notification_task_deadline_soon",
    employee_progress_reminder_75_b: "notification_task_deadline_soon",
    employee_progress_reminder_100: "notification_task_approved",
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

/** نفس منطق [send-fcm/index.ts]: بدون `notification` جذري لتفادي تكرار إشعارات الويب. */
function buildFcmV1NotificationMessageCron(
  token: string,
  title: string,
  body: string,
  dataPayload: Record<string, string>,
  soundBase: string | null,
  webNotificationTag: string,
): Record<string, unknown> {
  const platformSounds = fcmPlatformSoundPayloadsCron(soundBase);
  const androidExtra =
    (platformSounds.android?.notification as Record<string, unknown> | undefined) ?? {};
  const apnsBlock = platformSounds.apns as {
    headers?: Record<string, string>;
    payload?: { aps?: Record<string, unknown> };
  };
  const prevAps = { ...(apnsBlock.payload?.aps ?? {}) };
  const tag = webNotificationTag.slice(0, 64);

  const msg: Record<string, unknown> = {
    token,
    android: {
      priority: "high",
      notification: {
        title,
        body,
        ...androidExtra,
      },
    },
    apns: {
      headers: apnsBlock.headers,
      payload: {
        aps: {
          ...prevAps,
          alert: { title, body },
        },
      },
    },
    webpush: {
      headers: { Urgency: "high" },
      notification: { title, body, tag },
    },
  };
  if (Object.keys(dataPayload).length > 0) {
    msg.data = dataPayload;
  }
  return msg;
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
  const dataPayload: Record<string, string> = {};
  if (notificationType && notificationType.trim().length > 0) {
    dataPayload.notificationType = notificationType.trim();
  }
  if (soundBase) {
    dataPayload.pushSoundBase = soundBase;
  }
  const webTag = `point-cron-${crypto.randomUUID()}`;
  dataPayload.title = title;
  dataPayload.body = body;
  dataPayload.requestId = webTag;
  const message = buildFcmV1NotificationMessageCron(
    token,
    title,
    body,
    dataPayload,
    soundBase,
    webTag,
  );
  const res = await fetch(fcmUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message,
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

/** يطابق [TaskModel.normalizeProgress] / خطوات التقدم في التطبيق (0، 25٪، …). */
const PROGRESS_REMINDER_BIT_0 = 1;
const PROGRESS_REMINDER_BIT_25 = 32;
const PROGRESS_REMINDER_BIT_50 = 64;
const PROGRESS_REMINDER_BIT_75 = 128;
const PROGRESS_REMINDER_BIT_100 = 256;

function parseTaskMaskInt(raw: string | null | undefined): number {
  if (raw == null || raw === "") return 0;
  const n = parseInt(String(raw).trim(), 10);
  return Number.isFinite(n) ? Math.max(0, Math.min(511, n)) : 0;
}

function migrateLegacyMilestoneMaskForReminder(raw: number): number {
  if (raw <= 0) return 0;
  const newBits =
    PROGRESS_REMINDER_BIT_25 | PROGRESS_REMINDER_BIT_50 | PROGRESS_REMINDER_BIT_75 | PROGRESS_REMINDER_BIT_100;
  if (raw & newBits) return raw & newBits;
  let n = 0;
  if (raw & 2) n |= PROGRESS_REMINDER_BIT_25;
  if (raw & 4) n |= PROGRESS_REMINDER_BIT_50;
  if (raw & 8) n |= PROGRESS_REMINDER_BIT_75;
  if (raw & 16) n |= PROGRESS_REMINDER_BIT_100;
  return n;
}

/** يدمج [progressReminderSentMask] مع عتبات [progressMilestoneMask] القديمة لتجنب إعادة إشعارات فورية سابقة. */
function mergedProgressReminderMask(fields: Record<string, unknown>): number {
  const stored = parseTaskMaskInt(getStringField(fields, "progressReminderSentMask"));
  const legacy = migrateLegacyMilestoneMaskForReminder(
    parseTaskMaskInt(getStringField(fields, "progressMilestoneMask")),
  );
  return stored | legacy;
}

function normalizeProgressStepCron(progress: number | null): number {
  if (progress == null || progress <= 0) return 0;
  const x = Math.min(1, Math.max(0, progress));
  return Math.round(x * 4) / 4;
}

function progressTierReminderBit(norm: number): number {
  if (norm <= 0) return PROGRESS_REMINDER_BIT_0;
  if (norm === 0.25) return PROGRESS_REMINDER_BIT_25;
  if (norm === 0.5) return PROGRESS_REMINDER_BIT_50;
  if (norm === 0.75) return PROGRESS_REMINDER_BIT_75;
  if (norm >= 1) return PROGRESS_REMINDER_BIT_100;
  return 0;
}

function buildProgressTierReminderPayload(
  taskTitle: string,
  tierBit: number,
): { msgTitle: string; msgBody: string; notificationType: string } | null {
  if (tierBit === PROGRESS_REMINDER_BIT_0) {
    return {
      msgTitle: `📌 ${taskTitle}`,
      msgBody: "لم يتم البدء بعد - المهمة ما زالت بدون أي تقدم.",
      notificationType: "employee_progress_reminder_0",
    };
  }
  if (tierBit === PROGRESS_REMINDER_BIT_25) {
    return {
      msgTitle: `🚀 ${taskTitle}`,
      msgBody: "بداية جيدة - تم تسجيل بداية العمل.",
      notificationType: "employee_progress_reminder_25",
    };
  }
  if (tierBit === PROGRESS_REMINDER_BIT_50) {
    return {
      msgTitle: `📊 ${taskTitle}`,
      msgBody: "منتصف الطريق - أداء جيد، استمر.",
      notificationType: "employee_progress_reminder_50",
    };
  }
  if (tierBit === PROGRESS_REMINDER_BIT_75) {
    const useA = Math.random() < 0.5;
    return useA
      ? {
          msgTitle: `🔥 ${taskTitle}`,
          msgBody: "اقتربت من النهاية - باقي القليل.",
          notificationType: "employee_progress_reminder_75_a",
        }
      : {
          msgTitle: `⚡ ${taskTitle}`,
          msgBody: "تقريبًا انتهيت - أكمل المهمة.",
          notificationType: "employee_progress_reminder_75_b",
        };
  }
  if (tierBit === PROGRESS_REMINDER_BIT_100) {
    return {
      msgTitle: `✅ ${taskTitle}`,
      msgBody: "إنجاز كامل - تم إنهاء المهمة بنجاح.",
      notificationType: "employee_progress_reminder_100",
    };
  }
  return null;
}

/** مهام انتهت من ناحية سير العمل — لا نرسل تذكير اقتراب موعد. */
const TASK_ENDED_STATUSES = new Set([
  "status_approved",
  "status_published",
  "status_rejected",
]);

/** حالات جارية — للفحص عن جمود/تحديث (يتطابق مع التطبيق). */
const TASK_ONGOING_STATUSES: string[] = [
  "status_not_start_yet",
  "status_processing",
  "status_under_revision",
  "status_in_edit",
  "status_edit_requested",
  "status_ready_to_publish",
  "status_awaiting_manager",
  "status_scheduled",
];

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
      await sendEmailIfPolicyAllows("manager_task_overdue", m?.email ?? null, "مهمة متأخرة", msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: m?.fcmToken ?? null,
        title: "مهمة متأخرة",
        body: msgBody,
        notificationType: "manager_task_overdue",
      });
    }

    const overdueEmpNotified = getStringField(f, "overdueEmployeeNotifiedAt");
    const dayMs = 24 * 60 * 60 * 1000;
    const lastEmp = overdueEmpNotified ? new Date(overdueEmpNotified).getTime() : 0;
    const canEmp = !overdueEmpNotified || now.getTime() - lastEmp >= dayMs;
    if (canEmp && emp?.fcmToken) {
      const empTitle = "❌ مهمة متأخرة";
      const empBody = `تجاوز موعد التسليم: ${title}`;
      await sendEmailIfPolicyAllows("employee_task_overdue", emp.email ?? null, empTitle, empBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: emp.fcmToken,
        title: empTitle,
        body: empBody,
        notificationType: "employee_task_overdue",
      });
      await patchTaskStringFields(accessToken, t.name, { overdueEmployeeNotifiedAt: notifyStamp });
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
    const notified1h = getStringField(f, "dueSoonNotifiedAt1h");
    const notified12h = getStringField(f, "dueSoonNotifiedAt12h");

    // متبقي أكثر من 23 ساعة وأقل أو يساوي 24 ساعة
    if (hoursUntil <= 24 && hoursUntil > 23 && !notified24) {
      const msgTitle = "⏳ اقتراب موعد التسليم";
      const msgBody = `بقي وقت قليل — ${title}`;
      await sendEmailIfPolicyAllows("employee_task_due_soon", emp?.email ?? null, msgTitle, msgBody);
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

    if (hoursUntil <= 12 && hoursUntil > 11 && !notified12h) {
      const msgTitle = "⏳ متابعة: المهمة ما زالت بانتظار إجراء";
      const msgBody = `${title} — يرجى التصرف قبل الموعد.`;
      await sendEmailIfPolicyAllows("employee_task_followup", emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: emp?.fcmToken ?? null,
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_followup",
      });
      await patchTaskStringFields(accessToken, t.name, { dueSoonNotifiedAt12h: notifyStamp });
    }

    if (hoursUntil <= 6 && hoursUntil > 5 && !notified6) {
      const msgTitle = "⏳ اقتراب موعد التسليم (6 ساعات)";
      const msgBody = `بقي وقت قليل — ${title}`;
      await sendEmailIfPolicyAllows("employee_task_due_soon", emp?.email ?? null, msgTitle, msgBody);
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

    if (hoursUntil <= 1 && hoursUntil > 1 / 60 && !notified1h) {
      const msgTitle = "⏳ متبقي حوالي ساعة على التسليم";
      const msgBody = title;
      await sendEmailIfPolicyAllows("employee_task_due_soon_1h", emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: emp?.fcmToken ?? null,
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_due_soon_1h",
      });
      await patchTaskStringFields(accessToken, t.name, { dueSoonNotifiedAt1h: notifyStamp });
    }
  }

  const in72hMs = 72 * 60 * 60 * 1000;

  // تذكير بالبدء: لم تبدأ بعد تاريخ البدء
  const notStartedTasks = await runQuery({
    accessToken,
    projectId,
    structuredQuery: {
      from: [{ collectionId: "tasks" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            { fieldFilter: { field: { fieldPath: "status" }, op: "EQUAL", value: { stringValue: "status_not_start_yet" } } },
            { fieldFilter: { field: { fieldPath: "fromDate" }, op: "LESS_THAN", value: { stringValue: nowIso } } },
            { fieldFilter: { field: { fieldPath: "assignedTo" }, op: "GREATER_THAN", value: { stringValue: "" } } },
          ],
        },
      },
      limit: 35,
    },
  });

  for (const t of notStartedTasks) {
    const f = t.fields as any;
    const title = (f?.title?.stringValue as string) ?? "مهمة";
    const assignedTo = (f?.assignedTo?.stringValue as string) ?? "";
    if (!assignedTo) continue;
    const startN = getStringField(f, "startReminderNotifiedAt");
    if (hoursSinceIso(startN, now) < 24) continue;
    const emp = byEmpId.get(assignedTo);
    const msgTitle = "⏰ تذكير بالبدء";
    const msgBody = `لم تبدأ بعد — ${title}`;
    await sendEmailIfPolicyAllows("employee_task_start_reminder", emp?.email ?? null, msgTitle, msgBody);
    await sendFcm({
      accessToken,
      fcmUrl,
      token: emp?.fcmToken ?? null,
      title: msgTitle,
      body: msgBody,
      notificationType: "employee_task_start_reminder",
    });
    await patchTaskStringFields(accessToken, t.name, { startReminderNotifiedAt: notifyStamp });
  }

  // تحذير إداري: لم يتخذ إجراء بعد مرور 48 ساعة على تاريخ البدء
  for (const t of notStartedTasks) {
    const f = t.fields as any;
    const title = (f?.title?.stringValue as string) ?? "مهمة";
    const assignedTo = (f?.assignedTo?.stringValue as string) ?? "";
    const fromStr = getStringField(f, "fromDate");
    if (!assignedTo || !fromStr) continue;
    const fromD = new Date(fromStr).getTime();
    if (Number.isNaN(fromD) || now.getTime() - fromD < 48 * 60 * 60 * 1000) continue;
    const mgrN = getStringField(f, "managerNoActionNotifiedAt");
    if (hoursSinceIso(mgrN, now) < 24) continue;
    const emp = byEmpId.get(assignedTo);
    const empName = emp?.name ?? assignedTo;
    const msgBody = `«${title}» — ${empName} لم يبدأ بعد تاريخ البدء.`;
    for (const id of managers) {
      const m = byEmpId.get(id);
      await sendEmailIfPolicyAllows("manager_task_no_action", m?.email ?? null, "⚠️ لم يتخذ موظف إجراءً على المهمة", msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: m?.fcmToken ?? null,
        title: "⚠️ لم يتخذ موظف إجراءً على المهمة",
        body: msgBody,
        notificationType: "manager_task_no_action",
      });
    }
    await patchTaskStringFields(accessToken, t.name, { managerNoActionNotifiedAt: notifyStamp });
  }

  // مهام قيد التنفيذ دون تقدم مسجّل بعد 48 ساعة من البدء
  const processingNoProgress = await runQuery({
    accessToken,
    projectId,
    structuredQuery: {
      from: [{ collectionId: "tasks" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            { fieldFilter: { field: { fieldPath: "status" }, op: "EQUAL", value: { stringValue: "status_processing" } } },
            { fieldFilter: { field: { fieldPath: "assignedTo" }, op: "GREATER_THAN", value: { stringValue: "" } } },
          ],
        },
      },
      limit: 40,
    },
  });

  for (const t of processingNoProgress) {
    const f = t.fields as any;
    const title = (f?.title?.stringValue as string) ?? "مهمة";
    const assignedTo = (f?.assignedTo?.stringValue as string) ?? "";
    const fromStr = getStringField(f, "fromDate");
    const prog = getDoubleField(f, "progress");
    if (!assignedTo || !fromStr) continue;
    if (prog != null && prog > 0) continue;
    const fromD = new Date(fromStr).getTime();
    if (Number.isNaN(fromD) || now.getTime() - fromD < 48 * 60 * 60 * 1000) continue;
    const np = getStringField(f, "noProgressRemindedAt");
    if (hoursSinceIso(np, now) < 72) continue;
    const emp = byEmpId.get(assignedTo);
    const msgTitle = "📌 لا يزال بلا تقدم مسجّل";
    const msgBody = `${title} — سجّل تقدمك.`;
    await sendEmailIfPolicyAllows("employee_task_no_progress_yet", emp?.email ?? null, msgTitle, msgBody);
    await sendFcm({
      accessToken,
      fcmUrl,
      token: emp?.fcmToken ?? null,
      title: msgTitle,
      body: msgBody,
      notificationType: "employee_task_no_progress_yet",
    });
    await patchTaskStringFields(accessToken, t.name, { noProgressRemindedAt: notifyStamp });
  }

  // جمود 72 ساعة: موظف (تحديث) + إدارة (توقف تقدم) — يتطلب `toDate` في المستقبل
  const ongoingTasks = await runQuery({
    accessToken,
    projectId,
    structuredQuery: {
      from: [{ collectionId: "tasks" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: "status" },
                op: "IN",
                value: {
                  arrayValue: {
                    values: TASK_ONGOING_STATUSES.map((s) => ({ stringValue: s })),
                  },
                },
              },
            },
            { fieldFilter: { field: { fieldPath: "assignedTo" }, op: "GREATER_THAN", value: { stringValue: "" } } },
            { fieldFilter: { field: { fieldPath: "toDate" }, op: "GREATER_THAN", value: { stringValue: nowIso } } },
          ],
        },
      },
      limit: 45,
    },
  });

  for (const t of ongoingTasks) {
    const f = t.fields as any;
    const title = (f?.title?.stringValue as string) ?? "مهمة";
    const assignedTo = (f?.assignedTo?.stringValue as string) ?? "";
    const st = getStringField(f, "status") ?? "";
    if (!assignedTo || TASK_ENDED_STATUSES.has(st)) continue;

    const emp = byEmpId.get(assignedTo);

    {
      const prog = getDoubleField(f, "progress");
      const norm = normalizeProgressStepCron(prog);
      const tierBit = progressTierReminderBit(norm);
      if (tierBit !== 0 && emp?.fcmToken) {
        const merged = mergedProgressReminderMask(f);
        if ((merged & tierBit) === 0) {
          const payload = buildProgressTierReminderPayload(title, tierBit);
          if (payload) {
            await sendEmailIfPolicyAllows(
              payload.notificationType,
              emp.email ?? null,
              payload.msgTitle,
              payload.msgBody,
            );
            await sendFcm({
              accessToken,
              fcmUrl,
              token: emp.fcmToken,
              title: payload.msgTitle,
              body: payload.msgBody,
              notificationType: payload.notificationType,
            });
            const prev = parseTaskMaskInt(getStringField(f, "progressReminderSentMask"));
            await patchTaskStringFields(accessToken, t.name, {
              progressReminderSentMask: String(prev | tierBit),
            });
          }
        }
      }
    }

    const latestMs = getLatestActivityMs(f);
    if (latestMs === 0) continue;
    const inactiveMs = now.getTime() - latestMs;
    if (inactiveMs < in72hMs) continue;

    const empName = emp?.name ?? assignedTo;

    const staleN = getStringField(f, "staleUpdateNotifiedAt");
    if (hoursSinceIso(staleN, now) >= 72) {
      const msgTitle = "📝 تحديث المهمة مطلوب";
      const msgBody = `لم يُحدَّث «${title}» منذ فترة.`;
      await sendEmailIfPolicyAllows("employee_task_stale_update", emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        token: emp?.fcmToken ?? null,
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_stale_update",
      });
      await patchTaskStringFields(accessToken, t.name, { staleUpdateNotifiedAt: notifyStamp });
    }

    const stallN = getStringField(f, "managerStalledNotifiedAt");
    if (hoursSinceIso(stallN, now) >= 72) {
      const msgBody = `لا تسجيل لتقدم جديد على «${title}» (${empName}) منذ فترة.`;
      for (const id of managers) {
        const m = byEmpId.get(id);
        await sendEmailIfPolicyAllows("manager_task_progress_stalled", m?.email ?? null, "⛔ توقف التقدم", msgBody);
        await sendFcm({
          accessToken,
          fcmUrl,
          token: m?.fcmToken ?? null,
          title: "⛔ توقف التقدم",
          body: msgBody,
          notificationType: "manager_task_progress_stalled",
        });
      }
      await patchTaskStringFields(accessToken, t.name, { managerStalledNotifiedAt: notifyStamp });
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
    await sendEmailIfPolicyAllows("client_pending_over_24h", client?.email ?? null, msgTitle, title);
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
    await sendEmailIfPolicyAllows("publish_post_one_hour", target.email ?? null, msgTitle, title);
    await sendFcm({
      accessToken,
      fcmUrl,
      token: target.fcmToken ?? null,
      title: msgTitle,
      body: title,
      notificationType: "publish_post_one_hour",
    });
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
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-cron-secret",
  };
}
