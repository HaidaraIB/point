/**
 * جدولة Supabase Cron (مثال جسم الطلب):
 * `POST` + JSON `{ "mode": "unread_chats", "firebaseProjectId": "<optional>" }`
 * مع الرؤوس: `Authorization: Bearer <SUPABASE_ANON_KEY>`, `apikey`, `x-cron-secret: <CRON_SECRET>`.
 *
 * أوضاع `mode`: `tasks` | `content24h` | `publish` | `unread_chats` | `attendance` | `all`.
 * **تجنّب `all` في الإنتاج** عند كثرة المستخدمين — حدود زمن Edge قد تقطع التنفيذ؛
 * جدولة كرون منفصلة لكل `mode` + `unread_chats` منفصل دائماً عند كثرة المحادثات.
 */
import "https://deno.land/std@0.177.0/http/server.ts";
import type { ServiceAccountJson } from "../_shared/firebase-edge.ts";
import { resolveServiceAccountForScheduledCron } from "../_shared/firebase-edge.ts";
import {
  extractFcmTokensFromFirestoreFields,
  fcmPayloadImpliesInvalidToken,
  maskFcmToken,
} from "../_shared/fcm_tokens.ts";
import {
  buildChatUnreadDigestEmailHtml,
  buildEmailHtml,
  type ChatDigestRow,
  type EmailLocale,
} from "../send-notification-email/email-template.ts";

// نطاق يغطي Firestore REST و FCM v1؛ `firebase.messaging` وحدها تسبب 403 على list/query في Firestore.
const GOOGLE_ACCESS_SCOPE = "https://www.googleapis.com/auth/cloud-platform";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const RESEND_URL = "https://api.resend.com/emails";
const FROM_EMAIL = "Point Agency <no-reply@mail.point-iq.app>";

const CRON_FCM_VERSION = "scheduled-notifications-v6";

type CronFcmAgg = {
  sendAttempts: number;
  sendOk: number;
  sendFailed: number;
  recipientsWithNoToken: number;
  invalidTokensCleaned: number;
};

let cronFcmAgg: CronFcmAgg = {
  sendAttempts: 0,
  sendOk: 0,
  sendFailed: 0,
  recipientsWithNoToken: 0,
  invalidTokensCleaned: 0,
};

function resetCronFcmAgg(): void {
  cronFcmAgg = {
    sendAttempts: 0,
    sendOk: 0,
    sendFailed: 0,
    recipientsWithNoToken: 0,
    invalidTokensCleaned: 0,
  };
}

function snapshotCronFcmAgg(): CronFcmAgg {
  return { ...cronFcmAgg };
}

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
    const mode = (body?.mode ?? "all").toLowerCase();
    console.log(
      JSON.stringify({
        cronStart: true,
        mode,
        firebaseProjectId: body.firebaseProjectId ?? null,
      }),
    );
    resetCronFcmAgg();
    const started = Date.now();
    const sa = resolveServiceAccountForScheduledCron(body.firebaseProjectId);
    console.log(JSON.stringify({ cronFirebaseProject: sa.project_id }));
    const accessToken = await getAccessToken(sa);
    const firestoreBase = `https://firestore.googleapis.com/v1/projects/${sa.project_id}/databases/(default)/documents`;
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    const now = new Date();

    if (mode === "unread_chats") {
      await handleUnreadChatDigest({ accessToken, firestoreBase, fcmUrl, projectId: sa.project_id });
      const fcm = snapshotCronFcmAgg();
      const durationMs = Date.now() - started;
      console.log(
        JSON.stringify({
          cronCompletion: "unread_chats",
          durationMs,
          fcm,
          warnAllMode: false,
        }),
      );
      return json({ ok: true, mode: "unread_chats", durationMs, fcm }, 200);
    }

    if (mode === "attendance") {
      await handleAttendanceReminders({ accessToken, firestoreBase, fcmUrl, now, projectId: sa.project_id });
      const fcm = snapshotCronFcmAgg();
      const durationMs = Date.now() - started;
      return json({ ok: true, mode: "attendance", durationMs, fcm }, 200);
    }

    if (mode === "tasks" || mode === "all") {
      await handleTaskReminders({ accessToken, firestoreBase, fcmUrl, now, projectId: sa.project_id });
    }
    if (mode === "content24h" || mode === "all") {
      await handleContentPendingOver24h({ accessToken, firestoreBase, fcmUrl, now, projectId: sa.project_id });
    }
    if (mode === "publish" || mode === "all") {
      await handlePublishReminders({ accessToken, firestoreBase, fcmUrl, now, projectId: sa.project_id });
    }
    if (mode === "attendance" || mode === "all") {
      await handleAttendanceReminders({ accessToken, firestoreBase, fcmUrl, now, projectId: sa.project_id });
    }

    const fcm = snapshotCronFcmAgg();
    const durationMs = Date.now() - started;
    console.log(
      JSON.stringify({
        cronCompletion: mode,
        durationMs,
        fcm,
        warnAllMode: mode === "all",
      }),
    );
    return json(
      {
        ok: true,
        mode,
        durationMs,
        fcm,
        ...(mode === "all"
          ? {
            schedulingHint:
              "Prefer separate cron jobs per mode (tasks, content24h, publish) to avoid Edge timeouts.",
          }
          : {}),
      },
      200,
    );
  } catch (e) {
    const details = e instanceof Error ? e.message : String(e);
    const stack = e instanceof Error ? e.stack : undefined;
    console.error(
      JSON.stringify({
        cronError: true,
        errorCode: "ERR_SERVER",
        details,
        stack: stack?.slice(0, 2000),
      }),
    );
    return json({ errorCode: "ERR_SERVER", details }, 500);
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

async function writeCronPushDiagnostic(args: {
  accessToken: string;
  projectId: string;
  requestId: string;
  stage: string;
  status: "ok" | "error";
  recipientId?: string;
  recipientKind?: "employee" | "client";
  tokenMasked?: string;
  title?: string;
  bodyLen?: number;
  notificationType?: string;
  fcmHttpStatus?: number;
  fcmErrorCode?: string;
  fcmErrorMessage?: string;
  details?: unknown;
}): Promise<void> {
  if (args.status !== "error") return;
  try {
    const url =
      `https://firestore.googleapis.com/v1/projects/${args.projectId}/databases/(default)/documents/push_diagnostics`;
    const fields: Record<string, unknown> = {
      requestId: { stringValue: args.requestId },
      stage: { stringValue: args.stage },
      status: { stringValue: args.status },
      targetType: { stringValue: "token" },
      functionVersion: { stringValue: CRON_FCM_VERSION },
      createdAt: { timestampValue: new Date().toISOString() },
      bodyLen: { integerValue: String(args.bodyLen ?? 0) },
      source: { stringValue: "scheduled_notifications" },
    };
    if (args.recipientId) fields.recipientId = { stringValue: args.recipientId };
    if (args.recipientKind) fields.recipientKind = { stringValue: args.recipientKind };
    if (args.tokenMasked) fields.tokenMasked = { stringValue: args.tokenMasked };
    if (args.title) fields.title = { stringValue: args.title };
    if (args.notificationType) fields.notificationType = { stringValue: args.notificationType };
    if (typeof args.fcmHttpStatus === "number") {
      fields.fcmHttpStatus = { integerValue: String(args.fcmHttpStatus) };
    }
    if (args.fcmErrorCode) fields.fcmErrorCode = { stringValue: args.fcmErrorCode };
    if (args.fcmErrorMessage) fields.fcmErrorMessage = { stringValue: args.fcmErrorMessage };
    if (args.details !== undefined) {
      fields.detailsJson = { stringValue: JSON.stringify(args.details).slice(0, 1400) };
    }
    await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${args.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields }),
    });
  } catch (_) {
    // non-blocking
  }
}

async function removeInvalidFcmTokenFromDoc(
  accessToken: string,
  projectId: string,
  collectionId: "employees" | "clients",
  userId: string,
  badToken: string,
): Promise<void> {
  const docPath = `projects/${projectId}/databases/(default)/documents/${collectionId}/${userId}`;
  const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const getUrl = `https://firestore.googleapis.com/v1/${docPath}`;
  const getRes = await fetch(getUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
  let clearSingle = false;
  if (getRes.ok) {
    const doc = await getRes.json() as { fields?: Record<string, unknown> };
    const single = getStringField(doc.fields ?? {}, "fcmToken")?.trim();
    clearSingle = single === badToken;
  }
  const writes: Record<string, unknown>[] = [
    {
      transform: {
        document: docPath,
        fieldTransforms: [
          {
            fieldPath: "fcmTokens",
            removeAllFromArray: {
              values: [{ stringValue: badToken }],
            },
          },
        ],
      },
    },
  ];
  if (clearSingle) {
    writes.push({
      update: {
        name: docPath,
        fields: {
          fcmToken: { nullValue: "NULL_VALUE" },
        },
      },
      updateMask: { fieldPaths: ["fcmToken"] },
    });
  }
  const res = await fetch(commitUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ writes }),
  });
  if (!res.ok) {
    console.error("removeInvalidFcmTokenFromDoc failed", await res.text().catch(() => ""));
  }
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
  htmlOverride?: string | null,
) {
  if (!shouldSendEmailForNotificationTypeCron(notificationType)) return;
  await sendEmailIfPossible(toEmail, subject, body, htmlOverride);
}

async function sendEmailIfPossible(
  toEmail: string | null,
  subject: string,
  body: string,
  /** عند التمرير يُستخدم بدل buildEmailHtml(body) — لملخص الدردشة وغيره */
  htmlOverride?: string | null,
) {
  if (!toEmail) return;
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) return;
  const html = htmlOverride != null && htmlOverride.length > 0 ? htmlOverride : buildEmailHtml(body);
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
      html,
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
    chat_unread_digest: "notification_chat",
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
/** Matches [send-fcm] FCM_NOTIFICATION_TTL_SEC / apns-expiration for offline delivery. */
const FCM_CRON_NOTIFICATION_TTL_SEC = 86400;

function apnsExpirationHeaderValueCron(): string {
  return String(Math.floor(Date.now() / 1000) + FCM_CRON_NOTIFICATION_TTL_SEC);
}

/** Matches [send-fcm] android.notification.tag for per-chat replacement on Android. */
function androidChatCollapseTagFromDataCron(data: Record<string, string>): string | undefined {
  const t = (data.notificationType ?? "").trim();
  if (t !== "chat_message") return undefined;
  const cid = (data.chatId ?? "").trim();
  if (!cid) return undefined;
  const raw = `point_chat_${cid}`;
  return raw.length <= 64 ? raw : raw.slice(0, 64);
}

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
  const apnsHeaders: Record<string, string> = {
    ...(apnsBlock.headers ?? {}),
    "apns-expiration": apnsExpirationHeaderValueCron(),
  };

  const androidCollapseTag = androidChatCollapseTagFromDataCron(dataPayload);
  const isAndroidChatDataOnly = androidCollapseTag !== undefined;
  const androidNotification: Record<string, unknown> = {
    title,
    body,
    ...androidExtra,
  };
  if (androidCollapseTag) {
    androidNotification.tag = androidCollapseTag;
  }

  const msg: Record<string, unknown> = {
    token,
    android: {
      priority: "high",
      ttl: `${FCM_CRON_NOTIFICATION_TTL_SEC}s`,
      ...(isAndroidChatDataOnly ? {} : { notification: androidNotification }),
    },
    apns: {
      headers: apnsHeaders,
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
  if (!isAndroidChatDataOnly) {
    msg.notification = {
      title,
      body,
    };
  }
  if (Object.keys(dataPayload).length > 0) {
    msg.data = dataPayload;
  }
  return msg;
}

/** يطابق [_shouldPersistFcmToNotificationInbox] في [firestore_fcm_api.dart] — لا نحفظ محادثات الدردشة ولا ملخص غير المقروء. */
function shouldPersistInAppNotification(notificationType: string | undefined): boolean {
  const t = (notificationType ?? "").trim();
  return t !== "chat_message" && t !== "chat_unread_digest";
}

/** يطابق [FirestoreNotificationApi.addNotification] — مجموعة `notifications` للوارد داخل التطبيق. */
async function persistInAppNotification(
  accessToken: string,
  projectId: string,
  recipientId: string,
  title: string,
  body: string,
): Promise<void> {
  const rid = recipientId.trim();
  if (!rid) return;
  try {
    const url =
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/notifications`;
    const fields: Record<string, unknown> = {
      title: { stringValue: title },
      body: { stringValue: body },
      recipientId: { stringValue: rid },
      createdAt: { stringValue: new Date().toISOString() },
      isRead: { booleanValue: false },
    };
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields }),
    });
    if (!res.ok) {
      const out = await res.text().catch(() => "");
      console.error("persistInAppNotification failed", res.status, out.slice(0, 800));
    }
  } catch (e) {
    console.error("persistInAppNotification error", String(e));
  }
}

function getStringArrayField(fields: Record<string, unknown>, key: string): string[] {
  const raw = (fields[key] as { arrayValue?: { values?: unknown[] } })?.arrayValue?.values;
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const item of raw) {
    const s = (item as { stringValue?: string })?.stringValue;
    if (typeof s === "string" && s.length > 0) out.push(s);
  }
  return out;
}

function getBooleanField(fields: Record<string, unknown>, key: string): boolean {
  return (fields[key] as { booleanValue?: boolean })?.booleanValue === true;
}

function chatIdFromDocumentName(name: string): string {
  const parts = name.split("/");
  return parts[parts.length - 1] ?? "";
}

/** Firestore `language` on employees/clients — default Arabic to match the app. */
function normalizeDigestLang(raw: string | null | undefined): EmailLocale {
  const s = (raw ?? "").trim().toLowerCase();
  return s === "en" ? "en" : "ar";
}

const CHAT_UNREAD_DIGEST_COPY: Record<
  EmailLocale,
  { pushTitle: string; pushBody: string; emailSubject: string; emailIntro: string }
> = {
  ar: {
    pushTitle: "Point",
    pushBody: "لديك رسائل غير مقروءة. افتح التطبيق لقراءتها.",
    emailSubject: "رسائل غير مقروءة — Point Agency",
    emailIntro: "لديك رسائل لم تُقرأ في المحادثات التالية:",
  },
  en: {
    pushTitle: "Point",
    pushBody: "You have unread messages. Open the app to read them.",
    emailSubject: "Unread messages — Point Agency",
    emailIntro: "You have unread messages in the following chats:",
  },
};

function chatUnreadDigestRowPlain(lang: EmailLocale, n: number, label: string): string {
  const k = Math.max(0, Math.floor(n));
  if (lang === "en") {
    return `You have ${k} unread message${k === 1 ? "" : "s"} from ${label}`;
  }
  const word = k === 1 ? "رسالة" : k === 2 ? "رسالتان" : "رسائل";
  return `لديك ${k} ${word} غير مقروءة من ${label}`;
}

async function getFirestoreDocument(
  accessToken: string,
  firestoreBase: string,
  relativePath: string,
): Promise<{ name: string; fields: Record<string, unknown> } | null> {
  const segments = relativePath.split("/").map(encodeURIComponent).join("/");
  const url = `${firestoreBase}/${segments}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (res.status === 404) return null;
  if (!res.ok) {
    console.error("getFirestoreDocument", relativePath, await res.text().catch(() => ""));
    return null;
  }
  const data = await res.json();
  if (!data.fields) return null;
  return { name: data.name, fields: data.fields };
}

type ResolvedProfile = {
  name: string | null;
  image: string | null;
  email: string | null;
  /** Same semantics as Flutter `_extractFcmTokens` (fcmToken + fcmTokens[]). */
  fcmTokens: string[];
  /** Where this profile was loaded from (for token invalidation). */
  sourceCollection: "employees" | "clients";
  /** UI locale from Firestore `language` — `ar`|`en`; default `ar`. */
  language: EmailLocale;
};

async function resolveUserProfile(
  accessToken: string,
  firestoreBase: string,
  userId: string,
  cache: Map<string, ResolvedProfile | null>,
): Promise<ResolvedProfile | null> {
  if (cache.has(userId)) return cache.get(userId) ?? null;
  let doc = await getFirestoreDocument(accessToken, firestoreBase, `employees/${userId}`);
  let sourceCollection: "employees" | "clients" = "employees";
  if (!doc) {
    doc = await getFirestoreDocument(accessToken, firestoreBase, `clients/${userId}`);
    sourceCollection = "clients";
  }
  if (!doc) {
    cache.set(userId, null);
    return null;
  }
  const f = doc.fields;
  const prof: ResolvedProfile = {
    name: getStringField(f, "name"),
    image: getStringField(f, "image"),
    email: getStringField(f, "email"),
    fcmTokens: extractFcmTokensFromFirestoreFields(f),
    sourceCollection,
    language: normalizeDigestLang(getStringField(f, "language")),
  };
  cache.set(userId, prof);
  return prof;
}

async function queryUnreadMessagesForChat(
  accessToken: string,
  firestoreBase: string,
  chatId: string,
): Promise<Array<{ name: string; fields: Record<string, unknown> }>> {
  const url = `${firestoreBase}/chats/${encodeURIComponent(chatId)}:runQuery`;
  const structuredQuery = {
    from: [{ collectionId: "messages" }],
    where: {
      fieldFilter: {
        field: { fieldPath: "isRead" },
        op: "EQUAL",
        value: { booleanValue: false },
      },
    },
    limit: 500,
  };
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ structuredQuery }),
  });
  const data = await res.json();
  if (!res.ok) {
    console.error("queryUnreadMessagesForChat", chatId, JSON.stringify(data).slice(0, 400));
    return [];
  }
  const out: Array<{ name: string; fields: Record<string, unknown> }> = [];
  for (
    const row of data as Array<{ document?: { name?: string; fields?: Record<string, unknown> } }>
  ) {
    if (row?.document?.name && row?.document?.fields) {
      out.push({ name: row.document.name, fields: row.document.fields });
    }
  }
  return out;
}

/** كرون منفصل: بريد مفصّل + دفع خفيف لكل موظف/عميل لديه رسائل غير مقروءة واردة. */
async function handleUnreadChatDigest(args: {
  accessToken: string;
  firestoreBase: string;
  fcmUrl: string;
  projectId: string;
}): Promise<void> {
  const { accessToken, firestoreBase, fcmUrl, projectId } = args;
  const profileCache = new Map<string, ResolvedProfile | null>();
  const digestByUser = new Map<string, ChatDigestRow[]>();

  let pageToken: string | undefined;
  do {
    let listUrl = `${firestoreBase}/chats?pageSize=100`;
    if (pageToken) listUrl += `&pageToken=${encodeURIComponent(pageToken)}`;
    const res = await fetch(listUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
    const data = await res.json();
    if (!res.ok) {
      console.error("handleUnreadChatDigest list chats", JSON.stringify(data).slice(0, 600));
      break;
    }
    const docs = (data.documents ?? []) as Array<{ name: string; fields: Record<string, unknown> }>;
    pageToken = typeof data.nextPageToken === "string" ? data.nextPageToken : undefined;

    for (const doc of docs) {
      const chatId = chatIdFromDocumentName(doc.name);
      const fields = doc.fields;
      const participants = getStringArrayField(fields, "participants");
      if (participants.length === 0) continue;

      const messages = await queryUnreadMessagesForChat(accessToken, firestoreBase, chatId);
      if (messages.length === 0) continue;

      const isGroup = getBooleanField(fields, "isGroup") || participants.length > 2;
      const groupTitle = getStringField(fields, "title") ?? "Group";

      for (const p of participants) {
        let cnt = 0;
        for (const msg of messages) {
          const senderId = getStringField(msg.fields, "senderId");
          if (!senderId || senderId === p) continue;
          const text =
            getStringField(msg.fields, "text") ??
            getStringField(msg.fields, "body") ??
            "";
          if (!text.trim()) continue;
          cnt++;
        }
        if (cnt <= 0) continue;

        let label: string;
        let imageUrl: string | null | undefined;
        if (isGroup) {
          label = groupTitle;
          imageUrl = null;
        } else {
          const other = participants.find((x) => x !== p);
          if (!other) continue;
          const op = await resolveUserProfile(accessToken, firestoreBase, other, profileCache);
          label = op?.name?.trim() || other;
          imageUrl = op?.image?.trim() || null;
        }

        if (!digestByUser.has(p)) digestByUser.set(p, []);
        digestByUser.get(p)!.push({
          count: cnt,
          label,
          imageUrl,
        });
      }
    }
  } while (pageToken);

  const DIGEST_TYPE = "chat_unread_digest";

  for (const [userId, rows] of digestByUser) {
    if (rows.length === 0) continue;
    const me = await resolveUserProfile(accessToken, firestoreBase, userId, profileCache);
    if (!me) continue;
    const email = me.email?.trim() || null;

    const lang = me.language;
    const t = CHAT_UNREAD_DIGEST_COPY[lang];
    const plainLines = [
      t.emailIntro,
      "",
      ...rows.map((r) => chatUnreadDigestRowPlain(lang, r.count, r.label)),
    ];
    const plainBody = plainLines.join("\n");
    const html = buildChatUnreadDigestEmailHtml({
      intro: t.emailIntro,
      rows,
      language: lang,
    });

    if (!email && me.fcmTokens.length === 0) continue;

    if (email) {
      await sendEmailIfPolicyAllows(DIGEST_TYPE, email, t.emailSubject, plainBody, html);
    }

    if (me.fcmTokens.length > 0) {
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: me.fcmTokens,
        title: t.pushTitle,
        body: plainBody,
        notificationType: DIGEST_TYPE,
        recipientId: userId,
        recipientKind: me.sourceCollection === "clients" ? "client" : "employee",
        projectId,
      });
    }
  }
}

async function sendFcm({
  accessToken,
  fcmUrl,
  tokens,
  title,
  body,
  notificationType,
  dataExtras,
  recipientId,
  recipientKind,
  projectId,
}: {
  accessToken: string;
  fcmUrl: string;
  tokens: string[];
  title: string;
  body: string;
  notificationType?: string;
  dataExtras?: Record<string, string>;
  /** معرّف الموظف أو العميل في Firestore — لحفظ نسخة في مجموعة notifications (مثل تدفق التطبيق). */
  recipientId?: string | null;
  recipientKind?: "employee" | "client";
  projectId?: string;
}) {
  if (
    recipientId &&
    projectId &&
    shouldPersistInAppNotification(notificationType)
  ) {
    await persistInAppNotification(accessToken, projectId, recipientId, title, body);
  }
  const cleaned = [...new Set(tokens.map((t) => t.trim()).filter((t) => t.length > 0))];
  if (cleaned.length === 0) {
    cronFcmAgg.recipientsWithNoToken++;
    if (recipientId && projectId) {
      await writeCronPushDiagnostic({
        accessToken,
        projectId,
        requestId: `cron_${crypto.randomUUID()}`,
        stage: "cron_validation",
        status: "error",
        recipientId,
        recipientKind,
        title,
        bodyLen: body.length,
        notificationType,
        details: { reason: "no_fcm_tokens" },
      });
    }
    return;
  }

  const soundBase = soundBaseForNotificationTypeCron(notificationType);
  const dataPayloadBase: Record<string, string> = {};
  if (notificationType && notificationType.trim().length > 0) {
    dataPayloadBase.notificationType = notificationType.trim();
  }
  if (soundBase) {
    dataPayloadBase.pushSoundBase = soundBase;
  }
  if ((notificationType ?? "").trim() === "chat_unread_digest") {
    dataPayloadBase.openScreen = "chats";
  }
  dataPayloadBase.title = title;
  dataPayloadBase.body = body;
  if (dataExtras) {
    for (const [k, v] of Object.entries(dataExtras)) {
      if (k.trim().length === 0) continue;
      dataPayloadBase[k] = v;
    }
  }

  for (const token of cleaned) {
    const webTag = `point-cron-${crypto.randomUUID()}`;
    const dataPayload = { ...dataPayloadBase, requestId: webTag };
    const message = buildFcmV1NotificationMessageCron(
      token,
      title,
      body,
      dataPayload,
      soundBase,
      webTag,
    );
    cronFcmAgg.sendAttempts++;
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
    if (!res) {
      cronFcmAgg.sendFailed++;
      if (projectId) {
        await writeCronPushDiagnostic({
          accessToken,
          projectId,
          requestId: webTag,
          stage: "cron_fcm_http",
          status: "error",
          recipientId: recipientId ?? undefined,
          recipientKind,
          tokenMasked: maskFcmToken(token),
          title,
          bodyLen: body.length,
          notificationType,
          details: { reason: "network_or_null_response" },
        });
      }
      continue;
    }
    const outRaw = await res.text().catch(() => "");
    let outParsed: Record<string, unknown> = {};
    try {
      outParsed = outRaw ? JSON.parse(outRaw) as Record<string, unknown> : {};
    } catch {
      outParsed = { raw: outRaw.slice(0, 400) };
    }
    if (!res.ok) {
      cronFcmAgg.sendFailed++;
      const fcmError = (outParsed as { error?: { code?: string; message?: string } }).error;
      if (projectId) {
        await writeCronPushDiagnostic({
          accessToken,
          projectId,
          requestId: webTag,
          stage: "cron_fcm_result",
          status: "error",
          recipientId: recipientId ?? undefined,
          recipientKind,
          tokenMasked: maskFcmToken(token),
          title,
          bodyLen: body.length,
          notificationType,
          fcmHttpStatus: res.status,
          fcmErrorCode: fcmError?.code,
          fcmErrorMessage: fcmError?.message,
          details: outParsed,
        });
      }
      if (
        recipientId &&
        projectId &&
        recipientKind &&
        fcmPayloadImpliesInvalidToken(outParsed)
      ) {
        await removeInvalidFcmTokenFromDoc(
          accessToken,
          projectId,
          recipientKind === "client" ? "clients" : "employees",
          recipientId,
          token,
        );
        cronFcmAgg.invalidTokensCleaned++;
      }
      console.error("sendFcm failed", res.status, outRaw.slice(0, 1400));
      continue;
    }
    cronFcmAgg.sendOk++;
    if (projectId) {
      const fcmMessageName = typeof (outParsed as { name?: string }).name === "string"
        ? (outParsed as { name: string }).name
        : undefined;
      await writeCronPushDiagnostic({
        accessToken,
        projectId,
        requestId: webTag,
        stage: "cron_fcm_result",
        status: "ok",
        recipientId: recipientId ?? undefined,
        recipientKind,
        tokenMasked: maskFcmToken(token),
        title,
        bodyLen: body.length,
        notificationType,
        fcmHttpStatus: res.status,
        details: { fcmMessageName },
      });
    }
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

/** مهام انتهت من ناحية سير العمل — لا نرسل تذكير اقتراب موعد / متأخر. (يتوافق مع StorageKeys + نصوص قديمة) */
const TASK_ENDED_STATUSES_ARRAY = [
  "status_approved",
  "status_published",
  "status_rejected",
  "status_task_completed",
  "status_promotion_finished",
  // نصوص عربية/إنجليزية قد تُخزَّن كقيمة status في بيانات قديمة (FunHelper._displayLabelToStatusKey)
  "مهمة مكتملة",
  "تم النشر",
  "مرفوض",
  "انتهاء الترويج",
  "تمت الموافقة",
  "Task completed",
  "Published",
  "Rejected",
  "Approved",
  "task completed",
  "published",
  "rejected",
  "approved",
] as const;

const TASK_ENDED_STATUSES = new Set<string>(TASK_ENDED_STATUSES_ARRAY);
const TASK_ENDED_STATUSES_LOWER = new Set(
  TASK_ENDED_STATUSES_ARRAY.map((s) => s.toLowerCase()),
);

function taskIsEndedForReminders(raw: string | undefined | null): boolean {
  const s = (raw ?? "").trim();
  if (!s) return false;
  if (TASK_ENDED_STATUSES.has(s)) return true;
  return TASK_ENDED_STATUSES_LOWER.has(s.toLowerCase());
}

/** محتوى منشور مسبقاً — لا نرسل تذكير اقتراب موعد النشر. */
const CONTENT_PUBLISHED_STATUSES = new Set(
  ["status_published", "تم النشر", "Published", "published"].map((s) => s.toLowerCase()),
);

function contentIsAlreadyPublishedForReminders(raw: string | undefined | null): boolean {
  const s = (raw ?? "").trim();
  if (!s) return false;
  return CONTENT_PUBLISHED_STATUSES.has(s.toLowerCase());
}

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
  const byEmpId = new Map<string, { name: string; email: string | null; fcmTokens: string[]; role: string | null }>();
  for (const e of employees) {
    const id = e.name.split("/").pop() ?? "";
    byEmpId.set(id, {
      name: getStringField(e.fields, "name") ?? id,
      email: getStringField(e.fields, "email"),
      fcmTokens: extractFcmTokensFromFirestoreFields(e.fields),
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
    if (taskIsEndedForReminders(st)) continue;
    const emp = byEmpId.get(assignedTo);
    const empName = emp?.name ?? assignedTo;
      const msgBody = `المهمة "${title}" متأخرة. الموظف: ${empName}.`;
    for (const id of managers) {
      const m = byEmpId.get(id);
      await sendEmailIfPolicyAllows("manager_task_overdue", m?.email ?? null, "تنبيه مهمة متأخرة", msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: m?.fcmTokens ?? [],
        title: "مهمة متأخرة",
        body: msgBody,
        notificationType: "manager_task_overdue",
        recipientId: id,
        recipientKind: "employee",
        projectId,
      });
    }

    const overdueEmpNotified = getStringField(f, "overdueEmployeeNotifiedAt");
    const dayMs = 24 * 60 * 60 * 1000;
    const lastEmp = overdueEmpNotified ? new Date(overdueEmpNotified).getTime() : 0;
    const canEmp = !overdueEmpNotified || now.getTime() - lastEmp >= dayMs;
    if (canEmp && emp) {
      const empTitle = "مهمة متأخرة";
      const empBody = `انتهى موعد تسليم المهمة "${title}".`;
      await sendEmailIfPolicyAllows("employee_task_overdue", emp.email ?? null, empTitle, empBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: emp.fcmTokens ?? [],
        title: empTitle,
        body: empBody,
        notificationType: "employee_task_overdue",
        recipientId: assignedTo,
        recipientKind: "employee",
        projectId,
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
    if (taskIsEndedForReminders(status)) continue;

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
      const msgTitle = "اقتراب موعد التسليم";
      const msgBody = `المهمة "${title}" تقترب من موعد التسليم.`;
      await sendEmailIfPolicyAllows("employee_task_due_soon", emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: emp?.fcmTokens ?? [],
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_due_soon",
        recipientId: assignedTo,
        recipientKind: "employee",
        projectId,
      });
      await patchTaskStringFields(accessToken, t.name, { dueSoonNotifiedAt24h: notifyStamp });
    }

    if (hoursUntil <= 12 && hoursUntil > 11 && !notified12h) {
      const msgTitle = "متابعة المهمة";
      const msgBody = `المهمة "${title}" ما زالت بانتظار الإجراء.`;
      await sendEmailIfPolicyAllows("employee_task_followup", emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: emp?.fcmTokens ?? [],
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_followup",
        recipientId: assignedTo,
        recipientKind: "employee",
        projectId,
      });
      await patchTaskStringFields(accessToken, t.name, { dueSoonNotifiedAt12h: notifyStamp });
    }

    if (hoursUntil <= 6 && hoursUntil > 5 && !notified6) {
      const msgTitle = "اقتراب موعد التسليم (6 ساعات)";
      const msgBody = `المهمة "${title}" تقترب من الموعد النهائي.`;
      await sendEmailIfPolicyAllows("employee_task_due_soon", emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: emp?.fcmTokens ?? [],
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_due_soon",
        recipientId: assignedTo,
        recipientKind: "employee",
        projectId,
      });
      await patchTaskStringFields(accessToken, t.name, { dueSoonNotifiedAt6h: notifyStamp });
    }

    if (hoursUntil <= 1 && hoursUntil > 1 / 60 && !notified1h) {
      const msgTitle = "متبقي حوالي ساعة على التسليم";
      const msgBody = title;
      await sendEmailIfPolicyAllows("employee_task_due_soon_1h", emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: emp?.fcmTokens ?? [],
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_due_soon_1h",
        recipientId: assignedTo,
        recipientKind: "employee",
        projectId,
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
      const msgTitle = "تذكير بالبدء";
      const msgBody = `لم يبدأ العمل على "${title}" بعد.`;
    await sendEmailIfPolicyAllows("employee_task_start_reminder", emp?.email ?? null, msgTitle, msgBody);
    await sendFcm({
      accessToken,
      fcmUrl,
      tokens: emp?.fcmTokens ?? [],
      title: msgTitle,
      body: msgBody,
      notificationType: "employee_task_start_reminder",
      recipientId: assignedTo,
      recipientKind: "employee",
      projectId,
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
    const msgBody = `الموظف ${empName} لم يبدأ المهمة "${title}" بعد تاريخ البدء.`;
    for (const id of managers) {
      const m = byEmpId.get(id);
      await sendEmailIfPolicyAllows("manager_task_no_action", m?.email ?? null, "تنبيه: لا يوجد إجراء على المهمة", msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: m?.fcmTokens ?? [],
        title: "⚠️ لم يتخذ موظف إجراءً على المهمة",
        body: msgBody,
        notificationType: "manager_task_no_action",
        recipientId: id,
        recipientKind: "employee",
        projectId,
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
    const msgTitle = "لا يوجد تقدم مسجّل";
    const msgBody = `المهمة "${title}" لا تحتوي على تقدم مسجّل بعد.`;
    await sendEmailIfPolicyAllows("employee_task_no_progress_yet", emp?.email ?? null, msgTitle, msgBody);
    await sendFcm({
      accessToken,
      fcmUrl,
      tokens: emp?.fcmTokens ?? [],
      title: msgTitle,
      body: msgBody,
      notificationType: "employee_task_no_progress_yet",
      recipientId: assignedTo,
      recipientKind: "employee",
      projectId,
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
    if (!assignedTo || taskIsEndedForReminders(st)) continue;

    const emp = byEmpId.get(assignedTo);

    {
      const prog = getDoubleField(f, "progress");
      const norm = normalizeProgressStepCron(prog);
      const tierBit = progressTierReminderBit(norm);
      if (tierBit !== 0 && emp) {
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
              tokens: emp.fcmTokens ?? [],
              title: payload.msgTitle,
              body: payload.msgBody,
              notificationType: payload.notificationType,
              recipientId: assignedTo,
              recipientKind: "employee",
              projectId,
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
      const msgTitle = "تحديث المهمة مطلوب";
      const msgBody = `لا يوجد تحديث جديد على "${title}" منذ فترة.`;
      await sendEmailIfPolicyAllows("employee_task_stale_update", emp?.email ?? null, msgTitle, msgBody);
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: emp?.fcmTokens ?? [],
        title: msgTitle,
        body: msgBody,
        notificationType: "employee_task_stale_update",
        recipientId: assignedTo,
        recipientKind: "employee",
        projectId,
      });
      await patchTaskStringFields(accessToken, t.name, { staleUpdateNotifiedAt: notifyStamp });
    }

    const stallN = getStringField(f, "managerStalledNotifiedAt");
    if (hoursSinceIso(stallN, now) >= 72) {
      const msgBody = `لا يوجد تقدم جديد على "${title}" (${empName}) منذ فترة.`;
      for (const id of managers) {
        const m = byEmpId.get(id);
        await sendEmailIfPolicyAllows("manager_task_progress_stalled", m?.email ?? null, "تنبيه توقف التقدم", msgBody);
        await sendFcm({
          accessToken,
          fcmUrl,
          tokens: m?.fcmTokens ?? [],
          title: "⛔ توقف التقدم",
          body: msgBody,
          notificationType: "manager_task_progress_stalled",
          recipientId: id,
          recipientKind: "employee",
          projectId,
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
  const byClientId = new Map<string, { email: string | null; fcmTokens: string[] }>();
  for (const c of clients) {
    const id = c.name.split("/").pop() ?? "";
    byClientId.set(id, {
      email: getStringField(c.fields, "email"),
      fcmTokens: extractFcmTokensFromFirestoreFields(c.fields),
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
    const msgTitle = "محتوى بانتظار المراجعة لأكثر من 24 ساعة";
    await sendEmailIfPolicyAllows("client_pending_over_24h", client?.email ?? null, msgTitle, title);
    await sendFcm({
      accessToken,
      fcmUrl,
      tokens: client?.fcmTokens ?? [],
      title: msgTitle,
      body: title,
      notificationType: "client_pending_over_24h",
      recipientId: clientId,
      recipientKind: "client",
      projectId,
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

  const byEmpId = new Map<string, { email: string | null; fcmTokens: string[]; role: string | null; department: string | null }>();
  for (const e of employees) {
    const id = e.name.split("/").pop() ?? "";
    byEmpId.set(id, {
      email: getStringField(e.fields, "email"),
      fcmTokens: extractFcmTokensFromFirestoreFields(e.fields),
      role: getStringField(e.fields, "role"),
      department: getStringField(e.fields, "department"),
    });
  }
  const publishDept = [...byEmpId.entries()]
    .filter(([, v]) => v.department === "cat6" || v.role === "admin" || v.role === "supervisor")
    .map(([id]) => id);

  const nowIso = now.toISOString();
  /** Lead time before publishDate. Keep cron for mode=publish ≤ this (e.g. every 5–10 min). */
  const PUBLISH_REMINDER_LEAD_MS = 15 * 60 * 1000;
  const inLeadIso = new Date(now.getTime() + PUBLISH_REMINDER_LEAD_MS).toISOString();
  const notifyStamp = nowIso;

  // خلال ١٥ دقيقة — يستبعد المنشور فعلاً عبر الحالة أدناه
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
            { fieldFilter: { field: { fieldPath: "publishDate" }, op: "LESS_THAN_OR_EQUAL", value: { stringValue: inLeadIso } } },
          ],
        },
      },
      limit: 50,
    },
  });

  for (const doc of nearPublish) {
    const f = doc.fields as any;
    const status = getStringField(f, "status") ?? "";
    if (contentIsAlreadyPublishedForReminders(status)) continue;
    if (getStringField(f, "publishSoonNotifiedAt")) continue;

    const title = (f?.title?.stringValue as string) ?? "منشور";
    const executor = (f?.executor?.stringValue as string) ?? "";
    const targetId = executor || publishDept[0];
    const target = targetId ? byEmpId.get(targetId) : null;
    if (!targetId || !target) continue;
    const msgTitle = "تذكير نشر خلال ١٥ دقيقة";
    await sendEmailIfPolicyAllows("publish_post_one_hour", target.email ?? null, msgTitle, title);
    await sendFcm({
      accessToken,
      fcmUrl,
      tokens: target.fcmTokens ?? [],
      title: msgTitle,
      body: title,
      notificationType: "publish_post_one_hour",
      recipientId: targetId,
      recipientKind: "employee",
      projectId,
    });
    await patchTaskStringFields(accessToken, doc.name, { publishSoonNotifiedAt: notifyStamp });
  }
}

function parseHHmm(value: string | null): { hour: number; minute: number } | null {
  if (!value || value.length !== 5 || value[2] !== ":") return null;
  const hour = Number(value.slice(0, 2));
  const minute = Number(value.slice(3, 5));
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return { hour, minute };
}

function localDateKey(now: Date, offsetHours = 3): string {
  const shifted = new Date(now.getTime() + offsetHours * 60 * 60 * 1000);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const d = String(shifted.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function localHourMinute(now: Date, offsetHours = 3): { hour: number; minute: number } {
  const shifted = new Date(now.getTime() + offsetHours * 60 * 60 * 1000);
  return { hour: shifted.getUTCHours(), minute: shifted.getUTCMinutes() };
}

function hhmmToMinutes(value: { hour: number; minute: number }): number {
  return value.hour * 60 + value.minute;
}

async function loadAttendancePolicy(
  accessToken: string,
  projectId: string,
): Promise<{ checkInGraceMinutes: number; checkOutGraceMinutes: number }> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/app_settings/attendance_policy`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!res.ok) {
    return { checkInGraceMinutes: 60, checkOutGraceMinutes: 60 };
  }
  const data = await res.json();
  const fields = (data.fields ?? {}) as Record<string, unknown>;
  const checkIn = getDoubleField(fields, "checkInGraceMinutes") ?? 60;
  const checkOut = getDoubleField(fields, "checkOutGraceMinutes") ?? 60;
  const clamp = (n: number) => Math.min(480, Math.max(5, Math.round(n)));
  return {
    checkInGraceMinutes: clamp(checkIn),
    checkOutGraceMinutes: clamp(checkOut),
  };
}

async function dayOutcomeDocExists(
  accessToken: string,
  projectId: string,
  docId: string,
): Promise<boolean> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/attendance_day_outcomes/${encodeURIComponent(docId)}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  return res.ok;
}

async function writeAutoRejectedAttendanceRecord({
  accessToken,
  projectId,
  employeeId,
  employeeName,
  action,
  rejectionReason,
  recordedAtIso,
}: {
  accessToken: string;
  projectId: string;
  employeeId: string;
  employeeName: string;
  action: "present" | "left";
  rejectionReason: "missed_check_in_window" | "missed_check_out_window";
  recordedAtIso: string;
}): Promise<void> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/attendance_records`;
  await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      fields: {
        employeeId: { stringValue: employeeId },
        employeeName: { stringValue: employeeName },
        action: { stringValue: action },
        approvalStatus: { stringValue: "auto_rejected_late" },
        rejectionReason: { stringValue: rejectionReason },
        markedBy: { stringValue: "system" },
        recordedAt: { timestampValue: recordedAtIso },
        latitude: { doubleValue: 0 },
        longitude: { doubleValue: 0 },
        distanceMeters: { doubleValue: 0 },
        officeLatitude: { doubleValue: 0 },
        officeLongitude: { doubleValue: 0 },
        officeRadiusMeters: { doubleValue: 0 },
        photoUrl: { stringValue: "" },
      },
    }),
  });
}

function windowEndIso(dayKey: string, endMinutes: number): string {
  const hour = Math.floor(endMinutes / 60);
  const minute = endMinutes % 60;
  const hh = String(hour).padStart(2, "0");
  const mm = String(minute).padStart(2, "0");
  return new Date(`${dayKey}T${hh}:${mm}:00.000`).toISOString();
}

const FLEXIBLE_EOD_MINUTES = 23 * 60 + 55;
const CALENDAR_DAY_END_MINUTES = 23 * 60 + 59;
const ATTENDANCE_CLOSING_REMINDER_LEAD_MINUTES = 15;
/** Last hour of the day — remind flexible remote staff before midnight absent. */
const FLEXIBLE_EOD_REMINDER_LEAD_MINUTES = 60;

async function sendAttendanceWindowReminder({
  accessToken,
  projectId,
  fcmUrl,
  employeeId,
  email,
  fcmTokens,
  dayKey,
  dedupeSuffix,
  emailType,
  title,
  body,
  notificationType,
}: {
  accessToken: string;
  projectId: string;
  fcmUrl: string;
  employeeId: string;
  email: string | null;
  fcmTokens: string[];
  dayKey: string;
  dedupeSuffix: string;
  emailType: string;
  title: string;
  body: string;
  notificationType: string;
}): Promise<void> {
  const dedupeId = `${employeeId}_${dayKey}_${dedupeSuffix}`;
  if (await reminderDocExists(accessToken, projectId, dedupeId)) return;
  await sendEmailIfPolicyAllows(emailType, email, title, body);
  await sendFcm({
    accessToken,
    fcmUrl,
    tokens: fcmTokens,
    title,
    body,
    notificationType,
    recipientId: employeeId,
    recipientKind: "employee",
    projectId,
  });
  await markReminderSent(accessToken, projectId, dedupeId);
}

function dayBoundsIso(dayKey: string): { dayStartIso: string; dayEndIso: string } {
  return {
    dayStartIso: new Date(`${dayKey}T00:00:00.000Z`).toISOString(),
    dayEndIso: new Date(`${dayKey}T23:59:59.999Z`).toISOString(),
  };
}

async function fetchAttendanceRecordsForDay({
  accessToken,
  projectId,
  employeeId,
  dayKey,
}: {
  accessToken: string;
  projectId: string;
  employeeId: string;
  dayKey: string;
}) {
  const { dayStartIso, dayEndIso } = dayBoundsIso(dayKey);
  return runQuery({
    accessToken,
    projectId,
    structuredQuery: {
      from: [{ collectionId: "attendance_records" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            { fieldFilter: { field: { fieldPath: "employeeId" }, op: "EQUAL", value: { stringValue: employeeId } } },
            { fieldFilter: { field: { fieldPath: "recordedAt" }, op: "GREATER_THAN_OR_EQUAL", value: { timestampValue: dayStartIso } } },
            { fieldFilter: { field: { fieldPath: "recordedAt" }, op: "LESS_THAN_OR_EQUAL", value: { timestampValue: dayEndIso } } },
          ],
        },
      },
      limit: 50,
    },
  });
}

async function processFlexibleCalendarDayAbsent({
  accessToken,
  projectId,
  fcmUrl,
  employeeId,
  employeeName,
  dayKey,
  records,
  fcmTokens,
}: {
  accessToken: string;
  projectId: string;
  fcmUrl: string;
  employeeId: string;
  employeeName: string;
  dayKey: string;
  records: Array<{ fields: Record<string, unknown> }>;
  fcmTokens: string[];
}): Promise<void> {
  const hasPresentRecord = records.some((r) =>
    getStringField(r.fields, "action") === "present"
  );
  const hasLeftRecord = records.some((r) => getStringField(r.fields, "action") === "left");
  const eodIso = windowEndIso(dayKey, CALENDAR_DAY_END_MINUTES);

  if (!hasPresentRecord) {
    const dedupeId = `${employeeId}_${dayKey}_auto_no_check_in`;
    if (!(await reminderDocExists(accessToken, projectId, dedupeId))) {
      await writeAutoRejectedAttendanceRecord({
        accessToken,
        projectId,
        employeeId,
        employeeName,
        action: "present",
        rejectionReason: "missed_check_in_window",
        recordedAtIso: eodIso,
      });
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: fcmTokens,
        title: "Marked absent",
        body: "Check-in was not recorded by end of day.",
        notificationType: "employee_attendance_auto_absent",
        recipientId: employeeId,
        recipientKind: "employee",
        projectId,
      });
      await markReminderSent(accessToken, projectId, dedupeId);
    }
  }

  if (!hasLeftRecord) {
    const dedupeId = `${employeeId}_${dayKey}_auto_no_checkout`;
    if (!(await reminderDocExists(accessToken, projectId, dedupeId))) {
      await writeAutoRejectedAttendanceRecord({
        accessToken,
        projectId,
        employeeId,
        employeeName,
        action: "left",
        rejectionReason: "missed_check_out_window",
        recordedAtIso: eodIso,
      });
      await sendFcm({
        accessToken,
        fcmUrl,
        tokens: fcmTokens,
        title: "Marked absent",
        body: "Check-out was not recorded by end of day.",
        notificationType: "employee_attendance_auto_absent",
        recipientId: employeeId,
        recipientKind: "employee",
        projectId,
      });
      await markReminderSent(accessToken, projectId, dedupeId);
    }
  }
}

async function writeDayOutcomeAbsent({
  accessToken,
  projectId,
  docId,
  employeeId,
  dateKey,
  reason,
}: {
  accessToken: string;
  projectId: string;
  docId: string;
  employeeId: string;
  dateKey: string;
  reason: "no_check_in" | "no_checkout";
}): Promise<void> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/attendance_day_outcomes?documentId=${encodeURIComponent(docId)}`;
  await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      fields: {
        employeeId: { stringValue: employeeId },
        dateKey: { stringValue: dateKey },
        outcome: { stringValue: "absent" },
        reason: { stringValue: reason },
        markedBy: { stringValue: "system" },
        autoMarkedAt: { timestampValue: new Date().toISOString() },
      },
    }),
  });
}

async function reminderDocExists(accessToken: string, projectId: string, docId: string): Promise<boolean> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/attendance_reminder_sent/${encodeURIComponent(docId)}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  return res.ok;
}

async function markReminderSent(accessToken: string, projectId: string, docId: string): Promise<void> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/attendance_reminder_sent?documentId=${encodeURIComponent(docId)}`;
  await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      fields: {
        sentAt: { timestampValue: new Date().toISOString() },
      },
    }),
  });
}

async function handleAttendanceReminders({
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
  const policy = await loadAttendancePolicy(accessToken, projectId);
  const dayKey = localDateKey(now);
  const { hour: curHour, minute: curMinute } = localHourMinute(now);
  const nowMinutes = curHour * 60 + curMinute;

  for (const e of employees) {
    const id = e.name.split("/").pop() ?? "";
    const role = getStringField(e.fields, "role");
    if (role !== "employee") continue;

    const isRemote = getBooleanField(e.fields, "attendanceRemote");
    const isFlexibleRemote =
      isRemote && getBooleanField(e.fields, "attendanceFlexibleHours");

    const workFrom = getStringField(e.fields, "workHoursFrom");
    const workTo = getStringField(e.fields, "workHoursTo");
    const from = parseHHmm(workFrom);
    const to = parseHHmm(workTo);

    if (isFlexibleRemote) {
      const fcmTokens = extractFcmTokensFromFirestoreFields(e.fields);
      const email = getStringField(e.fields, "email");
      const todayRecords = await fetchAttendanceRecordsForDay({
        accessToken,
        projectId,
        employeeId: id,
        dayKey,
      });
      const employeeName = getStringField(e.fields, "name") ?? id;
      const hasPresentRecord = todayRecords.some((r) =>
        getStringField(r.fields, "action") === "present"
      );
      const hasLeftRecord = todayRecords.some((r) =>
        getStringField(r.fields, "action") === "left"
      );
      const hasValidPresent = todayRecords.some((r) =>
        getStringField(r.fields, "action") === "present" &&
        getStringField(r.fields, "approvalStatus") !== "absent"
      );

      const inFlexibleDayEndReminder =
        nowMinutes >= FLEXIBLE_EOD_MINUTES - FLEXIBLE_EOD_REMINDER_LEAD_MINUTES &&
        nowMinutes < FLEXIBLE_EOD_MINUTES;

      if (inFlexibleDayEndReminder) {
        if (!hasPresentRecord) {
          await sendAttendanceWindowReminder({
            accessToken,
            projectId,
            fcmUrl,
            employeeId: id,
            email,
            fcmTokens,
            dayKey,
            dedupeSuffix: "flex_check_in_eod",
            emailType: "employee_attendance_check_in",
            title: "Check in before end of day",
            body: "You have not checked in today. Please submit Present before the day ends.",
            notificationType: "employee_attendance_check_in",
          });
        } else if (hasValidPresent && !hasLeftRecord) {
          await sendAttendanceWindowReminder({
            accessToken,
            projectId,
            fcmUrl,
            employeeId: id,
            email,
            fcmTokens,
            dayKey,
            dedupeSuffix: "flex_check_out_eod",
            emailType: "employee_attendance_check_out",
            title: "Check out before end of day",
            body: "Please submit Left before the day ends to complete attendance.",
            notificationType: "employee_attendance_check_out",
          });
        }
      }

      if (nowMinutes >= FLEXIBLE_EOD_MINUTES) {
        await processFlexibleCalendarDayAbsent({
          accessToken,
          projectId,
          fcmUrl,
          employeeId: id,
          employeeName,
          dayKey,
          records: todayRecords,
          fcmTokens,
        });
      }

      const yesterdayKey = localDateKey(
        new Date(now.getTime() - 24 * 60 * 60 * 1000),
      );
      if (yesterdayKey !== dayKey) {
        const yesterdayRecords = await fetchAttendanceRecordsForDay({
          accessToken,
          projectId,
          employeeId: id,
          dayKey: yesterdayKey,
        });
        await processFlexibleCalendarDayAbsent({
          accessToken,
          projectId,
          fcmUrl,
          employeeId: id,
          employeeName,
          dayKey: yesterdayKey,
          records: yesterdayRecords,
          fcmTokens,
        });
      }
      continue;
    }

    if (!from || !to) continue;

    const loc = (e.fields.attendanceLocation as any)?.mapValue?.fields;
    if (!isRemote) {
      if (!loc) continue;
      const lat = getDoubleField(loc, "latitude");
      const lng = getDoubleField(loc, "longitude");
      if (lat == null || lng == null || (lat === 0 && lng === 0)) continue;
    }

    const fcmTokens = extractFcmTokensFromFirestoreFields(e.fields);
    const email = getStringField(e.fields, "email");

    const todayRecords = await fetchAttendanceRecordsForDay({
      accessToken,
      projectId,
      employeeId: id,
      dayKey,
    });

    const employeeName = getStringField(e.fields, "name") ?? id;

    const hasPresentRecord = todayRecords.some((r) =>
      getStringField(r.fields, "action") === "present"
    );
    const hasLeftRecord = todayRecords.some((r) => getStringField(r.fields, "action") === "left");
    const hasValidPresent = todayRecords.some((r) =>
      getStringField(r.fields, "action") === "present" &&
      getStringField(r.fields, "approvalStatus") !== "absent"
    );

    const presentWindowEnd = hhmmToMinutes(from) + policy.checkInGraceMinutes;
    const leftWindowEnd = hhmmToMinutes(to) + policy.checkOutGraceMinutes;

    if (nowMinutes > presentWindowEnd && !hasPresentRecord) {
      const dedupeId = `${id}_${dayKey}_auto_no_check_in`;
      if (!(await reminderDocExists(accessToken, projectId, dedupeId))) {
        await writeAutoRejectedAttendanceRecord({
          accessToken,
          projectId,
          employeeId: id,
          employeeName,
          action: "present",
          rejectionReason: "missed_check_in_window",
          recordedAtIso: windowEndIso(dayKey, presentWindowEnd),
        });
        await sendFcm({
          accessToken,
          fcmUrl,
          tokens: fcmTokens,
          title: "Marked absent",
          body: "Check-in was not recorded within the allowed time.",
          notificationType: "employee_attendance_auto_absent",
          recipientId: id,
          recipientKind: "employee",
          projectId,
        });
        await markReminderSent(accessToken, projectId, dedupeId);
      }
    }

    if (nowMinutes > leftWindowEnd && !hasLeftRecord) {
      const dedupeId = `${id}_${dayKey}_auto_no_checkout`;
      if (!(await reminderDocExists(accessToken, projectId, dedupeId))) {
        await writeAutoRejectedAttendanceRecord({
          accessToken,
          projectId,
          employeeId: id,
          employeeName,
          action: "left",
          rejectionReason: "missed_check_out_window",
          recordedAtIso: windowEndIso(dayKey, leftWindowEnd),
        });
        await sendFcm({
          accessToken,
          fcmUrl,
          tokens: fcmTokens,
          title: "Marked absent",
          body: "Check-out was not recorded within the allowed time.",
          notificationType: "employee_attendance_auto_absent",
          recipientId: id,
          recipientKind: "employee",
          projectId,
        });
        await markReminderSent(accessToken, projectId, dedupeId);
      }
    }

    const inCheckInWindow = nowMinutes >= hhmmToMinutes(from) &&
      nowMinutes <= presentWindowEnd;
    if (inCheckInWindow && !hasValidPresent) {
      await sendAttendanceWindowReminder({
        accessToken,
        projectId,
        fcmUrl,
        employeeId: id,
        email,
        fcmTokens,
        dayKey,
        dedupeSuffix: "check_in",
        emailType: "employee_attendance_check_in",
        title: "Time to check in",
        body: "Please check in for work now.",
        notificationType: "employee_attendance_check_in",
      });
    }

    const inCheckInClosing =
      nowMinutes >= presentWindowEnd - ATTENDANCE_CLOSING_REMINDER_LEAD_MINUTES &&
      nowMinutes <= presentWindowEnd;
    if (inCheckInClosing && !hasValidPresent) {
      await sendAttendanceWindowReminder({
        accessToken,
        projectId,
        fcmUrl,
        employeeId: id,
        email,
        fcmTokens,
        dayKey,
        dedupeSuffix: "check_in_closing",
        emailType: "employee_attendance_check_in",
        title: "Check in soon",
        body: "Your check-in window is closing soon.",
        notificationType: "employee_attendance_check_in",
      });
    }

    const inCheckOutWindow = nowMinutes >= hhmmToMinutes(to) &&
      nowMinutes <= leftWindowEnd;
    if (inCheckOutWindow && !hasLeftRecord && hasValidPresent) {
      await sendAttendanceWindowReminder({
        accessToken,
        projectId,
        fcmUrl,
        employeeId: id,
        email,
        fcmTokens,
        dayKey,
        dedupeSuffix: "check_out",
        emailType: "employee_attendance_check_out",
        title: "Time to check out",
        body: "Please record your departure.",
        notificationType: "employee_attendance_check_out",
      });
    }

    const inCheckOutClosing =
      nowMinutes >= leftWindowEnd - ATTENDANCE_CLOSING_REMINDER_LEAD_MINUTES &&
      nowMinutes <= leftWindowEnd;
    if (inCheckOutClosing && !hasLeftRecord && hasValidPresent) {
      await sendAttendanceWindowReminder({
        accessToken,
        projectId,
        fcmUrl,
        employeeId: id,
        email,
        fcmTokens,
        dayKey,
        dedupeSuffix: "check_out_closing",
        emailType: "employee_attendance_check_out",
        title: "Check out soon",
        body: "Your check-out window is closing soon.",
        notificationType: "employee_attendance_check_out",
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
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-cron-secret",
  };
}
