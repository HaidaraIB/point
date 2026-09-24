/**
 * Shared checkout session creation for all online payment methods.
 */

import type { OnlinePaymentMethod } from "./card-settings.ts";
import { createAlqasehSession } from "./alqaseh.ts";
import { createPaytabsSession } from "./paytabs.ts";
import { createQicardSession } from "./qicard.ts";
import { createZaincashSession } from "./zaincash.ts";

export type OnlinePaymentSessionResult = {
  provider: OnlinePaymentMethod;
  redirectUrl: string;
  providerRef: string;
};

type SessionFactory = (
  accessToken: string,
  projectId: string,
  invoiceId: string,
  returnBaseUrl?: string,
) => Promise<{ redirectUrl: string; providerRef: string }>;

const SESSION_FACTORIES: Record<OnlinePaymentMethod, SessionFactory> = {
  paytabs: async (accessToken, projectId, invoiceId, returnBaseUrl) => {
    const session = await createPaytabsSession(
      accessToken,
      projectId,
      invoiceId,
      returnBaseUrl,
    );
    return {
      redirectUrl: session.redirectUrl,
      providerRef: session.providerRef,
    };
  },
  alqaseh: async (accessToken, projectId, invoiceId, returnBaseUrl) => {
    const session = await createAlqasehSession(
      accessToken,
      projectId,
      invoiceId,
      returnBaseUrl,
    );
    return {
      redirectUrl: session.redirectUrl,
      providerRef: session.providerRef,
    };
  },
  qicard: async (accessToken, projectId, invoiceId, returnBaseUrl) => {
    const session = await createQicardSession(
      accessToken,
      projectId,
      invoiceId,
      returnBaseUrl,
    );
    return {
      redirectUrl: session.redirectUrl,
      providerRef: session.providerRef,
    };
  },
  zaincash: async (accessToken, projectId, invoiceId, returnBaseUrl) => {
    const session = await createZaincashSession(
      accessToken,
      projectId,
      invoiceId,
      returnBaseUrl,
    );
    return {
      redirectUrl: session.redirectUrl,
      providerRef: session.providerRef,
    };
  },
};

export async function createOnlinePaymentSession(
  method: OnlinePaymentMethod,
  accessToken: string,
  projectId: string,
  invoiceId: string,
  returnBaseUrl?: string,
): Promise<OnlinePaymentSessionResult> {
  const factory = SESSION_FACTORIES[method];
  const session = await factory(
    accessToken,
    projectId,
    invoiceId,
    returnBaseUrl,
  );
  return {
    provider: method,
    redirectUrl: session.redirectUrl,
    providerRef: session.providerRef,
  };
}
