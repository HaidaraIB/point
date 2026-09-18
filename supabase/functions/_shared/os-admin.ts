import { firestoreString, getFirestoreDoc } from "./firestore-rest.ts";

/** OS section is admin-only (matches Flutter OsPermissions). */
export async function assertOsAdmin(
  saAccessToken: string,
  projectId: string,
  uid: string,
): Promise<void> {
  const authFields = await getFirestoreDoc(saAccessToken, projectId, `authRoles/${uid}`);
  if (!authFields) throw new Error("Forbidden");

  const authRole = firestoreString(authFields, "role").toLowerCase();
  if (authRole === "admin") return;

  const employeeId = firestoreString(authFields, "employeeId");
  if (!employeeId) throw new Error("Forbidden");

  const employeeFields = await getFirestoreDoc(
    saAccessToken,
    projectId,
    `employees/${employeeId}`,
  );
  if (!employeeFields) throw new Error("Forbidden");

  const employeeRole = firestoreString(employeeFields, "role").toLowerCase();
  if (employeeRole !== "admin") {
    throw new Error("Forbidden");
  }
}
