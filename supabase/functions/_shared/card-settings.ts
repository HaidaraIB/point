/**
 * Active card payment provider settings (PayTabs / Alqaseh / none).
 */

import type { CardProvider } from "./card-settlement.ts";
import {
  firestoreBool,
  firestoreString,
  getFirestoreDoc,
  setFirestoreDoc,
  toFirestoreBool,
  toFirestoreString,
} from "./firestore-rest.ts";

export const OS_SETTINGS_DOC = "os_settings/default";

export type ActiveCardProvider = "none" | "paytabs" | "alqaseh";

export function parseActiveCardProvider(value: string): ActiveCardProvider {
  const v = value.trim().toLowerCase();
  if (v === "paytabs" || v === "alqaseh" || v === "none") return v;
  return "none";
}

export async function loadActiveCardProvider(
  accessToken: string,
  projectId: string,
): Promise<ActiveCardProvider> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return "none";

  const explicit = firestoreString(fields, "activeCardProvider");
  if (explicit) return parseActiveCardProvider(explicit);

  // Legacy fallback
  if (firestoreBool(fields, "paytabsEnabled")) return "paytabs";
  return "none";
}

export async function loadCardDefaultBankAccountId(
  accessToken: string,
  projectId: string,
): Promise<string> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return "";

  const shared = firestoreString(fields, "cardDefaultBankAccountId");
  if (shared) return shared;

  return firestoreString(fields, "paytabsDefaultBankAccountId");
}

export type ActiveCardProviderStatus = {
  provider: ActiveCardProvider;
  defaultBankAccountId: string;
};

export async function getActiveCardProviderStatus(
  accessToken: string,
  projectId: string,
): Promise<ActiveCardProviderStatus> {
  const provider = await loadActiveCardProvider(accessToken, projectId);
  const defaultBankAccountId = await loadCardDefaultBankAccountId(
    accessToken,
    projectId,
  );
  return { provider, defaultBankAccountId };
}

async function providerConfiguredForEnvironment(
  accessToken: string,
  projectId: string,
  provider: ActiveCardProvider,
): Promise<boolean> {
  if (provider === "none") return true;
  if (provider === "paytabs") {
    const { getPaytabsSettingsStatus } = await import("./paytabs.ts");
    const status = await getPaytabsSettingsStatus(accessToken, projectId);
    return status.hasServerKey && status.profileId.length > 0;
  }
  if (provider === "alqaseh") {
    const { getAlqasehSettingsStatus } = await import("./alqaseh.ts");
    const status = await getAlqasehSettingsStatus(accessToken, projectId);
    return status.hasClientSecret && status.clientId.length > 0;
  }
  return false;
}

export type SetActiveCardProviderInput = {
  provider: ActiveCardProvider;
  defaultBankAccountId?: string;
};

export async function setActiveCardProvider(
  input: SetActiveCardProviderInput,
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<ActiveCardProviderStatus> {
  const provider = parseActiveCardProvider(input.provider);
  const existingBank = await loadCardDefaultBankAccountId(
    accessToken,
    projectId,
  );
  const defaultBankAccountId = (
    input.defaultBankAccountId ?? existingBank
  ).trim();

  if (provider !== "none") {
    if (!defaultBankAccountId) {
      throw new Error("ERR_CARD_BANK_ACCOUNT_REQUIRED");
    }
    const configured = await providerConfiguredForEnvironment(
      accessToken,
      projectId,
      provider,
    );
    if (!configured) {
      if (provider === "paytabs") throw new Error("ERR_PAYTABS_NOT_CONFIGURED");
      if (provider === "alqaseh") throw new Error("ERR_ALQASEH_NOT_CONFIGURED");
    }
  }

  const now = new Date().toISOString();
  await setFirestoreDoc(
    accessToken,
    projectId,
    OS_SETTINGS_DOC,
    {
      activeCardProvider: toFirestoreString(provider),
      cardDefaultBankAccountId: toFirestoreString(defaultBankAccountId),
      paytabsEnabled: toFirestoreBool(provider === "paytabs"),
      cardProviderUpdatedAt: toFirestoreString(now),
      cardProviderUpdatedBy: toFirestoreString(uid),
    },
    [
      "activeCardProvider",
      "cardDefaultBankAccountId",
      "paytabsEnabled",
      "cardProviderUpdatedAt",
      "cardProviderUpdatedBy",
    ],
  );

  return await getActiveCardProviderStatus(accessToken, projectId);
}

export async function resolveSettlementBankAccountId(
  accessToken: string,
  projectId: string,
  provider: CardProvider,
): Promise<string> {
  const shared = await loadCardDefaultBankAccountId(accessToken, projectId);
  if (shared) return shared;

  if (provider === "paytabs") {
    const { loadPaytabsSettings } = await import("./paytabs.ts");
    const settings = await loadPaytabsSettings(accessToken, projectId);
    return settings?.defaultBankAccountId ?? "";
  }
  if (provider === "alqaseh") {
    const { loadAlqasehSettings } = await import("./alqaseh.ts");
    const settings = await loadAlqasehSettings(accessToken, projectId);
    return settings?.defaultBankAccountId ?? "";
  }
  return "";
}
