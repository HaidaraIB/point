#!/usr/bin/env node
/**
 * Point — Supabase Storage → R2 migration (VPS standalone package).
 *
 * Run on a server so Supabase→R2 copy uses datacenter bandwidth, not your home internet.
 *
 *   npm install
 *   cp .env.example .env   # fill in secrets
 *   node migrate.mjs --project point-agency-production --skip-scan --copy --rewrite
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import admin from "firebase-admin";

import {
  CHAT_MESSAGE_FIELDS,
  TOP_LEVEL_COLLECTIONS,
  purgeDocumentFields,
  resolveCollectionsToScan,
  rewriteDocumentFields,
  scanDocumentFields,
  shouldScanChats,
} from "./lib/firestore-url-fields.mjs";
import {
  appendChangeLog,
  appendPurgeLog,
  buildRawUrlByNormalized,
  clearScanProgress,
  getProjectCacheDir,
  loadScanProgress,
  loadUrlMap,
  saveScanProgress,
  saveUrlMap,
  uniqueUrlsFromHits,
  writeScanReport,
} from "./lib/migration-url-map.mjs";
import {
  formatFirestoreQuotaHelp,
  retryFirestore,
  sleep,
} from "./lib/firestore-retry.mjs";
import { copyWithFailureLog, createR2Client, readR2Env } from "./lib/r2-upload.mjs";
import { deleteSupabaseObjectsByUrls } from "./lib/supabase-delete.mjs";

const VALID_PROJECTS = ["point-agency-production", "point-f33cb"];
const BATCH_LIMIT = 500;

/**
 * @typedef {{
 *   project: string,
 *   copy: boolean,
 *   rewrite: boolean,
 *   dryRun: boolean,
 *   limit: number | null,
 *   collection: string | null,
 *   forceRecopy: boolean,
 *   concurrency: number,
 *   pageSize: number,
 *   delayMs: number,
 *   resume: boolean,
 *   skipScan: boolean,
 *   freshScan: boolean,
 *   purge: boolean,
 *   confirmPurge: boolean,
 *   rewriteFromHits: boolean,
 * }} CliOptions
 */

function parseArgs(argv) {
  /** @type {CliOptions} */
  const opts = {
    project: "",
    copy: false,
    rewrite: false,
    dryRun: true,
    limit: null,
    collection: null,
    forceRecopy: false,
    concurrency: 3,
    pageSize: 25,
    delayMs: 300,
    resume: false,
    skipScan: false,
    freshScan: false,
    purge: false,
    confirmPurge: false,
    rewriteFromHits: false,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--copy") {
      opts.copy = true;
      opts.dryRun = false;
    } else if (arg === "--rewrite") {
      opts.rewrite = true;
      opts.dryRun = false;
    } else if (arg === "--dry-run") {
      opts.dryRun = true;
    } else if (arg === "--force-recopy") {
      opts.forceRecopy = true;
    } else if (arg === "--project" && argv[i + 1]) {
      opts.project = argv[++i];
    } else if (arg === "--limit" && argv[i + 1]) {
      opts.limit = Math.max(1, parseInt(argv[++i], 10));
    } else if (arg === "--collection" && argv[i + 1]) {
      opts.collection = argv[++i];
    } else if (arg === "--concurrency" && argv[i + 1]) {
      opts.concurrency = Math.max(1, parseInt(argv[++i], 10));
    } else if (arg === "--page-size" && argv[i + 1]) {
      opts.pageSize = Math.max(1, Math.min(500, parseInt(argv[++i], 10)));
    } else if (arg === "--delay-ms" && argv[i + 1]) {
      opts.delayMs = Math.max(0, parseInt(argv[++i], 10));
    } else if (arg === "--resume") {
      opts.resume = true;
    } else if (arg === "--skip-scan") {
      opts.skipScan = true;
    } else if (arg === "--fresh-scan") {
      opts.freshScan = true;
    } else if (arg === "--purge") {
      opts.purge = true;
    } else if (arg === "--confirm-purge") {
      opts.confirmPurge = true;
    } else if (arg === "--rewrite-from-hits") {
      opts.rewrite = true;
      opts.rewriteFromHits = true;
      opts.skipScan = true;
      opts.dryRun = false;
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      console.error(`Unknown argument: ${arg}`);
      printHelp();
      process.exit(1);
    }
  }

  if (!opts.project) {
    console.error("Missing required --project");
    printHelp();
    process.exit(1);
  }
  if (!VALID_PROJECTS.includes(opts.project)) {
    console.error(
      `Invalid --project ${opts.project}. Expected one of: ${VALID_PROJECTS.join(", ")}`,
    );
    process.exit(1);
  }
  if (!opts.copy && !opts.rewrite && !opts.purge) {
    opts.dryRun = true;
  }
  if (opts.purge && opts.confirmPurge && !argv.includes("--dry-run")) {
    opts.dryRun = false;
  }

  return opts;
}

function printHelp() {
  console.log(`Firestore Supabase → R2 URL migration

Options:
  --project <id>       Required. ${VALID_PROJECTS.join(" | ")}
  --copy               Download from Supabase, upload to R2, update url-map
  --rewrite            Rewrite Firestore fields using url-map (full collection scan)
  --rewrite-from-hits  Rewrite only docs listed in scan-report.json (~minimal reads)
  --dry-run            Scan only (default when --copy/--rewrite omitted)
  --limit <n>          Max documents per top-level collection / chat
  --collection <name>  Restrict scan (e.g. tasks, chats)
  --concurrency <n>    Parallel Supabase→R2 copies (default 3)
  --page-size <n>      Firestore docs per page (default 25)
  --delay-ms <n>       Pause between Firestore pages (default 300)
  --resume             Continue from .migration-cache/ scan-progress.json
  --fresh-scan         Discard saved scan progress before scanning
  --skip-scan          Use existing scan-report.json (for --copy / --rewrite only)
  --purge              Delete Supabase Storage objects and clear URLs in Firestore
  --confirm-purge      Required with --purge to execute deletes (otherwise preview only)
  --force-recopy       Re-upload URLs already present in url-map
`);
}

function loadEnvFile() {
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  for (const name of [".env", ".env.local"]) {
    const envPath = path.join(__dirname, name);
    if (!fs.existsSync(envPath)) continue;
    const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eq = trimmed.indexOf("=");
      if (eq <= 0) continue;
      const key = trimmed.slice(0, eq).trim();
      let value = trimmed.slice(eq + 1).trim();
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      if (!process.env[key]) {
        process.env[key] = value;
      }
    }
  }
}

/**
 * @param {string} projectId
 */
function initFirebase(projectId) {
  if (admin.apps.length > 0) {
    return admin.firestore();
  }

  const jsonRaw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
  if (jsonRaw) {
    const serviceAccount = JSON.parse(jsonRaw);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
    return admin.firestore();
  }

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim()) {
    admin.initializeApp({ projectId });
    return admin.firestore();
  }

  throw new Error(
    "Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON",
  );
}

function getUrlConfig() {
  return {
    supabaseBucket: process.env.SUPABASE_BUCKET ?? "point",
    supabaseStorageBaseUrl: process.env.SUPABASE_STORAGE_BASE_URL ?? "",
  };
}

/**
 * @param {FirebaseFirestore.Query} query
 * @param {string} label
 */
async function runQuery(query, label) {
  return retryFirestore(() => query.get(), { label });
}

/**
 * @param {FirebaseFirestore.WriteBatch} batch
 * @param {string} label
 */
async function commitBatch(batch, label) {
  return retryFirestore(() => batch.commit(), { label });
}

/**
 * @param {CliOptions} opts
 * @param {string} projectId
 */
function initScanProgress(opts, projectId) {
  if (opts.freshScan) {
    clearScanProgress(projectId);
    return { hits: [], byCollection: {}, completedSteps: [] };
  }
  if (opts.resume) {
    return loadScanProgress(projectId);
  }
  return { hits: [], byCollection: {}, completedSteps: [] };
}

/**
 * @param {string} stepKey
 * @param {string[]} completedSteps
 */
function isStepComplete(stepKey, completedSteps) {
  return completedSteps.includes(stepKey);
}

/**
 * @param {CliOptions} opts
 * @param {string} projectId
 * @param {{ hits: unknown[], byCollection: Record<string, number>, completedSteps: string[] }} progress
 */
function persistScanProgress(_opts, projectId, progress) {
  saveScanProgress(projectId, progress);
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {CliOptions} opts
 * @param {object} urlConfig
 */
async function scanFirestore(db, opts, urlConfig) {
  const progress = initScanProgress(opts, opts.project);
  /** @type {Array<{ docPath: string, fieldPath: string, rawUrl: string, normalizedUrl: string }>} */
  const hits = [...progress.hits];
  /** @type {Record<string, number>} */
  const byCollection = { ...progress.byCollection };
  const completedSteps = [...progress.completedSteps];

  const collections = resolveCollectionsToScan(opts.collection ?? undefined);

  try {
    for (const spec of collections) {
      const stepKey = `collection:${spec.collection}`;
      if (isStepComplete(stepKey, completedSteps)) {
        console.log(`Skipping ${spec.collection} (already scanned — use --fresh-scan to rescan)`);
        continue;
      }

      console.log(`Scanning ${spec.collection}…`);
      let scanned = 0;
      /** @type {FirebaseFirestore.QueryDocumentSnapshot | null} */
      let lastDoc = null;

      while (true) {
        if (opts.limit !== null && scanned >= opts.limit) break;

        let query = db
          .collection(spec.collection)
          .orderBy(admin.firestore.FieldPath.documentId());
        if (lastDoc) query = query.startAfter(lastDoc);

        const pageSize =
          opts.limit !== null
            ? Math.min(opts.pageSize, opts.limit - scanned)
            : opts.pageSize;
        if (pageSize <= 0) break;

        const snap = await runQuery(
          query.limit(pageSize),
          `scan ${spec.collection}`,
        );
        if (snap.empty) break;

        for (const doc of snap.docs) {
          scanned += 1;
          const docPath = `${spec.collection}/${doc.id}`;
          const docHits = scanDocumentFields(
            docPath,
            doc.data(),
            spec.fields,
            urlConfig,
          );
          if (docHits.length > 0) {
            byCollection[spec.collection] =
              (byCollection[spec.collection] ?? 0) + docHits.length;
            hits.push(...docHits);
          }
        }

        lastDoc = snap.docs[snap.docs.length - 1];
        persistScanProgress(opts, opts.project, {
          hits,
          byCollection,
          completedSteps,
        });

        if (opts.delayMs > 0) await sleep(opts.delayMs);
        if (snap.size < pageSize) break;
      }

      completedSteps.push(stepKey);
      persistScanProgress(opts, opts.project, { hits, byCollection, completedSteps });
      console.log(`  ${spec.collection}: scanned ${scanned} doc(s), ${byCollection[spec.collection] ?? 0} URL hit(s)`);
    }

    if (shouldScanChats(opts.collection ?? undefined)) {
      const chatsStep = "collection:chats";
      if (!isStepComplete(chatsStep, completedSteps)) {
        console.log("Scanning chats/messages…");
        let chatScanned = 0;
        /** @type {FirebaseFirestore.QueryDocumentSnapshot | null} */
        let lastChat = null;

        while (true) {
          if (opts.limit !== null && chatScanned >= opts.limit) break;

          let chatQuery = db
            .collection("chats")
            .orderBy(admin.firestore.FieldPath.documentId());
          if (lastChat) chatQuery = chatQuery.startAfter(lastChat);

          const pageSize =
            opts.limit !== null
              ? Math.min(Math.max(1, Math.floor(opts.pageSize / 2)), opts.limit - chatScanned)
              : Math.max(1, Math.floor(opts.pageSize / 2));
          if (pageSize <= 0) break;

          const chatSnap = await runQuery(chatQuery.limit(pageSize), "scan chats");
          if (chatSnap.empty) break;

          for (const chatDoc of chatSnap.docs) {
            chatScanned += 1;
            let msgScanned = 0;
            /** @type {FirebaseFirestore.QueryDocumentSnapshot | null} */
            let lastMsg = null;

            while (true) {
              if (opts.limit !== null && msgScanned >= opts.limit) break;

              let msgQuery = chatDoc.ref
                .collection("messages")
                .orderBy(admin.firestore.FieldPath.documentId());
              if (lastMsg) msgQuery = msgQuery.startAfter(lastMsg);

              const msgPageSize =
                opts.limit !== null
                  ? Math.min(opts.pageSize, opts.limit - msgScanned)
                  : opts.pageSize;
              if (msgPageSize <= 0) break;

              const msgSnap = await runQuery(
                msgQuery.limit(msgPageSize),
                `scan chats/${chatDoc.id}/messages`,
              );
              if (msgSnap.empty) break;

              for (const msgDoc of msgSnap.docs) {
                msgScanned += 1;
                const docPath = `chats/${chatDoc.id}/messages/${msgDoc.id}`;
                const docHits = scanDocumentFields(
                  docPath,
                  msgDoc.data(),
                  CHAT_MESSAGE_FIELDS,
                  urlConfig,
                );
                if (docHits.length > 0) {
                  byCollection.chats = (byCollection.chats ?? 0) + docHits.length;
                  hits.push(...docHits);
                }
              }

              lastMsg = msgSnap.docs[msgSnap.docs.length - 1];
              persistScanProgress(opts, opts.project, {
                hits,
                byCollection,
                completedSteps,
              });
              if (opts.delayMs > 0) await sleep(opts.delayMs);
              if (msgSnap.size < msgPageSize) break;
            }
          }

          lastChat = chatSnap.docs[chatSnap.docs.length - 1];
          if (opts.delayMs > 0) await sleep(opts.delayMs);
          if (chatSnap.size < pageSize) break;
        }

        completedSteps.push(chatsStep);
        persistScanProgress(opts, opts.project, { hits, byCollection, completedSteps });
        console.log(`  chats: ${byCollection.chats ?? 0} URL hit(s) in messages`);
      } else {
        console.log("Skipping chats (already scanned — use --fresh-scan to rescan)");
      }
    }

    clearScanProgress(opts.project);
  } catch (error) {
    persistScanProgress(opts, opts.project, { hits, byCollection, completedSteps });
    throw error;
  }

  const uniqueUrls = uniqueUrlsFromHits(hits);
  const rawUrlByNormalized = buildRawUrlByNormalized(hits);
  return { hits, byCollection, uniqueUrls, rawUrlByNormalized };
}

/**
 * @param {string[]} urls
 * @param {Record<string, string>} rawUrlByNormalized
 * @param {CliOptions} opts
 * @param {object} urlConfig
 */
async function copyUrls(urls, rawUrlByNormalized, opts, urlConfig) {
  const urlMap = loadUrlMap(opts.project);
  readR2Env();
  createR2Client(readR2Env());

  /** @type {string[]} */
  const toCopy = [];
  for (const url of urls) {
    if (!opts.forceRecopy && urlMap[url]?.newUrl) continue;
    toCopy.push(url);
  }

  console.log(
    `Copy phase: ${toCopy.length} unique URL(s) to process (${urls.length - toCopy.length} skipped from cache)`,
  );

  if (opts.dryRun) {
    console.log("[dry-run] Skipping Supabase→R2 copies");
    return { copied: 0, failed: 0, urlMap };
  }

  let copied = 0;
  let failed = 0;
  let index = 0;

  async function worker() {
    while (index < toCopy.length) {
      const currentIndex = index;
      index += 1;
      const normalized = toCopy[currentIndex];
      const fetchUrl = rawUrlByNormalized[normalized] ?? normalized;
      try {
        const entry = await copyWithFailureLog(opts.project, fetchUrl, {
          projectId: opts.project,
          forceRecopy: opts.forceRecopy,
          urlConfig,
        });
        urlMap[normalized] = {
          newUrl: entry.newUrl,
          r2Key: entry.r2Key,
          bytes: entry.bytes,
          contentType: entry.contentType,
          copiedAt: entry.copiedAt,
          objectKey: entry.objectKey,
        };
        copied += 1;
        saveUrlMap(opts.project, urlMap);
        console.log(`  copied [${copied + failed}/${toCopy.length}] → ${entry.newUrl}`);
      } catch (error) {
        failed += 1;
        console.error(
          `  failed [${copied + failed}/${toCopy.length}] ${normalized}: ${
            error instanceof Error ? error.message : error
          }`,
        );
      }
    }
  }

  const workers = Array.from(
    { length: Math.min(opts.concurrency, toCopy.length || 1) },
    () => worker(),
  );
  await Promise.all(workers);

  return { copied, failed, urlMap };
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {CliOptions} opts
 * @param {Record<string, { newUrl: string }>} urlMap
 * @param {object} urlConfig
 */
async function rewriteFirestore(db, opts, urlMap, urlConfig) {
  let updatedDocs = 0;
  let totalChanges = 0;

  const collections = resolveCollectionsToScan(opts.collection ?? undefined);

  for (const spec of collections) {
    let scanned = 0;
    let lastDoc = null;
    /** @type {FirebaseFirestore.WriteBatch | null} */
    let batch = null;
    let batchCount = 0;

    async function commitBatchIfNeeded() {
      if (!batch || batchCount === 0) return;
      if (!opts.dryRun) {
        await commitBatch(batch, `rewrite ${spec.collection}`);
      }
      batch = db.batch();
      batchCount = 0;
    }

    batch = db.batch();

    while (true) {
      if (opts.limit !== null && scanned >= opts.limit) break;
      let query = db
        .collection(spec.collection)
        .orderBy(admin.firestore.FieldPath.documentId());
      if (lastDoc) query = query.startAfter(lastDoc);
      const pageSize =
        opts.limit !== null
          ? Math.min(opts.pageSize, opts.limit - scanned)
          : opts.pageSize;
      if (pageSize <= 0) break;
      const snap = await runQuery(
        query.limit(pageSize),
        `rewrite scan ${spec.collection}`,
      );
      if (snap.empty) break;

      for (const doc of snap.docs) {
        scanned += 1;
        const { updated, changes, changed } = rewriteDocumentFields(
          doc.data(),
          spec.fields,
          urlMap,
          urlConfig,
        );
        if (!changed) continue;

        const docPath = `${spec.collection}/${doc.id}`;
        if (!opts.dryRun) {
          batch.update(doc.ref, updated);
          batchCount += 1;
        }
        updatedDocs += 1;
        totalChanges += changes.length;
        for (const change of changes) {
          appendChangeLog(opts.project, {
            docPath,
            fieldPath: change.fieldPath,
            oldUrl: change.oldUrl,
            newUrl: change.newUrl,
            dryRun: opts.dryRun,
          });
        }
        if (batchCount >= BATCH_LIMIT) {
          await commitBatchIfNeeded();
        }
      }

      lastDoc = snap.docs[snap.docs.length - 1];
      if (opts.delayMs > 0) await sleep(opts.delayMs);
      if (snap.size < pageSize) break;
    }

    await commitBatchIfNeeded();
  }

  if (shouldScanChats(opts.collection ?? undefined)) {
    let chatScanned = 0;
    /** @type {FirebaseFirestore.QueryDocumentSnapshot | null} */
    let lastChat = null;
    /** @type {FirebaseFirestore.WriteBatch | null} */
    let batch = db.batch();
    let batchCount = 0;

    async function commitChatBatchIfNeeded() {
      if (batchCount === 0) return;
      if (!opts.dryRun) {
        await commitBatch(batch, "rewrite chats/messages");
      }
      batch = db.batch();
      batchCount = 0;
    }

    while (true) {
      if (opts.limit !== null && chatScanned >= opts.limit) break;
      let chatQuery = db
        .collection("chats")
        .orderBy(admin.firestore.FieldPath.documentId());
      if (lastChat) chatQuery = chatQuery.startAfter(lastChat);
      const pageSize =
        opts.limit !== null
          ? Math.min(Math.max(1, Math.floor(opts.pageSize / 2)), opts.limit - chatScanned)
          : Math.max(1, Math.floor(opts.pageSize / 2));
      if (pageSize <= 0) break;
      const chatSnap = await runQuery(chatQuery.limit(pageSize), "rewrite scan chats");
      if (chatSnap.empty) break;

      for (const chatDoc of chatSnap.docs) {
        chatScanned += 1;
        let msgScanned = 0;
        let lastMsg = null;
        while (true) {
          if (opts.limit !== null && msgScanned >= opts.limit) break;
          let msgQuery = chatDoc.ref
            .collection("messages")
            .orderBy(admin.firestore.FieldPath.documentId());
          if (lastMsg) msgQuery = msgQuery.startAfter(lastMsg);
          const msgPageSize =
            opts.limit !== null
              ? Math.min(opts.pageSize, opts.limit - msgScanned)
              : opts.pageSize;
          if (msgPageSize <= 0) break;
          const msgSnap = await runQuery(
            msgQuery.limit(msgPageSize),
            `rewrite scan chats/${chatDoc.id}/messages`,
          );
          if (msgSnap.empty) break;

          for (const msgDoc of msgSnap.docs) {
            msgScanned += 1;
            const { updated, changes, changed } = rewriteDocumentFields(
              msgDoc.data(),
              CHAT_MESSAGE_FIELDS,
              urlMap,
              urlConfig,
            );
            if (!changed) continue;

            const docPath = `chats/${chatDoc.id}/messages/${msgDoc.id}`;
            if (!opts.dryRun) {
              batch.update(msgDoc.ref, updated);
              batchCount += 1;
            }
            updatedDocs += 1;
            totalChanges += changes.length;
            for (const change of changes) {
              appendChangeLog(opts.project, {
                docPath,
                fieldPath: change.fieldPath,
                oldUrl: change.oldUrl,
                newUrl: change.newUrl,
                dryRun: opts.dryRun,
              });
            }
            if (batchCount >= BATCH_LIMIT) {
              await commitChatBatchIfNeeded();
            }
          }

          lastMsg = msgSnap.docs[msgSnap.docs.length - 1];
          if (opts.delayMs > 0) await sleep(opts.delayMs);
          if (msgSnap.size < msgPageSize) break;
        }
      }

      lastChat = chatSnap.docs[chatSnap.docs.length - 1];
      if (opts.delayMs > 0) await sleep(opts.delayMs);
      if (chatSnap.size < pageSize) break;
    }

    await commitChatBatchIfNeeded();
  }

  return { updatedDocs, totalChanges };
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {CliOptions} opts
 * @param {object} urlConfig
 */
async function purgeFirestore(db, opts, urlConfig) {
  let updatedDocs = 0;
  let totalChanges = 0;
  const collections = resolveCollectionsToScan(opts.collection ?? undefined);

  for (const spec of collections) {
    let scanned = 0;
    /** @type {FirebaseFirestore.QueryDocumentSnapshot | null} */
    let lastDoc = null;
    let batch = db.batch();
    let batchCount = 0;

    async function commitBatchIfNeeded() {
      if (batchCount === 0) return;
      if (!opts.dryRun) {
        await commitBatch(batch, `purge ${spec.collection}`);
      }
      batch = db.batch();
      batchCount = 0;
    }

    while (true) {
      if (opts.limit !== null && scanned >= opts.limit) break;
      let query = db
        .collection(spec.collection)
        .orderBy(admin.firestore.FieldPath.documentId());
      if (lastDoc) query = query.startAfter(lastDoc);
      const pageSize =
        opts.limit !== null
          ? Math.min(opts.pageSize, opts.limit - scanned)
          : opts.pageSize;
      if (pageSize <= 0) break;
      const snap = await runQuery(
        query.limit(pageSize),
        `purge scan ${spec.collection}`,
      );
      if (snap.empty) break;

      for (const doc of snap.docs) {
        scanned += 1;
        const docPath = `${spec.collection}/${doc.id}`;
        const { updated, changes, changed } = purgeDocumentFields(
          doc.data(),
          spec.fields,
          urlConfig,
        );
        if (!changed) continue;

        if (!opts.dryRun) {
          batch.update(doc.ref, updated);
          batchCount += 1;
        }
        updatedDocs += 1;
        totalChanges += changes.length;
        for (const change of changes) {
          appendPurgeLog(opts.project, {
            docPath,
            fieldPath: change.fieldPath,
            oldUrl: change.oldUrl,
            dryRun: opts.dryRun,
          });
        }
        if (batchCount >= BATCH_LIMIT) {
          await commitBatchIfNeeded();
        }
      }

      lastDoc = snap.docs[snap.docs.length - 1];
      if (opts.delayMs > 0) await sleep(opts.delayMs);
      if (snap.size < pageSize) break;
    }

    await commitBatchIfNeeded();
  }

  if (shouldScanChats(opts.collection ?? undefined)) {
    let chatScanned = 0;
    /** @type {FirebaseFirestore.QueryDocumentSnapshot | null} */
    let lastChat = null;
    let batch = db.batch();
    let batchCount = 0;

    async function commitChatBatchIfNeeded() {
      if (batchCount === 0) return;
      if (!opts.dryRun) {
        await commitBatch(batch, "purge chats/messages");
      }
      batch = db.batch();
      batchCount = 0;
    }

    while (true) {
      if (opts.limit !== null && chatScanned >= opts.limit) break;
      let chatQuery = db
        .collection("chats")
        .orderBy(admin.firestore.FieldPath.documentId());
      if (lastChat) chatQuery = chatQuery.startAfter(lastChat);
      const pageSize =
        opts.limit !== null
          ? Math.min(Math.max(1, Math.floor(opts.pageSize / 2)), opts.limit - chatScanned)
          : Math.max(1, Math.floor(opts.pageSize / 2));
      if (pageSize <= 0) break;
      const chatSnap = await runQuery(chatQuery.limit(pageSize), "purge scan chats");
      if (chatSnap.empty) break;

      for (const chatDoc of chatSnap.docs) {
        chatScanned += 1;
        let msgScanned = 0;
        /** @type {FirebaseFirestore.QueryDocumentSnapshot | null} */
        let lastMsg = null;
        while (true) {
          if (opts.limit !== null && msgScanned >= opts.limit) break;
          let msgQuery = chatDoc.ref
            .collection("messages")
            .orderBy(admin.firestore.FieldPath.documentId());
          if (lastMsg) msgQuery = msgQuery.startAfter(lastMsg);
          const msgPageSize =
            opts.limit !== null
              ? Math.min(opts.pageSize, opts.limit - msgScanned)
              : opts.pageSize;
          if (msgPageSize <= 0) break;
          const msgSnap = await runQuery(
            msgQuery.limit(msgPageSize),
            `purge scan chats/${chatDoc.id}/messages`,
          );
          if (msgSnap.empty) break;

          for (const msgDoc of msgSnap.docs) {
            msgScanned += 1;
            const docPath = `chats/${chatDoc.id}/messages/${msgDoc.id}`;
            const { updated, changes, changed } = purgeDocumentFields(
              msgDoc.data(),
              CHAT_MESSAGE_FIELDS,
              urlConfig,
            );
            if (!changed) continue;

            if (!opts.dryRun) {
              batch.update(msgDoc.ref, updated);
              batchCount += 1;
            }
            updatedDocs += 1;
            totalChanges += changes.length;
            for (const change of changes) {
              appendPurgeLog(opts.project, {
                docPath,
                fieldPath: change.fieldPath,
                oldUrl: change.oldUrl,
                dryRun: opts.dryRun,
              });
            }
            if (batchCount >= BATCH_LIMIT) {
              await commitChatBatchIfNeeded();
            }
          }

          lastMsg = msgSnap.docs[msgSnap.docs.length - 1];
          if (opts.delayMs > 0) await sleep(opts.delayMs);
          if (msgSnap.size < msgPageSize) break;
        }
      }

      lastChat = chatSnap.docs[chatSnap.docs.length - 1];
      if (opts.delayMs > 0) await sleep(opts.delayMs);
      if (chatSnap.size < pageSize) break;
    }

    await commitChatBatchIfNeeded();
  }

  return { updatedDocs, totalChanges };
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} docPath
 */
function docRefFromPath(db, docPath) {
  const parts = docPath.split("/");
  if (parts.length === 2) {
    return db.collection(parts[0]).doc(parts[1]);
  }
  if (parts.length === 4 && parts[0] === "chats" && parts[2] === "messages") {
    return db.collection("chats").doc(parts[1]).collection("messages").doc(parts[3]);
  }
  throw new Error(`Unsupported docPath for targeted rewrite: ${docPath}`);
}

/**
 * @param {string} docPath
 */
function fieldsForDocPath(docPath) {
  if (docPath.includes("/messages/")) {
    return CHAT_MESSAGE_FIELDS;
  }
  const collection = docPath.split("/")[0];
  const spec = TOP_LEVEL_COLLECTIONS.find((c) => c.collection === collection);
  if (!spec) {
    throw new Error(`Unknown collection in docPath: ${docPath}`);
  }
  return spec.fields;
}

/**
 * Rewrite only documents that appeared in scan-report hits (1 Firestore read per doc).
 * @param {FirebaseFirestore.Firestore} db
 * @param {CliOptions} opts
 * @param {Record<string, { newUrl: string }>} urlMap
 * @param {object} urlConfig
 * @param {Array<{ docPath: string }>} hits
 */
async function rewriteFirestoreFromHits(db, opts, urlMap, urlConfig, hits) {
  const docPaths = [...new Set(hits.map((h) => h.docPath).filter(Boolean))];
  console.log(`Targeted rewrite: ${docPaths.length} document(s) (${hits.length} URL field hit(s))`);

  let updatedDocs = 0;
  let totalChanges = 0;
  let batch = db.batch();
  let batchCount = 0;

  async function commitBatchIfNeeded() {
    if (batchCount === 0) return;
    if (!opts.dryRun) {
      await commitBatch(batch, "rewrite-from-hits");
    }
    batch = db.batch();
    batchCount = 0;
  }

  for (const docPath of docPaths) {
    const ref = docRefFromPath(db, docPath);
    const snap = await retryFirestore(() => ref.get(), {
      label: `rewrite-from-hits get ${docPath}`,
    });
    if (!snap.exists) {
      console.warn(`  skip missing doc: ${docPath}`);
      continue;
    }

    const fields = fieldsForDocPath(docPath);
    const { updated, changes, changed } = rewriteDocumentFields(
      snap.data(),
      fields,
      urlMap,
      urlConfig,
    );
    if (!changed) continue;

    if (!opts.dryRun) {
      batch.update(ref, updated);
      batchCount += 1;
    }
    updatedDocs += 1;
    totalChanges += changes.length;
    for (const change of changes) {
      appendChangeLog(opts.project, {
        docPath,
        fieldPath: change.fieldPath,
        oldUrl: change.oldUrl,
        newUrl: change.newUrl,
        dryRun: opts.dryRun,
      });
    }
    if (batchCount >= BATCH_LIMIT) {
      await commitBatchIfNeeded();
    }
  }

  await commitBatchIfNeeded();
  return { updatedDocs, totalChanges, docReads: docPaths.length };
}

/**
 * @param {string} projectId
 */
function loadScanFromReport(projectId) {
  const reportPath = path.join(getProjectCacheDir(projectId), "scan-report.json");
  if (!fs.existsSync(reportPath)) {
    throw new Error(
      `No scan-report.json at ${reportPath}. Run a scan first or omit --skip-scan.`,
    );
  }
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  const uniqueUrls = Array.isArray(report.uniqueUrls) ? report.uniqueUrls : [];
  /** @type {Record<string, string>} */
  const rawUrlByNormalized = {};
  if (Array.isArray(report.hits)) {
    for (const hit of report.hits) {
      if (hit?.normalizedUrl && hit?.rawUrl && !rawUrlByNormalized[hit.normalizedUrl]) {
        rawUrlByNormalized[hit.normalizedUrl] = hit.rawUrl;
      }
    }
  }
  return {
    hits: Array.isArray(report.hits) ? report.hits : [],
    byCollection: report.byCollection ?? {},
    uniqueUrls,
    rawUrlByNormalized:
      Object.keys(rawUrlByNormalized).length > 0
        ? rawUrlByNormalized
        : buildRawUrlByNormalized(
            uniqueUrls.map((normalizedUrl) => ({
              normalizedUrl,
              rawUrl: normalizedUrl,
            })),
          ),
  };
}

async function main() {
  loadEnvFile();
  const opts = parseArgs(process.argv);
  const urlConfig = getUrlConfig();
  const mode = opts.purge
    ? opts.dryRun
      ? "purge (preview)"
      : "purge"
    : opts.dryRun && !opts.copy && !opts.rewrite
      ? "scan"
      : [
          opts.copy && "copy",
          opts.rewrite && (opts.rewriteFromHits ? "rewrite-from-hits" : "rewrite"),
        ]
          .filter(Boolean)
          .join("+");

  console.log(`Project: ${opts.project}`);
  console.log(`Mode: ${mode}${opts.dryRun && (opts.copy || opts.rewrite) ? " (dry-run)" : ""}`);
  if (opts.limit) console.log(`Limit: ${opts.limit} docs per collection/chat`);
  if (opts.collection) console.log(`Collection filter: ${opts.collection}`);
  console.log(`Page size: ${opts.pageSize}, delay: ${opts.delayMs}ms`);
  if (opts.resume) console.log("Resume: continuing from saved scan progress");
  if (opts.skipScan) console.log("Skip scan: using scan-report.json");
  if (opts.rewriteFromHits) console.log("Rewrite mode: targeted (scan-report hits only)");
  if (opts.purge && !opts.confirmPurge) {
    console.log("Purge preview only — add --confirm-purge to delete for real");
  }

  const db = initFirebase(opts.project);

  /** @type {{ hits: unknown[], byCollection: Record<string, number>, uniqueUrls: string[], rawUrlByNormalized: Record<string, string> }} */
  let scan;

  if (opts.skipScan) {
    console.log("\n=== Scan (skipped) ===");
    scan = loadScanFromReport(opts.project);
    console.log(`Loaded ${scan.uniqueUrls.length} unique URL(s) from scan-report.json`);
  } else {
    console.log("\n=== Scan ===");
    scan = await scanFirestore(db, opts, urlConfig);
  }

  console.log(`Documents with Supabase URLs: ${scan.hits.length} field hit(s)`);
  console.log(`Unique Supabase URLs: ${scan.uniqueUrls.length}`);
  console.log("By collection:", scan.byCollection);

  writeScanReport(opts.project, {
    project: opts.project,
    mode,
    dryRun: opts.dryRun,
    hitsCount: scan.hits.length,
    uniqueUrlCount: scan.uniqueUrls.length,
    byCollection: scan.byCollection,
    uniqueUrls: scan.uniqueUrls,
    hits: scan.hits,
    scannedAt: new Date().toISOString(),
  });

  let copyResult = { copied: 0, failed: 0, urlMap: loadUrlMap(opts.project) };

  if (opts.copy) {
    console.log("\n=== Copy Supabase → R2 ===");
    copyResult = await copyUrls(scan.uniqueUrls, scan.rawUrlByNormalized, opts, urlConfig);
    console.log(`Copied: ${copyResult.copied}, Failed: ${copyResult.failed}`);
    if (copyResult.failed > 0 && !opts.dryRun) {
      process.exitCode = 1;
    }
  }

  const urlMap = opts.copy ? copyResult.urlMap : loadUrlMap(opts.project);

  if (opts.rewrite) {
    console.log("\n=== Rewrite Firestore ===");
    const mappedCount = scan.uniqueUrls.filter((u) => urlMap[u]?.newUrl).length;
    console.log(`URLs with R2 mapping: ${mappedCount}/${scan.uniqueUrls.length}`);
    if (mappedCount < scan.uniqueUrls.length) {
      console.warn(
        "Warning: some scanned URLs have no R2 mapping; those fields will be skipped.",
      );
    }
    if (opts.rewriteFromHits) {
      if (scan.hits.length === 0) {
        throw new Error("scan-report.json has no hits; run a scan first.");
      }
      const rewrite = await rewriteFirestoreFromHits(
        db,
        opts,
        urlMap,
        urlConfig,
        scan.hits,
      );
      console.log(
        `Updated documents: ${rewrite.updatedDocs}, field changes: ${rewrite.totalChanges}, Firestore reads: ~${rewrite.docReads}`,
      );
    } else {
      const rewrite = await rewriteFirestore(db, opts, urlMap, urlConfig);
      console.log(
        `Updated documents: ${rewrite.updatedDocs}, field changes: ${rewrite.totalChanges}`,
      );
    }
  }

  if (opts.purge) {
    console.log("\n=== Purge Supabase Storage + Firestore URLs ===");
    const supabaseResult = await deleteSupabaseObjectsByUrls(
      opts.project,
      scan.uniqueUrls,
      { dryRun: opts.dryRun, urlConfig },
    );
    console.log(
      `Supabase objects: deleted ${supabaseResult.deleted}, failed ${supabaseResult.failed}`,
    );
    const purge = await purgeFirestore(db, opts, urlConfig);
    console.log(
      `Firestore: cleared ${purge.totalChanges} URL(s) in ${purge.updatedDocs} document(s)`,
    );
    if ((supabaseResult.failed ?? 0) > 0 && !opts.dryRun) {
      process.exitCode = 1;
    }
  }

  if (!opts.copy && !opts.rewrite && !opts.purge) {
    console.log("\nDry-run scan complete. Use --copy and/or --rewrite to apply.");
  } else if (opts.purge && !opts.confirmPurge) {
    console.log("\nPurge preview complete. Re-run with --confirm-purge to apply.");
  }

  console.log(`\nReports: .migration-cache/${opts.project}/`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  const help = formatFirestoreQuotaHelp(error);
  if (help) console.error(`\n${help}`);
  process.exit(1);
});
