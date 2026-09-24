import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
} from "../_shared/firebase-edge.ts";
import {
  firestoreNumber,
  firestoreString,
  getAccessToken,
  getFirestoreDoc,
} from "../_shared/firestore-rest.ts";
import {
  listEnabledPaymentMethods,
  type OnlinePaymentMethod,
  OS_SETTINGS_DOC,
} from "../_shared/card-settings.ts";
import { createOnlinePaymentSession } from "../_shared/card-checkout.ts";
import { resolveInvoiceByPayLinkToken } from "../_shared/pay-link.ts";
import { amountsMatch } from "../_shared/card-settlement.ts";
import { onlinePaymentMethodLabel, resolveCheckoutMethod } from "../_shared/online-payment-methods.ts";

const throttle = new Map<string, number>();
const THROTTLE_MS = 500;

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  };
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

function throttleKey(projectId: string, token: string): string {
  return `${projectId}:${token}`;
}

function checkThrottle(projectId: string, token: string): boolean {
  const key = throttleKey(projectId, token);
  const now = Date.now();
  const last = throttle.get(key) ?? 0;
  if (now - last < THROTTLE_MS) return false;
  throttle.set(key, now);
  return true;
}

async function resolveCurrency(
  accessToken: string,
  projectId: string,
  methods: OnlinePaymentMethod[],
): Promise<string> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return "IQD";
  if (methods.includes("qicard")) {
    const q = firestoreString(fields, "qicardCurrency");
    if (q) return q;
  }
  if (methods.includes("alqaseh")) {
    const a = firestoreString(fields, "alqasehCurrency");
    if (a) return a;
  }
  const p = firestoreString(fields, "paytabsCurrency") ||
    firestoreString(fields, "paytabsTestCurrency");
  return p || "IQD";
}

async function agencyDisplayName(
  accessToken: string,
  projectId: string,
): Promise<string> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return "Point OS";
  const website = firestoreString(fields, "printWebsite");
  if (website) return website.replace(/^https?:\/\//, "");
  const email = firestoreString(fields, "printEmail");
  if (email) return email.split("@")[0] || "Point OS";
  return "Point OS";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders() });
  }

  const url = new URL(req.url);
  const projectId = (url.searchParams.get("p") ?? "").trim();
  const token = (url.searchParams.get("t") ?? "").trim();

  if (!projectId || !token) {
    return json({ errorCode: "ERR_INVALID_REQUEST" }, 400);
  }

  const allowed = listAllowedFirebaseProjectIds();
  if (!allowed.includes(projectId)) {
    return json({ errorCode: "ERR_FORBIDDEN" }, 403);
  }

  try {
    getServiceAccountForFirebaseProject(projectId);
    const accessToken = await getAccessToken(
      getServiceAccountForFirebaseProject(projectId),
    );

    if (!checkThrottle(projectId, token)) {
      return json({ errorCode: "ERR_RATE_LIMITED" }, 429);
    }

    const resolved = await resolveInvoiceByPayLinkToken(
      accessToken,
      projectId,
      token,
    );
    if (!resolved) {
      return json({ errorCode: "ERR_PAY_LINK_NOT_FOUND" }, 404);
    }

    const { invoiceId, fields } = resolved;
    const status = firestoreString(fields, "status");
    const paid = status === "PAID";
    const total = firestoreNumber(fields, "total");
    const displayNumber = firestoreString(fields, "displayNumber");
    const enabledMethods = await listEnabledPaymentMethods(
      accessToken,
      projectId,
    );
    const currency = await resolveCurrency(
      accessToken,
      projectId,
      enabledMethods,
    );
    const agencyName = await agencyDisplayName(accessToken, projectId);

    const methods = enabledMethods.map((id) => ({
      id,
      label: onlinePaymentMethodLabel(id),
    }));

    if (req.method === "GET") {
      return json({
        agencyName,
        invoiceNumber: displayNumber || undefined,
        amount: total,
        currency,
        paid,
        methods,
      });
    }

    if (req.method !== "POST") {
      return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);
    }

    if (paid) {
      return json({ errorCode: "ERR_INVOICE_ALREADY_PAID" }, 400);
    }
    if (methods.length === 0) {
      return json({ errorCode: "ERR_CARD_PAYMENT_DISABLED" }, 400);
    }

    const body = await req.json().catch(() => ({})) as {
      method?: string;
      returnBaseUrl?: string;
    };
    const method = resolveCheckoutMethod(body.method ?? "", enabledMethods);
    if (!method) {
      return json({ errorCode: "ERR_PAYMENT_METHOD_REQUIRED" }, 400);
    }

    const returnBaseUrl = (body.returnBaseUrl ?? "").trim();
    const existingProvider = firestoreString(fields, "cardProvider");
    const existingUrl = firestoreString(fields, "cardPaymentUrl");
    const existingAmount = firestoreNumber(fields, "cardSessionAmount");

    if (
      existingProvider === method &&
      existingUrl &&
      amountsMatch(existingAmount, total)
    ) {
      return json({ redirectUrl: existingUrl });
    }

    const session = await createOnlinePaymentSession(
      method,
      accessToken,
      projectId,
      invoiceId,
      returnBaseUrl,
    );
    return json({ redirectUrl: session.redirectUrl });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg.startsWith("ERR_")) {
      return json({ errorCode: msg }, 400);
    }
    console.error("pay-link error:", msg);
    return json({ errorCode: "ERR_INTERNAL" }, 500);
  }
});
