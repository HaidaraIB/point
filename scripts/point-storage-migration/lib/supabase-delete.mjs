import {
  appendFailureLog,
  extractSupabaseObjectKey,
  normalizeSupabaseUrl,
} from "./migration-url-map.mjs";

/**
 * @returns {{ supabaseUrl: string, serviceRoleKey: string, bucket: string }}
 */
export function readSupabaseEnv() {
  const supabaseUrl = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  const bucket = (process.env.SUPABASE_BUCKET ?? "point").trim();
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error(
      "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY (required for --purge)",
    );
  }
  return { supabaseUrl, serviceRoleKey, bucket };
}

/**
 * @param {string[]} objectKeys
 * @param {ReturnType<readSupabaseEnv>} env
 */
async function deleteObjectBatch(objectKeys, env) {
  if (objectKeys.length === 0) return;

  const url = `${env.supabaseUrl}/storage/v1/object/${encodeURIComponent(env.bucket)}`;
  const response = await fetch(url, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${env.serviceRoleKey}`,
      apikey: env.serviceRoleKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ prefixes: objectKeys }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `Supabase delete batch failed: HTTP ${response.status} ${body.slice(0, 300)}`,
    );
  }
}

/**
 * Delete a single object (fallback when batch delete fails).
 * @param {string} objectKey
 * @param {ReturnType<readSupabaseEnv>} env
 */
async function deleteSingleObject(objectKey, env) {
  const encodedKey = objectKey
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
  const url = `${env.supabaseUrl}/storage/v1/object/${encodeURIComponent(env.bucket)}/${encodedKey}`;
  const response = await fetch(url, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${env.serviceRoleKey}`,
      apikey: env.serviceRoleKey,
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `Supabase delete failed: HTTP ${response.status} ${body.slice(0, 300)}`,
    );
  }
}

/**
 * Delete Supabase Storage objects referenced by public URLs.
 * @param {string} projectId
 * @param {string[]} normalizedUrls
 * @param {{ dryRun?: boolean, urlConfig?: object, batchSize?: number }} opts
 */
export async function deleteSupabaseObjectsByUrls(projectId, normalizedUrls, opts = {}) {
  const env = readSupabaseEnv();
  const batchSize = opts.batchSize ?? 100;
  /** @type {Map<string, string>} objectKey -> normalizedUrl (for logging) */
  const keyByUrl = new Map();

  for (const normalized of normalizedUrls) {
    const key = extractSupabaseObjectKey(normalized, opts.urlConfig);
    if (key) keyByUrl.set(key, normalized);
  }

  const objectKeys = [...keyByUrl.keys()];
  console.log(
    `Supabase purge: ${objectKeys.length} unique object key(s) in bucket "${env.bucket}"`,
  );

  if (opts.dryRun) {
    console.log("[dry-run] Skipping Supabase Storage deletes");
    return { deleted: 0, failed: 0, skipped: objectKeys.length };
  }

  let deleted = 0;
  let failed = 0;

  for (let i = 0; i < objectKeys.length; i += batchSize) {
    const batch = objectKeys.slice(i, i + batchSize);
    try {
      await deleteObjectBatch(batch, env);
      deleted += batch.length;
      console.log(`  deleted [${deleted + failed}/${objectKeys.length}] batch of ${batch.length}`);
    } catch (error) {
      console.warn(
        `  batch delete failed, trying one-by-one: ${
          error instanceof Error ? error.message : error
        }`,
      );
      for (const key of batch) {
        try {
          await deleteSingleObject(key, env);
          deleted += 1;
          console.log(`  deleted [${deleted + failed}/${objectKeys.length}] ${key}`);
        } catch (singleError) {
          failed += 1;
          appendFailureLog(projectId, {
            phase: "supabase-delete",
            objectKey: key,
            url: keyByUrl.get(key) ?? "",
            error: singleError instanceof Error ? singleError.message : String(singleError),
          });
          console.error(
            `  failed [${deleted + failed}/${objectKeys.length}] ${key}: ${
              singleError instanceof Error ? singleError.message : singleError
            }`,
          );
        }
      }
    }
  }

  return { deleted, failed, skipped: 0 };
}

/**
 * @param {string} normalizedUrl
 * @param {object} [urlConfig]
 */
export function objectKeyFromNormalizedUrl(normalizedUrl, urlConfig = {}) {
  return extractSupabaseObjectKey(normalizeSupabaseUrl(normalizedUrl), urlConfig);
}
