import {
  isSupabaseStorageUrl,
  normalizeSupabaseUrl,
} from "./migration-url-map.mjs";

/**
 * @typedef {'string' | 'array' | 'nested'} FieldType
 * @typedef {{ path: string, type: FieldType, parent?: string, child?: string }} FieldSpec
 * @typedef {{ collection: string, fields: FieldSpec[], subcollection?: string }} CollectionSpec
 */

/** @type {CollectionSpec[]} */
export const TOP_LEVEL_COLLECTIONS = [
  {
    collection: "tasks",
    fields: [
      { path: "files", type: "array" },
      { path: "finalDeliverableFileUrls", type: "array" },
      { path: "managementEditRequestFileUrls", type: "array" },
      { path: "rejectionFileUrls", type: "array" },
      { path: "assignedImageUrl", type: "string" },
      {
        path: "promotionModel.attachementurl",
        type: "nested",
        parent: "promotionModel",
        child: "attachementurl",
      },
      {
        path: "monatageModel.attachementurl",
        type: "nested",
        parent: "monatageModel",
        child: "attachementurl",
      },
      {
        path: "publishModel.contenturl",
        type: "nested",
        parent: "publishModel",
        child: "contenturl",
      },
      {
        path: "publishModel.fileurl",
        type: "nested",
        parent: "publishModel",
        child: "fileurl",
      },
      {
        path: "programmingModel.contenturl",
        type: "nested",
        parent: "programmingModel",
        child: "contenturl",
      },
      {
        path: "programmingModel.fileurl",
        type: "nested",
        parent: "programmingModel",
        child: "fileurl",
      },
    ],
  },
  {
    collection: "contents",
    fields: [
      { path: "files", type: "array" },
      { path: "postAttachments", type: "array" },
      { path: "storyAttachments", type: "array" },
      { path: "reelAttachments", type: "array" },
      { path: "clientEdits", type: "array" },
    ],
  },
  {
    collection: "employees",
    fields: [{ path: "image", type: "string" }],
  },
  {
    collection: "clients",
    fields: [{ path: "image", type: "string" }],
  },
  {
    collection: "attendance_records",
    fields: [{ path: "photoUrl", type: "string" }],
  },
  {
    collection: "meta_posts",
    fields: [{ path: "mediaUrl", type: "string" }],
  },
];

/** @type {FieldSpec[]} */
export const CHAT_MESSAGE_FIELDS = [
  { path: "attachmentUrl", type: "string" },
  { path: "replyImageUrl", type: "string" },
  { path: "replyVideoUrl", type: "string" },
];

/**
 * @param {string} value
 * @param {object} [urlConfig]
 * @returns {{ rawUrl: string, normalizedUrl: string } | null}
 */
export function matchSupabaseUrl(value, urlConfig = {}) {
  if (typeof value !== "string" || !value.trim()) return null;
  const rawUrl = value.trim();
  if (!isSupabaseStorageUrl(rawUrl, urlConfig)) return null;
  return { rawUrl, normalizedUrl: normalizeSupabaseUrl(rawUrl) };
}

/**
 * @param {string} docPath
 * @param {Record<string, unknown>} data
 * @param {FieldSpec[]} fields
 * @param {object} [urlConfig]
 * @returns {Array<{ docPath: string, fieldPath: string, rawUrl: string, normalizedUrl: string }>}
 */
export function scanDocumentFields(docPath, data, fields, urlConfig = {}) {
  /** @type {Array<{ docPath: string, fieldPath: string, rawUrl: string, normalizedUrl: string }>} */
  const hits = [];

  for (const field of fields) {
    if (field.type === "string") {
      const match = matchSupabaseUrl(data[field.path], urlConfig);
      if (match) {
        hits.push({
          docPath,
          fieldPath: field.path,
          rawUrl: match.rawUrl,
          normalizedUrl: match.normalizedUrl,
        });
      }
      continue;
    }

    if (field.type === "array") {
      const arr = data[field.path];
      if (!Array.isArray(arr)) continue;
      arr.forEach((item, index) => {
        const match = matchSupabaseUrl(item, urlConfig);
        if (match) {
          hits.push({
            docPath,
            fieldPath: `${field.path}[${index}]`,
            rawUrl: match.rawUrl,
            normalizedUrl: match.normalizedUrl,
          });
        }
      });
      continue;
    }

    if (field.type === "nested" && field.parent && field.child) {
      const parent = data[field.parent];
      if (!parent || typeof parent !== "object" || Array.isArray(parent)) continue;
      const match = matchSupabaseUrl(/** @type {Record<string, unknown>} */ (parent)[field.child], urlConfig);
      if (match) {
        hits.push({
          docPath,
          fieldPath: field.path,
          rawUrl: match.rawUrl,
          normalizedUrl: match.normalizedUrl,
        });
      }
    }
  }

  return hits;
}

/**
 * @param {Record<string, unknown>} data
 * @param {FieldSpec[]} fields
 * @param {Record<string, { newUrl: string }>} urlMap
 * @param {object} [urlConfig]
 * @returns {{ updated: Record<string, unknown>, changes: Array<{ fieldPath: string, oldUrl: string, newUrl: string }>, changed: boolean }}
 */
export function rewriteDocumentFields(data, fields, urlMap, urlConfig = {}) {
  /** @type {Record<string, unknown>} */
  const updated = { ...data };
  /** @type {Array<{ fieldPath: string, oldUrl: string, newUrl: string }>} */
  const changes = [];
  let changed = false;

  for (const field of fields) {
    if (field.type === "string") {
      const current = updated[field.path];
      if (typeof current !== "string") continue;
      const match = matchSupabaseUrl(current, urlConfig);
      if (!match) continue;
      const entry = urlMap[match.normalizedUrl];
      if (!entry?.newUrl || entry.newUrl === current) continue;
      updated[field.path] = entry.newUrl;
      changes.push({ fieldPath: field.path, oldUrl: current, newUrl: entry.newUrl });
      changed = true;
      continue;
    }

    if (field.type === "array") {
      const arr = updated[field.path];
      if (!Array.isArray(arr)) continue;
      let arrayChanged = false;
      const next = arr.map((item) => {
        if (typeof item !== "string") return item;
        const match = matchSupabaseUrl(item, urlConfig);
        if (!match) return item;
        const entry = urlMap[match.normalizedUrl];
        if (!entry?.newUrl || entry.newUrl === item) return item;
        arrayChanged = true;
        changes.push({ fieldPath: field.path, oldUrl: item, newUrl: entry.newUrl });
        return entry.newUrl;
      });
      if (arrayChanged) {
        updated[field.path] = next;
        changed = true;
      }
      continue;
    }

    if (field.type === "nested" && field.parent && field.child) {
      const parent = updated[field.parent];
      if (!parent || typeof parent !== "object" || Array.isArray(parent)) continue;
      const parentObj = /** @type {Record<string, unknown>} */ ({ ...parent });
      const current = parentObj[field.child];
      if (typeof current !== "string") continue;
      const match = matchSupabaseUrl(current, urlConfig);
      if (!match) continue;
      const entry = urlMap[match.normalizedUrl];
      if (!entry?.newUrl || entry.newUrl === current) continue;
      parentObj[field.child] = entry.newUrl;
      updated[field.parent] = parentObj;
      changes.push({ fieldPath: field.path, oldUrl: current, newUrl: entry.newUrl });
      changed = true;
    }
  }

  return { updated, changes, changed };
}

/**
 * Remove Supabase Storage URL values from document fields (empty string / filter arrays).
 * @param {Record<string, unknown>} data
 * @param {FieldSpec[]} fields
 * @param {object} [urlConfig]
 * @returns {{ updated: Record<string, unknown>, changes: Array<{ fieldPath: string, oldUrl: string }>, changed: boolean }}
 */
export function purgeDocumentFields(data, fields, urlConfig = {}) {
  /** @type {Record<string, unknown>} */
  const updated = { ...data };
  /** @type {Array<{ fieldPath: string, oldUrl: string }>} */
  const changes = [];
  let changed = false;

  for (const field of fields) {
    if (field.type === "string") {
      const current = updated[field.path];
      if (typeof current !== "string") continue;
      const match = matchSupabaseUrl(current, urlConfig);
      if (!match) continue;
      updated[field.path] = "";
      changes.push({ fieldPath: field.path, oldUrl: current });
      changed = true;
      continue;
    }

    if (field.type === "array") {
      const arr = updated[field.path];
      if (!Array.isArray(arr)) continue;
      /** @type {unknown[]} */
      const next = [];
      let arrayChanged = false;
      for (const item of arr) {
        if (typeof item === "string") {
          const match = matchSupabaseUrl(item, urlConfig);
          if (match) {
            arrayChanged = true;
            changes.push({ fieldPath: field.path, oldUrl: item });
            continue;
          }
        }
        next.push(item);
      }
      if (arrayChanged) {
        updated[field.path] = next;
        changed = true;
      }
      continue;
    }

    if (field.type === "nested" && field.parent && field.child) {
      const parent = updated[field.parent];
      if (!parent || typeof parent !== "object" || Array.isArray(parent)) continue;
      const parentObj = /** @type {Record<string, unknown>} */ ({ ...parent });
      const current = parentObj[field.child];
      if (typeof current !== "string") continue;
      const match = matchSupabaseUrl(current, urlConfig);
      if (!match) continue;
      parentObj[field.child] = "";
      updated[field.parent] = parentObj;
      changes.push({ fieldPath: field.path, oldUrl: current });
      changed = true;
    }
  }

  return { updated, changes, changed };
}

/**
 * @param {string | undefined} collectionFilter
 */
export function resolveCollectionsToScan(collectionFilter) {
  if (!collectionFilter) return TOP_LEVEL_COLLECTIONS;
  const filtered = TOP_LEVEL_COLLECTIONS.filter(
    (c) => c.collection === collectionFilter,
  );
  if (filtered.length === 0 && collectionFilter !== "chats") {
    throw new Error(`Unknown collection: ${collectionFilter}`);
  }
  return filtered;
}

/**
 * @param {string | undefined} collectionFilter
 */
export function shouldScanChats(collectionFilter) {
  return !collectionFilter || collectionFilter === "chats";
}
