/**
 * Active card payment provider settings (PayTabs / Alqaseh / none) and wallet toggles.
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

export type OnlinePaymentMethod = "paytabs" | "alqaseh" | "qicard" | "zaincash";

export const WALLET_METHODS = ["qicard", "zaincash"] as const;
export type WalletPaymentMethod = (typeof WALLET_METHODS)[number];

export type WalletToggleStatus = {
  enabled: boolean;
  bankAccountId: string;
  configured: boolean;
};

export function parseActiveCardProvider(value: string): ActiveCardProvider {
  const v = value.trim().toLowerCase();
  if (v === "paytabs" || v === "alqaseh" || v === "none") return v;
  return "none";
}

export function parseWalletMethod(value: string): WalletPaymentMethod | null {
  const v = value.trim().toLowerCase();
  if (v === "qicard" || v === "zaincash") return v;
  return null;
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

export async function loadWalletBankAccountId(
  accessToken: string,
  projectId: string,
  method: WalletPaymentMethod,
): Promise<string> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return "";
  return firestoreString(fields, `${method}BankAccountId`);
}

export async function loadQicardBankAccountId(
  accessToken: string,
  projectId: string,
): Promise<string> {
  return await loadWalletBankAccountId(accessToken, projectId, "qicard");
}

export async function loadZaincashBankAccountId(
  accessToken: string,
  projectId: string,
): Promise<string> {
  return await loadWalletBankAccountId(accessToken, projectId, "zaincash");
}

export async function isWalletEnabledFlag(
  accessToken: string,
  projectId: string,
  method: WalletPaymentMethod,
): Promise<boolean> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return false;
  return firestoreBool(fields, `${method}Enabled`);
}

export async function isQicardEnabledFlag(
  accessToken: string,
  projectId: string,
): Promise<boolean> {
  return await isWalletEnabledFlag(accessToken, projectId, "qicard");
}

export async function isZaincashEnabledFlag(
  accessToken: string,
  projectId: string,
): Promise<boolean> {
  return await isWalletEnabledFlag(accessToken, projectId, "zaincash");
}

async function isWalletConfigured(
  accessToken: string,
  projectId: string,
  method: WalletPaymentMethod,
): Promise<boolean> {
  if (method === "qicard") {
    const { getQicardSettingsStatus } = await import("./qicard.ts");
    const status = await getQicardSettingsStatus(accessToken, projectId);
    return status.configuredInFirestore;
  }
  const { getZaincashSettingsStatus } = await import("./zaincash.ts");
  const status = await getZaincashSettingsStatus(accessToken, projectId);
  return status.configuredInFirestore;
}

export async function isQicardConfigured(
  accessToken: string,
  projectId: string,
): Promise<boolean> {
  return await isWalletConfigured(accessToken, projectId, "qicard");
}

export async function isZaincashConfigured(
  accessToken: string,
  projectId: string,
): Promise<boolean> {
  return await isWalletConfigured(accessToken, projectId, "zaincash");
}

export async function isWalletEnabled(
  accessToken: string,
  projectId: string,
  method: WalletPaymentMethod,
): Promise<boolean> {
  if (!(await isWalletEnabledFlag(accessToken, projectId, method))) return false;
  return await isWalletConfigured(accessToken, projectId, method);
}

export async function isQicardEnabled(
  accessToken: string,
  projectId: string,
): Promise<boolean> {
  return await isWalletEnabled(accessToken, projectId, "qicard");
}

export async function isZaincashEnabled(
  accessToken: string,
  projectId: string,
): Promise<boolean> {
  return await isWalletEnabled(accessToken, projectId, "zaincash");
}

export type ActiveCardProviderStatus = {
  provider: ActiveCardProvider;
  defaultBankAccountId: string;
};

/** @deprecated Use WalletToggleStatus */
export type QicardToggleStatus = WalletToggleStatus;

export type PaymentMethodsStatus = ActiveCardProviderStatus & {
  qicard: WalletToggleStatus;
  zaincash: WalletToggleStatus;
  enabledMethods: OnlinePaymentMethod[];
};

async function walletToggleStatus(
  accessToken: string,
  projectId: string,
  method: WalletPaymentMethod,
): Promise<WalletToggleStatus> {
  const bankAccountId = await loadWalletBankAccountId(
    accessToken,
    projectId,
    method,
  );
  const configured = await isWalletConfigured(accessToken, projectId, method);
  const enabledFlag = await isWalletEnabledFlag(accessToken, projectId, method);
  return {
    enabled: enabledFlag,
    bankAccountId,
    configured,
  };
}

export async function listEnabledPaymentMethods(
  accessToken: string,
  projectId: string,
): Promise<OnlinePaymentMethod[]> {
  const methods: OnlinePaymentMethod[] = [];
  const active = await loadActiveCardProvider(accessToken, projectId);

  if (active === "paytabs") {
    const configured = await providerConfiguredForEnvironment(
      accessToken,
      projectId,
      "paytabs",
    );
    if (configured) methods.push("paytabs");
  }
  if (active === "alqaseh") {
    const configured = await providerConfiguredForEnvironment(
      accessToken,
      projectId,
      "alqaseh",
    );
    if (configured) methods.push("alqaseh");
  }
  for (const wallet of WALLET_METHODS) {
    if (await isWalletEnabled(accessToken, projectId, wallet)) {
      methods.push(wallet);
    }
  }
  return methods;
}

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

export async function getPaymentMethodsStatus(
  accessToken: string,
  projectId: string,
): Promise<PaymentMethodsStatus> {
  const base = await getActiveCardProviderStatus(accessToken, projectId);
  const enabledMethods = await listEnabledPaymentMethods(
    accessToken,
    projectId,
  );

  return {
    ...base,
    qicard: await walletToggleStatus(accessToken, projectId, "qicard"),
    zaincash: await walletToggleStatus(accessToken, projectId, "zaincash"),
    enabledMethods,
  };
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
): Promise<PaymentMethodsStatus> {
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

  return await getPaymentMethodsStatus(accessToken, projectId);
}

export type SetWalletEnabledInput = {
  enabled: boolean;
  bankAccountId?: string;
};

function walletBankRequiredError(method: WalletPaymentMethod): string {
  if (method === "qicard") return "ERR_QICARD_BANK_ACCOUNT_REQUIRED";
  return "ERR_ZAINCASH_BANK_ACCOUNT_REQUIRED";
}

function walletNotConfiguredError(method: WalletPaymentMethod): string {
  if (method === "qicard") return "ERR_QICARD_NOT_CONFIGURED";
  return "ERR_ZAINCASH_NOT_CONFIGURED";
}

export async function setWalletEnabled(
  method: WalletPaymentMethod,
  input: SetWalletEnabledInput,
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<PaymentMethodsStatus> {
  const enabled = input.enabled === true;
  const existingBank = await loadWalletBankAccountId(
    accessToken,
    projectId,
    method,
  );
  const bankAccountId = (input.bankAccountId ?? existingBank).trim();

  if (enabled) {
    if (!bankAccountId) {
      throw new Error(walletBankRequiredError(method));
    }
    const configured = await isWalletConfigured(accessToken, projectId, method);
    if (!configured) throw new Error(walletNotConfiguredError(method));
  }

  const now = new Date().toISOString();
  await setFirestoreDoc(
    accessToken,
    projectId,
    OS_SETTINGS_DOC,
    {
      [`${method}Enabled`]: toFirestoreBool(enabled),
      [`${method}BankAccountId`]: toFirestoreString(bankAccountId),
      [`${method}UpdatedAt`]: toFirestoreString(now),
      [`${method}UpdatedBy`]: toFirestoreString(uid),
    },
    [
      `${method}Enabled`,
      `${method}BankAccountId`,
      `${method}UpdatedAt`,
      `${method}UpdatedBy`,
    ],
  );

  return await getPaymentMethodsStatus(accessToken, projectId);
}

export type SetQicardEnabledInput = SetWalletEnabledInput;

export async function setQicardEnabled(
  input: SetQicardEnabledInput,
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<PaymentMethodsStatus> {
  return await setWalletEnabled("qicard", input, accessToken, projectId, uid);
}

export async function resolveSettlementBankAccountId(
  accessToken: string,
  projectId: string,
  provider: CardProvider,
): Promise<string> {
  if (provider === "qicard" || provider === "zaincash") {
    const walletBank = await loadWalletBankAccountId(
      accessToken,
      projectId,
      provider,
    );
    if (walletBank) return walletBank;
  }

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
