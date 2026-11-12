// This database is administered independently of the restorable application database.
const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");
const mongoose = require("mongoose");

const metadata = "deletion_ledger_metadata";
const events = "deletion_events";
const anchor = "deletion_ledger_anchor";
const headId = "v1";
const identityPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const durable = { w: "majority", j: true };
let connectionPromise;

function ledger() {
  const uri = process.env.DELETION_LEDGER_URI;
  if (!uri) throw new Error("DELETION_LEDGER_URI is required");
  if (!connectionPromise) {
    connectionPromise = mongoose.createConnection(uri, { serverSelectionTimeoutMS: 5000 }).asPromise()
      .then(async connection => {
        if (connection.name === mongoose.connection.name || ["admin", "local", "config", "test"].includes(connection.name)) {
          await connection.close();
          throw new Error("Use a dedicated, explicitly named deletion ledger database");
        }
        return connection;
      }).catch(error => { connectionPromise = undefined; throw error; });
  }
  return connectionPromise;
}

function digest(previous, sequence, key, recordedAt) {
  return crypto.createHash("sha256").update(JSON.stringify([previous, sequence, key, recordedAt])).digest("hex");
}

// Independent, append-only checkpoint names contain a sequence and digest only.
function checkpointDir(identity) {
  const base = process.env.DELETION_CHECKPOINT_DIR;
  if (!base || !path.isAbsolute(base)) throw new Error("Absolute DELETION_CHECKPOINT_DIR is required");
  return path.join(base, identity);
}

async function checkpoint(dir, sequence, hash) {
  const validHash = sequence === 0 ? identityPattern.test(hash) : /^[0-9a-f]{64}$/.test(hash);
  if (!Number.isSafeInteger(sequence) || sequence < 0 || !validHash) throw new Error("Invalid deletion checkpoint");
  const file = await fs.open(path.join(dir, sequence + "-" + hash), "a", 0o600);
  try { await file.sync(); } finally { await file.close(); }
  const directory = await fs.open(dir, "r");
  try { await directory.sync(); } finally { await directory.close(); }
}

// Explicit one-time provisioning against the current live database. Never called on startup.
async function initializeLedger() {
  const { db } = await ledger();
  const source = mongoose.connection.db.collection(anchor);
  if (await source.findOne({ _id: headId }) || (await db.listCollections().toArray()).length) {
    throw new Error("Ledger or business anchor already exists; initialization refused");
  }
  const identity = crypto.randomUUID();
  const dir = checkpointDir(identity);
  await fs.mkdir(dir, { mode: 0o700 });
  await checkpoint(dir, 0, identity);
  const parent = await fs.open(path.dirname(dir), "r");
  try { await parent.sync(); } finally { await parent.close(); }
  await db.collection(events).createIndex({ sequence: 1 }, { unique: true });
  await db.collection(metadata).insertOne({ _id: headId, identity, sequence: 0, hash: identity }, { writeConcern: durable });
  await source.insertOne({ _id: headId, identity, sequence: 0 }, { writeConcern: durable });
}

async function businessAnchor() {
  const value = await mongoose.connection.db.collection(anchor).findOne({ _id: headId });
  if (!value || !identityPattern.test(value.identity) || !Number.isSafeInteger(value.sequence) || value.sequence < 0) {
    throw new Error("Business backup has no valid deletion ledger anchor");
  }
  return value;
}

async function recordDeletion(userId, phase) {
  const id = String(userId);
  if (!/^[a-f0-9]{24}$/.test(id) || !["requested", "completed"].includes(phase)) throw new Error("Invalid deletion event");
  const key = phase + ":" + id;
  const source = await businessAnchor();
  const connection = await ledger();
  const db = connection.db;
  const event = await connection.transaction(async session => {
    const head = await db.collection(metadata).findOne({ _id: headId }, { session });
    if (!head || head.identity !== source.identity || head.sequence < source.sequence) {
      throw new Error("Deletion ledger missing, mismatched or stale");
    }
    const existing = await db.collection(events).findOne({ _id: key }, { session });
    if (existing) return existing;
    const next = head.sequence + 1;
    const recordedAt = new Date().toISOString();
    const hash = digest(head.hash, next, key, recordedAt);
    // Serialize writers on the head first. MongoDB retries conflicting transactions.
    await db.collection(metadata).updateOne({ _id: headId }, { $set: { sequence: next, hash } }, { session });
    const entry = { _id: key, sequence: next, recordedAt, hash };
    await db.collection(events).insertOne(entry, { session });
    return entry;
  }, { writeConcern: durable, readConcern: { level: "snapshot" } });
  await checkpoint(checkpointDir(source.identity), event.sequence, event.hash);
  const saved = await mongoose.connection.db.collection(anchor).updateOne(
    { _id: headId, identity: source.identity }, { $max: { sequence: event.sequence } }, { writeConcern: durable }
  );
  if (!saved.matchedCount) throw new Error("Business deletion ledger anchor changed");
}

// During recovery all writers must be stopped. Unexpected tail events also block startup.
async function readDeletions() {
  const source = await businessAnchor();
  const { db } = await ledger();
  const head = await db.collection(metadata).findOne({ _id: headId });
  if (!head || head.identity !== source.identity || !Number.isSafeInteger(head.sequence) || head.sequence < source.sequence) {
    throw new Error("Deletion ledger missing, mismatched or stale");
  }
  const checkpoints = new Set(await fs.readdir(checkpointDir(source.identity)));
  if (!checkpoints.delete("0-" + source.identity)) throw new Error("Deletion checkpoint baseline missing");
  const accounts = new Map();
  let hash = source.identity;
  let sequence = 0;
  for await (const event of db.collection(events).find({}).sort({ sequence: 1 })) {
    const match = /^(requested|completed):([a-f0-9]{24})$/.exec(event._id);
    sequence += 1;
    if (!match || event.sequence !== sequence || (match[1] === "completed" && !accounts.has(match[2]))) {
      throw new Error("Deletion ledger has a gap or invalid event");
    }
    hash = digest(hash, sequence, event._id, event.recordedAt);
    if (event.hash !== hash || !checkpoints.delete(sequence + "-" + hash)) throw new Error("Deletion checkpoint mismatch");
    accounts.set(match[2], match[1]);
  }
  if (sequence !== head.sequence || hash !== head.hash || checkpoints.size) throw new Error("Deletion ledger is incomplete or damaged");
  return accounts;
}

async function closeLedger() {
  if (connectionPromise) await (await connectionPromise).close();
  connectionPromise = undefined;
}

module.exports = { initializeLedger, recordDeletion, readDeletions, closeLedger };
