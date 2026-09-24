/**
 * Online payment method ids (PayTabs / Alqaseh gateway + local methods).
 */

import type { OnlinePaymentMethod } from "./card-settings.ts";

export function parseOnlinePaymentMethod(
  value: string,
  allowed: OnlinePaymentMethod[],
): OnlinePaymentMethod | null {
  const v = value.trim().toLowerCase();
  if (v === "paytabs" || v === "alqaseh" || v === "qicard" || v === "zaincash") {
    return allowed.includes(v) ? v : null;
  }
  return null;
}

export function resolveCheckoutMethod(
  requested: string,
  enabled: OnlinePaymentMethod[],
): OnlinePaymentMethod | null {
  const parsed = parseOnlinePaymentMethod(requested, enabled);
  if (parsed) return parsed;
  if (enabled.length === 1) return enabled[0];
  return null;
}

export function onlinePaymentMethodLabel(id: OnlinePaymentMethod): string {
  if (id === "paytabs" || id === "alqaseh") return "Visa/Master Card";
  if (id === "zaincash") return "ZainCash";
  return "Qi Card";
}
