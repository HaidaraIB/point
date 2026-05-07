import "https://deno.land/std@0.177.0/http/server.ts";
import type { ServiceAccountJson } from "../_shared/firebase-edge.ts";
import {
  getServiceAccountForFirebaseProject,
  verifyFirebaseIdToken,
} from "../_shared/firebase-edge.ts";

type PushDiagnosticPayload = {
  requestId: string;
  stage: string;
  status: "ok" | "error";
  senderUid?: string;
  senderEmail?: string;
  recipientId?: string;
  recipientType?: string;
  targetType: "token" | "topic";
  tokenMasked?: string;
  topic?: string;
  title?: string;
  bodyLen?: number;
  notificationType?: string;
  functionVersion: string;
  fcmHttpStatus?: number;
  fcmMessageId?: string;
  fcmErrorCode?: string;
  fcmErrorStatus?: string;
  fcmErrorMessage?: string;
  details?: unknown;
};

// نستخدم scope واسع يغطي كل من Firestore REST و FCM v1.
// هذا يمنع انتقال المشكلة من `401 Invalid JWT` إلى `403` بسبب صلاحيات ناقصة.
const FCM_SCOPE = "https://www.googleapis.com/auth/cloud-platform";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const FUNCTION_VERSION = "send-fcm-v5-batch";

/** Max device targets per HTTP request (stays within typical Edge timeouts). */
const MAX_FCM_BATCH_RECIPIENTS = 100;
/** Parallel FCM HTTP calls inside one batch invocation. */
const FCM_BATCH_CONCURRENCY = 8;

type FcmBatchItemResult = {
  index: number;
  recipientId?: string;
  recipientType?: string;
  tokenMasked: string;
  ok: boolean;
  skipped?: boolean;
  reason?: string;
  requestId: string;
  fcmMessageId?: string;
  fcmHttpStatus?: number;
  fcmErrorCode?: string;
  fcmErrorStatus?: string;
  fcmErrorMessage?: string;
  details?: unknown;
};

async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  fn: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;
  async function worker() {
    while (true) {
      const idx = next++;
      if (idx >= items.length) break;
      results[idx] = await fn(items[idx], idx);
    }
  }
  const n = Math.min(limit, Math.max(1, items.length));
  await Promise.all(Array.from({ length: n }, () => worker()));
  return results;
}

function parseJsonResponse(raw: string): Record<string, unknown> {
  if (!raw) return {};
  try {
    return JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { raw: raw.slice(0, 1400) };
  }
}

async function handleFcmRecipientsBatch(args: {
  accessToken: string;
  sa: ServiceAccountJson;
  caller: { uid: string; email?: string };
  parsed: {
    recipients: Array<{
      token?: string;
      recipientId?: string;
      recipientType?: string;
      data?: Record<string, string>;
      requestId?: string;
    }>;
    title?: string;
    body?: string;
    data?: Record<string, string>;
    requestId?: string;
    notificationType?: string;
    silentDataOnly?: boolean;
  };
}): Promise<Response> {
  const { accessToken, sa, caller, parsed } = args;

  if (parsed.silentDataOnly === true) {
    return json(
      { errorCode: "ERR_INVALID_DATA", details: "batch does not support silentDataOnly", requestId: parsed.requestId },
      400,
    );
  }

  const rec = parsed.recipients ?? [];
  if (rec.length > MAX_FCM_BATCH_RECIPIENTS) {
    return json({
      errorCode: "ERR_INVALID_DATA",
      details: `max ${MAX_FCM_BATCH_RECIPIENTS} recipients`,
      max: MAX_FCM_BATCH_RECIPIENTS,
    }, 400);
  }

  const title = parsed.title ?? "";
  const body = parsed.body ?? "";
  if (!title || !body) {
    return json({ errorCode: "ERR_INVALID_DATA", details: "title and body required" }, 400);
  }

  const notificationType = parsed.notificationType;
  const parentRequestId = (parsed.requestId ?? crypto.randomUUID()).trim();
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  const soundBase = soundBaseForNotificationType(notificationType);

  const processOne = async (
    item: (typeof rec)[number],
    index: number,
  ): Promise<FcmBatchItemResult> => {
    const token = (item.token ?? "").trim();
    const tokenMasked = token ? maskFcmToken(token) : "***";
    const subRequestId = (item.requestId?.trim() || `${parentRequestId}_${index}`).trim();
    const recipientId = item.recipientId;
    const recipientType = item.recipientType;

    if (!token) {
      return {
        index,
        tokenMasked,
        ok: false,
        requestId: subRequestId,
        recipientId,
        recipientType,
        details: { reason: "missing_token" },
      };
    }

    if (
      notificationType?.trim() === "chat_message" &&
      recipientId &&
      typeof recipientId === "string"
    ) {
      const merged = { ...(parsed.data ?? {}), ...(item.data ?? {}) };
      if (merged.chatId) {
        const activeState = await getEmployeeActiveChatState(accessToken, sa.project_id, recipientId);
        const incomingChat = String(merged.chatId).trim();
        if (
          shouldSkipChatPushForActiveSameChat({
            activeChatId: activeState.chatId,
            activeChatUpdatedAtMs: activeState.updatedAtMs,
            incomingChatId: incomingChat,
          })
        ) {
          return {
            index,
            tokenMasked,
            ok: true,
            skipped: true,
            reason: "recipient_active_same_chat",
            requestId: subRequestId,
            recipientId,
            recipientType,
          };
        }
      }
    }

    const dataPayload: Record<string, string> = {
      ...(parsed.data ?? {}),
      ...(item.data ?? {}),
    };
    if (notificationType && notificationType.trim().length > 0) {
      dataPayload.notificationType = notificationType.trim();
    }
    if (soundBase) {
      dataPayload.pushSoundBase = soundBase;
    }
    dataPayload.title = title;
    dataPayload.body = body;
    dataPayload.requestId = subRequestId;

    const fcmMessage = buildFcmV1NotificationMessage({
      token,
      title,
      body,
      dataPayload,
      soundBase,
      webNotificationTag: `point-${subRequestId}`,
    });

    const res = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: fcmMessage,
      }),
    });

    const outRaw = await res.text().catch(() => "");
    const out = parseJsonResponse(outRaw);

    if (!res.ok) {
      const fcmError = (out as { error?: { code?: unknown; status?: unknown; message?: unknown } })?.error;
      await writePushDiagnostic({
        accessToken,
        projectId: sa.project_id,
        payload: {
          requestId: subRequestId,
          stage: "function_result",
          status: "error",
          senderUid: caller.uid,
          senderEmail: caller.email,
          recipientId,
          recipientType,
          targetType: "token",
          tokenMasked,
          title,
          bodyLen: body.length,
          notificationType,
          functionVersion: FUNCTION_VERSION,
          fcmHttpStatus: res.status,
          fcmMessageId: typeof (out as { name?: string })?.name === "string"
            ? (out as { name: string }).name
            : undefined,
          fcmErrorCode: fcmError?.code?.toString(),
          fcmErrorStatus: fcmError?.status?.toString(),
          fcmErrorMessage: fcmError?.message?.toString(),
          details: out,
        },
      });
      return {
        index,
        tokenMasked,
        ok: false,
        requestId: subRequestId,
        recipientId,
        recipientType,
        fcmHttpStatus: res.status,
        fcmErrorCode: fcmError?.code?.toString(),
        fcmErrorStatus: fcmError?.status?.toString(),
        fcmErrorMessage: fcmError?.message?.toString(),
        details: out,
      };
    }

    await writePushDiagnostic({
      accessToken,
      projectId: sa.project_id,
      payload: {
        requestId: subRequestId,
        stage: "function_result",
        status: "ok",
        senderUid: caller.uid,
        senderEmail: caller.email,
        recipientId,
        recipientType,
        targetType: "token",
        tokenMasked,
        title,
        bodyLen: body.length,
        notificationType,
        functionVersion: FUNCTION_VERSION,
        fcmHttpStatus: res.status,
        fcmMessageId: typeof (out as { name?: string })?.name === "string" ? (out as { name: string }).name : undefined,
        details: out,
      },
    });

    return {
      index,
      tokenMasked,
      ok: true,
      requestId: subRequestId,
      recipientId,
      recipientType,
      fcmMessageId: typeof (out as { name?: string })?.name === "string" ? (out as { name: string }).name : undefined,
    };
  };

  const results = await mapWithConcurrency(rec, FCM_BATCH_CONCURRENCY, processOne);

  const sent = results.filter((r) => r.ok && !r.skipped).length;
  const skipped = results.filter((r) => r.skipped === true).length;
  const failed = results.filter((r) => !r.ok).length;

  return json({
    ok: true,
    batch: true,
    functionVersion: FUNCTION_VERSION,
    parentRequestId,
    results,
    summary: { sent, skipped, failed, total: results.length },
  }, 200);
}

function soundBaseForNotificationType(notificationType: string | undefined): string | null {
  if (!notificationType) return null;
  const t = notificationType.trim();
  if (!t) return null;
  const map: Record<string, string> = {
    chat_message: "notification_chat",
    chat_unread_digest: "notification_chat",
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
    admin_supervisor_escalated_task: "notification_task_preview",
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
    // FCM topic broadcast from admin Home (employees / clients / all).
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

function fcmPlatformSoundPayloads(soundBase: string | null): {
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

/** Android TTL + APNs expiration: keep undelivered alerts up to 24h when device offline. */
const FCM_NOTIFICATION_TTL_SEC = 86400;

function apnsExpirationHeaderValue(): string {
  return String(Math.floor(Date.now() / 1000) + FCM_NOTIFICATION_TTL_SEC);
}

/** Android: same `tag` replaces the previous notification in the shade (per-chat merge). */
function androidChatCollapseTagFromData(data: Record<string, string>): string | undefined {
  const t = (data.notificationType ?? "").trim();
  if (t !== "chat_message") return undefined;
  const cid = (data.chatId ?? "").trim();
  if (!cid) return undefined;
  const raw = `point_chat_${cid}`;
  return raw.length <= 64 ? raw : raw.slice(0, 64);
}

/**
 * جذر `notification` يحسّن التسليم على Android/iOS عند إغلاق التطبيق؛ الويب يبقى عبر
 * `webpush.notification` + tag لتقليل الازدواجية.
 */
function buildFcmV1NotificationMessage(args: {
  token?: string;
  topic?: string;
  title: string;
  body: string;
  dataPayload: Record<string, string>;
  soundBase: string | null;
  webNotificationTag: string;
}): Record<string, unknown> {
  const platformSounds = fcmPlatformSoundPayloads(args.soundBase);
  const androidExtra =
    (platformSounds.android?.notification as Record<string, unknown> | undefined) ?? {};
  const apnsBlock = platformSounds.apns as {
    headers?: Record<string, string>;
    payload?: { aps?: Record<string, unknown> };
  };
  const prevAps = { ...(apnsBlock.payload?.aps ?? {}) };
  const tag = args.webNotificationTag.slice(0, 64);
  const apnsHeaders: Record<string, string> = {
    ...(apnsBlock.headers ?? {}),
    "apns-expiration": apnsExpirationHeaderValue(),
  };

  const androidCollapseTag = androidChatCollapseTagFromData(args.dataPayload);
  const iosChatThreadId =
    ((args.dataPayload.chatId ?? "").trim() || undefined);
  /**
   * `chat_message` + `chatId`: Android stays data-only so Flutter can aggregate locally.
   * iOS now uses APNs alert (not background-only) for reliable delivery while still
   * grouping conversation banners using `thread-id` + collapse id.
   */
  const isChatLocalAggregationAndroid = androidCollapseTag !== undefined;
  const androidNotification: Record<string, unknown> = {
    title: args.title,
    body: args.body,
    ...androidExtra,
  };
  if (androidCollapseTag) {
    androidNotification.tag = androidCollapseTag;
  }

  const apnsSection: Record<string, unknown> = isChatLocalAggregationAndroid
    ? {
      headers: {
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": apnsExpirationHeaderValue(),
        ...(iosChatThreadId ? { "apns-collapse-id": androidCollapseTag } : {}),
      },
      payload: {
        aps: {
          ...prevAps,
          alert: {
            title: args.title,
            body: args.body,
          },
          ...(iosChatThreadId ? { "thread-id": iosChatThreadId } : {}),
        },
      },
    }
    : {
      headers: apnsHeaders,
      payload: {
        aps: {
          ...prevAps,
          alert: {
            title: args.title,
            body: args.body,
          },
        },
      },
    };

  const msg: Record<string, unknown> = {
    ...(args.token ? { token: args.token } : {}),
    ...(args.topic ? { topic: args.topic } : {}),
    android: {
      priority: "high",
      ttl: `${FCM_NOTIFICATION_TTL_SEC}s`,
      ...(isChatLocalAggregationAndroid ? {} : { notification: androidNotification }),
    },
    apns: apnsSection,
    webpush: {
      headers: { Urgency: "high" },
      notification: {
        title: args.title,
        body: args.body,
        tag,
      },
    },
  };
  if (!isChatLocalAggregationAndroid) {
    msg.notification = {
      title: args.title,
      body: args.body,
    };
  }
  if (Object.keys(args.dataPayload).length > 0) {
    msg.data = args.dataPayload;
  }
  return msg;
}

/** دفع data-only صامت للمزامنة (بدون تنبيه نظام). يضيف silentSync=1 في data. */
function buildFcmV1SilentDataOnlyMessage(args: {
  token?: string;
  topic?: string;
  dataPayload: Record<string, string>;
}): Record<string, unknown> {
  const data: Record<string, string> = {
    ...args.dataPayload,
    silentSync: "1",
  };
  return {
    ...(args.token ? { token: args.token } : {}),
    ...(args.topic ? { topic: args.topic } : {}),
    data,
    android: { priority: "high" },
    apns: {
      headers: {
        "apns-push-type": "background",
        "apns-priority": "5",
      },
      payload: {
        aps: {
          "content-available": 1,
        },
      },
    },
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200, headers: corsHeaders() });
  if (req.method !== "POST") return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);

  try {
    // Web-safe auth: require a Firebase Auth ID token (no shared secret in client builds).
    // Firebase token passed by the Flutter app (we intentionally keep `authorization`
    // free for Supabase client JWT, if present).
    const firebaseAuthz = req.headers.get("x-firebase-id-token") ?? "";
    const idToken = firebaseAuthz.toLowerCase().startsWith("bearer ")
      ? firebaseAuthz.slice(7).trim()
      : firebaseAuthz.trim();
    if (!idToken) return json({ errorCode: "ERR_MISSING_TOKEN" }, 401);
    const caller = await verifyFirebaseIdToken(idToken);
    const sa = getServiceAccountForFirebaseProject(caller.firebaseProjectId);

    // We already verified the Firebase ID token signature and claims.
    // Do not additionally restrict by Firestore role, because notifications are
    // triggered by multiple app roles (employees/clients/etc).
    const accessToken = await getAccessToken(sa);

    const parsed = await req.json().catch(() => ({})) as {
      token?: string;
      topic?: string;
      title?: string;
      body?: string;
      data?: Record<string, string>;
      requestId?: string;
      recipientId?: string;
      recipientType?: string;
      notificationType?: string;
      silentDataOnly?: boolean;
      recipients?: Array<{
        token?: string;
        recipientId?: string;
        recipientType?: string;
        data?: Record<string, string>;
        requestId?: string;
      }>;
    };

    if (Array.isArray(parsed.recipients) && parsed.recipients.length > 0) {
      if (parsed.token || parsed.topic) {
        return json(
          {
            errorCode: "ERR_INVALID_DATA",
            details: "use either recipients[] or token/topic, not both",
          },
          400,
        );
      }
      return await handleFcmRecipientsBatch({
        accessToken,
        sa,
        caller,
        parsed: {
          recipients: parsed.recipients,
          title: parsed.title,
          body: parsed.body,
          data: parsed.data,
          requestId: parsed.requestId,
          notificationType: parsed.notificationType,
          silentDataOnly: parsed.silentDataOnly,
        },
      });
    }

    const {
      token,
      topic,
      title,
      body,
      data,
      requestId,
      recipientId,
      recipientType,
      notificationType,
      silentDataOnly,
    } = parsed;

    const requestIdSafe = (requestId ?? crypto.randomUUID()).trim();
    await writePushDiagnostic({
      accessToken,
      projectId: sa.project_id,
      payload: {
        requestId: requestIdSafe,
        stage: "function_request",
        status: "ok",
        senderUid: caller.uid,
        senderEmail: caller.email,
        recipientId,
        recipientType,
        targetType: token ? "token" : "topic",
        tokenMasked: token ? maskFcmToken(token) : undefined,
        topic,
        title,
        bodyLen: body?.length ?? 0,
        notificationType,
        functionVersion: FUNCTION_VERSION,
      },
    });

    if ((!token && !topic) || (token && topic)) {
      await writePushDiagnostic({
        accessToken,
        projectId: sa.project_id,
        payload: {
          requestId: requestIdSafe,
          stage: "function_validation",
          status: "error",
          senderUid: caller.uid,
          senderEmail: caller.email,
          recipientId,
          recipientType,
          targetType: token ? "token" : "topic",
          tokenMasked: token ? maskFcmToken(token) : undefined,
          topic,
          title,
          bodyLen: body?.length ?? 0,
          notificationType,
          functionVersion: FUNCTION_VERSION,
          details: { reason: "invalid_target_selection" },
        },
      });
      return json({ errorCode: "ERR_INVALID_DATA", requestId: requestIdSafe }, 400);
    }

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    if (silentDataOnly === true) {
      const raw = data ?? {};
      const keys = Object.keys(raw);
      if (keys.length === 0) {
        return json(
          { errorCode: "ERR_INVALID_DATA", requestId: requestIdSafe, details: "silentDataOnly requires data" },
          400,
        );
      }
      const dataPayload: Record<string, string> = { ...raw };
      if (notificationType && notificationType.trim().length > 0) {
        dataPayload.notificationType = notificationType.trim();
      }
      const fcmSilent = buildFcmV1SilentDataOnlyMessage({
        ...(token ? { token } : {}),
        ...(topic ? { topic } : {}),
        dataPayload,
      });
      const resSilent = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ message: fcmSilent }),
      });
      const outSilentRaw = await resSilent.text().catch(() => "");
      const outSilent = (() => {
        if (!outSilentRaw) return {};
        try {
          return JSON.parse(outSilentRaw);
        } catch (_) {
          return { raw: outSilentRaw.slice(0, 1400) };
        }
      })();
      if (!resSilent.ok) {
        return json({ errorCode: "ERR_SERVER", details: outSilent, requestId: requestIdSafe }, 500);
      }
      return json({ ok: true, result: outSilent, requestId: requestIdSafe, silentDataOnly: true }, 200);
    }

    if (!title || !body) {
      await writePushDiagnostic({
        accessToken,
        projectId: sa.project_id,
        payload: {
          requestId: requestIdSafe,
          stage: "function_validation",
          status: "error",
          senderUid: caller.uid,
          senderEmail: caller.email,
          recipientId,
          recipientType,
          targetType: token ? "token" : "topic",
          tokenMasked: token ? maskFcmToken(token) : undefined,
          topic,
          title,
          bodyLen: body?.length ?? 0,
          notificationType,
          functionVersion: FUNCTION_VERSION,
          details: { reason: "missing_title_or_body" },
        },
      });
      return json({ errorCode: "ERR_INVALID_DATA", requestId: requestIdSafe }, 400);
    }

    if (
      notificationType?.trim() === "chat_message" &&
      recipientId &&
      typeof recipientId === "string" &&
      data?.chatId
    ) {
      const activeState = await getEmployeeActiveChatState(accessToken, sa.project_id, recipientId);
      const incomingChat = String(data.chatId).trim();
      if (
        shouldSkipChatPushForActiveSameChat({
          activeChatId: activeState.chatId,
          activeChatUpdatedAtMs: activeState.updatedAtMs,
          incomingChatId: incomingChat,
        })
      ) {
        return json(
          {
            ok: true,
            skipped: true,
            reason: "recipient_active_same_chat",
            requestId: requestIdSafe,
          },
          200,
        );
      }
    }

    const soundBase = soundBaseForNotificationType(notificationType);
    const dataPayload: Record<string, string> = {
      ...(data ?? {}),
    };
    if (notificationType && notificationType.trim().length > 0) {
      dataPayload.notificationType = notificationType.trim();
    }
    if (soundBase) {
      dataPayload.pushSoundBase = soundBase;
    }
    // للويب: عرض موحّد من Service Worker + tag يمنع ازدواجية لنفس الطلب.
    dataPayload.title = title;
    dataPayload.body = body;
    dataPayload.requestId = requestIdSafe;

    const fcmMessage = buildFcmV1NotificationMessage({
      ...(token ? { token } : {}),
      ...(topic ? { topic } : {}),
      title,
      body,
      dataPayload,
      soundBase,
      webNotificationTag: `point-${requestIdSafe}`,
    });

    const res = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: fcmMessage,
      }),
    });

    const outRaw = await res.text().catch(() => "");
    const out = (() => {
      if (!outRaw) return {};
      try {
        return JSON.parse(outRaw);
      } catch (_) {
        return { raw: outRaw.slice(0, 1400) };
      }
    })();
    if (!res.ok) {
      const fcmError = (out as any)?.error;
      await writePushDiagnostic({
        accessToken,
        projectId: sa.project_id,
        payload: {
          requestId: requestIdSafe,
          stage: "function_result",
          status: "error",
          senderUid: caller.uid,
          senderEmail: caller.email,
          recipientId,
          recipientType,
          targetType: token ? "token" : "topic",
          tokenMasked: token ? maskFcmToken(token) : undefined,
          topic,
          title,
          bodyLen: body.length,
          notificationType,
          functionVersion: FUNCTION_VERSION,
          fcmHttpStatus: res.status,
          fcmMessageId: typeof (out as any)?.name === "string" ? (out as any).name : undefined,
          fcmErrorCode: fcmError?.code?.toString(),
          fcmErrorStatus: fcmError?.status?.toString(),
          fcmErrorMessage: fcmError?.message?.toString(),
          details: out,
        },
      });
      return json({ errorCode: "ERR_SERVER", details: out, requestId: requestIdSafe }, 500);
    }
    await writePushDiagnostic({
      accessToken,
      projectId: sa.project_id,
      payload: {
        requestId: requestIdSafe,
        stage: "function_result",
        status: "ok",
        senderUid: caller.uid,
        senderEmail: caller.email,
        recipientId,
        recipientType,
        targetType: token ? "token" : "topic",
        tokenMasked: token ? maskFcmToken(token) : undefined,
        topic,
        title,
        bodyLen: body.length,
        notificationType,
        functionVersion: FUNCTION_VERSION,
        fcmHttpStatus: res.status,
        fcmMessageId: typeof (out as any)?.name === "string" ? (out as any).name : undefined,
        details: out,
      },
    });
    return json({ ok: true, result: out, requestId: requestIdSafe }, 200);
  } catch (e) {
    return json({ errorCode: "ERR_SERVER", details: String(e) }, 500);
  }
});

/** Skip chat FCM only when the same chat is actively open *and* sync is fresh (avoids stale activeChatId after kill/background). */
const ACTIVE_CHAT_SKIP_MAX_AGE_MS = 3 * 60 * 1000;

async function getEmployeeActiveChatState(
  accessToken: string,
  projectId: string,
  employeeId: string,
): Promise<{ chatId: string | null; updatedAtMs: number | null }> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/employees/${encodeURIComponent(employeeId)}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return { chatId: null, updatedAtMs: null };
  const j = await res.json().catch(() => ({})) as {
    fields?: {
      activeChatId?: { stringValue?: string };
      activeChatUpdatedAt?: { timestampValue?: string; stringValue?: string };
    };
  };
  const chatId = j.fields?.activeChatId?.stringValue;
  const cid = typeof chatId === "string" && chatId.length > 0 ? chatId : null;
  const tsRaw =
    j.fields?.activeChatUpdatedAt?.timestampValue ??
    j.fields?.activeChatUpdatedAt?.stringValue;
  let updatedAtMs: number | null = null;
  if (typeof tsRaw === "string" && tsRaw.length > 0) {
    const n = new Date(tsRaw).getTime();
    updatedAtMs = Number.isNaN(n) ? null : n;
  }
  return { chatId: cid, updatedAtMs };
}

function shouldSkipChatPushForActiveSameChat(args: {
  activeChatId: string | null;
  activeChatUpdatedAtMs: number | null;
  incomingChatId: string;
}): boolean {
  const incoming = args.incomingChatId.trim();
  if (!incoming || !args.activeChatId || args.activeChatId.trim() !== incoming) {
    return false;
  }
  if (args.activeChatUpdatedAtMs == null) {
    return false;
  }
  return Date.now() - args.activeChatUpdatedAtMs < ACTIVE_CHAT_SKIP_MAX_AGE_MS;
}

function maskFcmToken(t: string): string {
  if (t.length <= 12) return "***";
  return `${t.substring(0, 6)}...${t.substring(t.length - 4)}`;
}

async function writePushDiagnostic(args: {
  accessToken: string;
  projectId: string;
  payload: PushDiagnosticPayload;
}): Promise<void> {
  try {
    const url =
      `https://firestore.googleapis.com/v1/projects/${args.projectId}/databases/(default)/documents/push_diagnostics`;
    const p = args.payload;
    const fields: Record<string, unknown> = {
      requestId: { stringValue: p.requestId },
      stage: { stringValue: p.stage },
      status: { stringValue: p.status },
      targetType: { stringValue: p.targetType },
      functionVersion: { stringValue: p.functionVersion },
      createdAt: { timestampValue: new Date().toISOString() },
      bodyLen: { integerValue: String(p.bodyLen ?? 0) },
    };
    if (p.senderUid) fields.senderUid = { stringValue: p.senderUid };
    if (p.senderEmail) fields.senderEmail = { stringValue: p.senderEmail };
    if (p.recipientId) fields.recipientId = { stringValue: p.recipientId };
    if (p.recipientType) fields.recipientType = { stringValue: p.recipientType };
    if (p.tokenMasked) fields.tokenMasked = { stringValue: p.tokenMasked };
    if (p.topic) fields.topic = { stringValue: p.topic };
    if (p.title) fields.title = { stringValue: p.title };
    if (p.notificationType) fields.notificationType = { stringValue: p.notificationType };
    if (typeof p.fcmHttpStatus === "number") {
      fields.fcmHttpStatus = { integerValue: String(p.fcmHttpStatus) };
    }
    if (p.fcmMessageId) fields.fcmMessageId = { stringValue: p.fcmMessageId };
    if (p.fcmErrorCode) fields.fcmErrorCode = { stringValue: p.fcmErrorCode };
    if (p.fcmErrorStatus) fields.fcmErrorStatus = { stringValue: p.fcmErrorStatus };
    if (p.fcmErrorMessage) fields.fcmErrorMessage = { stringValue: p.fcmErrorMessage };
    if (p.details !== undefined) {
      fields.detailsJson = { stringValue: JSON.stringify(p.details).slice(0, 1400) };
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
    // Keep diagnostics non-blocking.
  }
}

async function getAccessToken(sa: ServiceAccountJson): Promise<string> {
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

function corsHeaders() {
  // يجب أن تطابق الترويسات التي يحقنها supabase-dart عبر AuthHttpClient + Constants
  // (apikey، X-Client-Info، منصة الويب…) وإلا يفشل preflight على المتصفح فقط → Failed to fetch.
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-firebase-id-token, x-supabase-client-platform, x-supabase-client-platform-version, x-region",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

async function getEmployeeRole(args: {
  accessToken: string;
  projectId: string;
  uid: string;
  email?: string;
}): Promise<string | null> {
  // 1) Try doc id == uid
  {
    const url =
      `https://firestore.googleapis.com/v1/projects/${args.projectId}/databases/(default)/documents/employees/${encodeURIComponent(args.uid)}`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${args.accessToken}` } });
    if (res.ok) {
      const doc = await res.json() as any;
      const role = doc?.fields?.role?.stringValue;
      if (typeof role === "string") return role;
    }
  }

  // 2) Fallback: query by email field
  if (!args.email) return null;
  const runQueryUrl =
    `https://firestore.googleapis.com/v1/projects/${args.projectId}/databases/(default)/documents:runQuery`;
  const structuredQuery = {
    from: [{ collectionId: "employees" }],
    where: {
      fieldFilter: {
        field: { fieldPath: "email" },
        op: "EQUAL",
        value: { stringValue: args.email },
      },
    },
    limit: 1,
  };
  const res = await fetch(runQueryUrl, {
    method: "POST",
    headers: { Authorization: `Bearer ${args.accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({ structuredQuery }),
  });
  const out = await res.json() as any[];
  const doc = out?.find((r) => r?.document)?.document;
  const role = doc?.fields?.role?.stringValue;
  return typeof role === "string" ? role : null;
}
