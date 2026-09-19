import { firestoreString, getFirestoreDoc } from "./firestore-rest.ts";

function firestoreOsModuleAccess(fields: Record<string, unknown>): string[] {
  const v = fields.osModuleAccess as
    | { arrayValue?: { values?: Array<{ stringValue?: string }> } }
    | undefined;
  const values = v?.arrayValue?.values ?? [];
  return values
    .map((item) => item.stringValue?.trim() ?? "")
    .filter((s) => s.length > 0);
}

/** OS settings and secrets remain admin-only. */
export async function assertOsAdmin(
  saAccessToken: string,
  projectId: string,
  uid: string,
): Promise<void> {
  const authFields = await getFirestoreDoc(saAccessToken, projectId, `authRoles/${uid}`);
  if (!authFields) throw new Error("Forbidden");

  const authRole = firestoreString(authFields, "role").toLowerCase();
  if (authRole === "admin") return;

  throw new Error("Forbidden");
}

/** Admin or supervisor with optional Point OS module access (matches Flutter OsPermissions). */
export async function assertOsAccess(
  saAccessToken: string,
  projectId: string,
  uid: string,
  moduleId?: string,
): Promise<void> {
  const authFields = await getFirestoreDoc(saAccessToken, projectId, `authRoles/${uid}`);
  if (!authFields) throw new Error("Forbidden");

  const authRole = firestoreString(authFields, "role").toLowerCase();
  if (authRole === "admin") return;
  if (authRole !== "supervisor") throw new Error("Forbidden");

  const modules = firestoreOsModuleAccess(authFields);
  if (!moduleId) {
    if (modules.length > 0) return;
    throw new Error("Forbidden");
  }
  if (modules.includes(moduleId)) return;

  throw new Error("Forbidden");
}
