/**
 * Matches Dart [FirestoreFcmApi._extractFcmTokens]: merges `fcmToken` + `fcmTokens[]`.
 */
export function extractFcmTokensFromFirestoreFields(
  fields: Record<string, unknown>,
): string[] {
  const out = new Set<string>();
  const single = getStringField(fields, "fcmToken")?.trim() ?? "";
  if (single) out.add(single);
  const arr = (fields["fcmTokens"] as { arrayValue?: { values?: unknown[] } } | undefined)
    ?.arrayValue?.values;
  if (Array.isArray(arr)) {
    for (const item of arr) {
      const s = (item as { stringValue?: string })?.stringValue;
      if (typeof s === "string" && s.trim()) out.add(s.trim());
    }
  }
  return [...out];
}

function getStringField(fields: Record<string, unknown>, key: string): string | null {
  const v = (fields[key] as { stringValue?: string } | undefined)?.stringValue;
  return typeof v === "string" ? v : null;
}

export function maskFcmToken(t: string): string {
  if (t.length <= 12) return "***";
  return `${t.substring(0, 6)}...${t.substring(t.length - 4)}`;
}

export function fcmPayloadImpliesInvalidToken(details: unknown): boolean {
  const s = JSON.stringify(details).toLowerCase();
  return (
    s.includes("unregistered") ||
    s.includes("registration-token-not-registered") ||
    s.includes("invalid-registration-token") ||
    s.includes("invalid_argument") ||
    s.includes("not registered") ||
    s.includes("token-not-registered")
  );
}
