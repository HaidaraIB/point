import "https://deno.land/std@0.177.0/http/server.ts";

type ServiceAccountJson = {
  project_id: string;
  client_email: string;
  private_key: string;
};

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
const FIREBASE_ID_TOKEN_CERTS_URL =
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";
const FUNCTION_VERSION = "send-fcm-v3-sound";

function soundBaseForNotificationType(notificationType: string | undefined): string | null {
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200, headers: corsHeaders() });
  if (req.method !== "POST") return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);

  try {
    // Web-safe auth: require a Firebase Auth ID token (no shared secret in client builds).
    const sa = getServiceAccount();
    // Firebase token passed by the Flutter app (we intentionally keep `authorization`
    // free for Supabase client JWT, if present).
    const firebaseAuthz = req.headers.get("x-firebase-id-token") ?? "";
    const idToken = firebaseAuthz.toLowerCase().startsWith("bearer ")
      ? firebaseAuthz.slice(7).trim()
      : firebaseAuthz.trim();
    if (!idToken) return json({ errorCode: "ERR_MISSING_TOKEN" }, 401);
    const caller = await verifyFirebaseIdToken(idToken, sa.project_id);

    // We already verified the Firebase ID token signature and claims.
    // Do not additionally restrict by Firestore role, because notifications are
    // triggered by multiple app roles (employees/clients/etc).
    const accessToken = await getAccessToken(sa);
    void caller; // keep variable referenced (useful for future audits/logging)

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
    } = await req.json().catch(() => ({})) as {
      token?: string;
      topic?: string;
      title?: string;
      body?: string;
      data?: Record<string, string>;
      requestId?: string;
      recipientId?: string;
      recipientType?: string;
      notificationType?: string;
    };

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
          bodyLen: body.length,
          notificationType,
          functionVersion: FUNCTION_VERSION,
          details: { reason: "invalid_target_selection" },
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
      const active = await getEmployeeActiveChatId(accessToken, sa.project_id, recipientId);
      const incomingChat = String(data.chatId).trim();
      if (active && active === incomingChat) {
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

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    const soundBase = soundBaseForNotificationType(notificationType);
    const platformSounds = fcmPlatformSoundPayloads(soundBase);
    const dataPayload: Record<string, string> = {
      ...(data ?? {}),
    };
    if (notificationType && notificationType.trim().length > 0) {
      dataPayload.notificationType = notificationType.trim();
    }
    if (soundBase) {
      dataPayload.pushSoundBase = soundBase;
    }

    const fcmMessage = {
      ...(token ? { token } : {}),
      ...(topic ? { topic } : {}),
      notification: { title, body },
      ...platformSounds,
      ...(Object.keys(dataPayload).length > 0 ? { data: dataPayload } : {}),
    };

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

async function getEmployeeActiveChatId(
  accessToken: string,
  projectId: string,
  employeeId: string,
): Promise<string | null> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/employees/${encodeURIComponent(employeeId)}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return null;
  const j = await res.json().catch(() => ({}));
  const v = (j as { fields?: { activeChatId?: { stringValue?: string } } })?.fields?.activeChatId
    ?.stringValue;
  return typeof v === "string" && v.length > 0 ? v : null;
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

function decodeJwtPart(input: string): Record<string, unknown> {
  const pad = "=".repeat((4 - (input.length % 4)) % 4);
  const b64 = (input + pad).replace(/-/g, "+").replace(/_/g, "/");
  const jsonStr = new TextDecoder().decode(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)));
  return JSON.parse(jsonStr) as Record<string, unknown>;
}

async function verifyFirebaseIdToken(idToken: string, projectId: string): Promise<{ uid: string; email?: string }> {
  const parts = idToken.split(".");
  if (parts.length !== 3) throw new Error("Invalid ID token");
  const header = decodeJwtPart(parts[0]);
  const payload = decodeJwtPart(parts[1]);
  const kid = String(header["kid"] ?? "");
  if (!kid) throw new Error("Missing kid");

  const now = Math.floor(Date.now() / 1000);
  const aud = String(payload["aud"] ?? "");
  const iss = String(payload["iss"] ?? "");
  const sub = String(payload["sub"] ?? "");
  const exp = Number(payload["exp"] ?? 0);
  if (!sub) throw new Error("Missing sub");
  if (aud !== projectId) throw new Error("Invalid aud");
  if (iss !== `https://securetoken.google.com/${projectId}`) throw new Error("Invalid iss");
  if (!exp || now >= exp) throw new Error("Token expired");

  const certsRes = await fetch(FIREBASE_ID_TOKEN_CERTS_URL);
  const certs = await certsRes.json() as Record<string, string>;
  const certPem = certs[kid];
  if (!certPem) throw new Error("Unknown kid");

  const dataToVerify = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const sigBytes = base64urlToBytes(parts[2]);
  const key = await importX509(certPem);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, sigBytes, dataToVerify);
  if (!ok) throw new Error("Invalid signature");

  const email = typeof payload["email"] === "string" ? payload["email"] : undefined;
  return { uid: sub, email };
}

function base64urlToBytes(input: string): Uint8Array {
  const pad = "=".repeat((4 - (input.length % 4)) % 4);
  const b64 = (input + pad).replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

async function importX509(pem: string): Promise<CryptoKey> {
  const b64 = pem
    .replace(/-----BEGIN CERTIFICATE-----/g, "")
    .replace(/-----END CERTIFICATE-----/g, "")
    .replace(/\s+/g, "");
  // `crypto.subtle.importKey("spki", ...)` يحتاج DER الخاص بـ SubjectPublicKeyInfo،
  // بينما PEM هنا يحتوي على X509 Certificate كامل (Certificate SEQUENCE).
  // لذلك نستخرج subjectPublicKeyInfo من شهادة X509 ثم نستوردها كـ SPKI.
  const certDer = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const spkiDer = extractSubjectPublicKeyInfoDer(certDer);
  return await crypto.subtle.importKey(
    "spki",
    spkiDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
}

function extractSubjectPublicKeyInfoDer(certDer: Uint8Array): Uint8Array {
  // Minimal DER reader that assumes standard X509 certificate structure:
  // Certificate ::= SEQUENCE { tbsCertificate SEQUENCE, signatureAlgorithm, signatureValue }
  // tbsCertificate ends with: ... subject SEQUENCE, subjectPublicKeyInfo SEQUENCE ...
  const readLength = (der: Uint8Array, offset: number) => {
    const first = der[offset];
    if (first < 0x80) return { len: first, lenBytes: 1 };
    const numBytes = first & 0x7f;
    let len = 0;
    for (let i = 0; i < numBytes; i++) {
      len = (len << 8) | der[offset + 1 + i];
    }
    return { len, lenBytes: 1 + numBytes };
  };

  const readElement = (der: Uint8Array, offset: number) => {
    const tag = der[offset];
    const { len, lenBytes } = readLength(der, offset + 1);
    const headerBytes = 1 + lenBytes;
    const start = offset;
    const end = offset + headerBytes + len;
    return { tag, start, end };
  };

  // Outer Certificate SEQUENCE
  const certSeq = readElement(certDer, 0);
  if (certSeq.tag !== 0x30) {
    throw new Error("Invalid certificate DER (expected SEQUENCE)");
  }

  // Outer SEQUENCE content starts after its header bytes
  const { lenBytes: outerLenBytes } = readLength(certDer, 1);
  const outerContentStart = 1 + outerLenBytes;

  // First element inside outer SEQUENCE is tbsCertificate SEQUENCE
  const tbs = readElement(certDer, outerContentStart);
  if (tbs.tag !== 0x30) throw new Error("Invalid certificate DER (expected tbsCertificate SEQUENCE)");

  // tbsCertificate SEQUENCE content starts after its header
  const { len: tbsLen, lenBytes: tbsLenBytes } = readLength(certDer, tbs.start + 1);
  const tbsHeaderBytes = 1 + tbsLenBytes;
  let tbsOff = tbs.start + tbsHeaderBytes;

  // Optional version: [0] EXPLICIT tag 0xA0
  const firstEl = readElement(certDer, tbsOff);
  if (firstEl.tag === 0xa0) {
    tbsOff = firstEl.end;
  }

  // Skip: serialNumber(INTEGER=0x02), signature(SEQUENCE=0x30), issuer(SEQUENCE=0x30),
  // validity(SEQUENCE=0x30), subject(SEQUENCE=0x30)
  tbsOff = readElement(certDer, tbsOff).end; // serialNumber
  tbsOff = readElement(certDer, tbsOff).end; // signature
  tbsOff = readElement(certDer, tbsOff).end; // issuer
  tbsOff = readElement(certDer, tbsOff).end; // validity
  tbsOff = readElement(certDer, tbsOff).end; // subject

  // Next element must be subjectPublicKeyInfo: SEQUENCE (0x30)
  const spki = readElement(certDer, tbsOff);
  if (spki.tag !== 0x30) throw new Error("Invalid certificate DER (expected subjectPublicKeyInfo SEQUENCE)");

  // Copy bytes to a new Uint8Array so `buffer` starts at offset 0
  return certDer.slice(spki.start, spki.end);
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
