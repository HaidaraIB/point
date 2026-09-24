/**
 * Shared checkout session creation for all online payment methods.
 */

import type { OnlinePaymentMethod } from "./card-settings.ts";
import { createAlqasehSession } from "./alqaseh.ts";
import { createPaytabsSession } from "./paytabs.ts";
import { createQicardSession } from "./qicard.ts";

export type OnlinePaymentSessionResult = {
  provider: OnlinePaymentMethod;
  redirectUrl: string;
  providerRef: string;
};

export async function createOnlinePaymentSession(
  method: OnlinePaymentMethod,
  accessToken: string,
  projectId: string,
  invoiceId: string,
  returnBaseUrl?: string,
): Promise<OnlinePaymentSessionResult> {
  if (method === "paytabs") {
    const session = await createPaytabsSession(
      accessToken,
      projectId,
      invoiceId,
      returnBaseUrl,
    );
    return {
      provider: "paytabs",
      redirectUrl: session.redirectUrl,
      providerRef: session.providerRef,
    };
  }
  if (method === "alqaseh") {
    const session = await createAlqasehSession(
      accessToken,
      projectId,
      invoiceId,
      returnBaseUrl,
    );
    return {
      provider: "alqaseh",
      redirectUrl: session.redirectUrl,
      providerRef: session.providerRef,
    };
  }
  const session = await createQicardSession(
    accessToken,
    projectId,
    invoiceId,
    returnBaseUrl,
  );
  return {
    provider: "qicard",
    redirectUrl: session.redirectUrl,
    providerRef: session.providerRef,
  };
}
