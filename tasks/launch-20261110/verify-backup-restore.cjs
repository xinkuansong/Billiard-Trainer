// Usage: PATH=<MongoDB Database Tools bin>:$PATH node verify-backup-restore.cjs
// Both replica sets are created locally. No production URI, data or key is used.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { promisify } = require("node:util");
const execFile = promisify(require("node:child_process").execFile);
const { once } = require("node:events");
const { createRequire } = require("node:module");

const root = path.resolve(__dirname, "../..");
const backend = createRequire(path.join(root, "backend/package.json"));
const runtime = path.join(root, "output/custom-formation-sync-20261019/runtime/node_modules/mongodb-memory-server");
const { MongoMemoryReplSet } = require(runtime);
const mongoose = backend("mongoose");
const dbName = "cuephys_restore_fixture";
const replicaOptions = {
  binary: { systemBinary: path.join(runtime, "mongodb-binaries/mongod-arm64-darwin-7.0.24"), version: "7.0.24" },
  replSet: { count: 1, ip: "127.0.0.1", storageEngine: "wiredTiger" },
  instanceOpts: [{ args: ["--wiredTigerCacheSizeGB", "0.25"] }],
};

async function run() {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), "cuephys-w9-"));
  process.env.AVATAR_STORAGE_DIR = path.join(tmp, "avatars");
  process.env.JWT_SECRET = crypto.randomBytes(32).toString("hex");
  process.env.JWT_REFRESH_SECRET = crypto.randomBytes(32).toString("hex");
  const { createApp } = backend("./src/app");
  const { signAccessToken, signRefreshToken } = backend("./src/utils/jwt");
  const { initializeLedger, closeLedger, recordDeletion } = backend("./src/services/deletionLedger");
  const { reconcileRestoredAccounts } = backend("./src/services/accountDeletion");
  const User = backend("./src/models/User");
  const Training = backend("./src/models/TrainingSession");
  const Angle = backend("./src/models/AngleTest");
  const { CustomFormation, FormationChange } = backend("./src/models/CustomFormation");
  const models = [User, Training, Angle, CustomFormation, FormationChange];
  const avatars = process.env.AVATAR_STORAGE_DIR;
  const archive = path.join(tmp, "database.archive.gz");
  const avatarArchive = path.join(tmp, "avatars.tar.gz");
  const report = { startedAt: new Date().toISOString(), databaseTools: (await execFile("mongorestore", ["--version"])).stdout.split("\n")[0] };
  let source, target, server;

  async function startApi() {
    server = createApp().listen(0, "127.0.0.1");
    await once(server, "listening");
  }
  async function stopApi() {
    if (!server) return;
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    server = null;
  }
  async function request(account, method, route, data) {
    const response = await fetch("http://127.0.0.1:" + server.address().port + route, {
      method, headers: { Authorization: "Bearer " + account.access,
        "Content-Type": Buffer.isBuffer(data) ? "image/jpeg" : "application/json" },
      body: Buffer.isBuffer(data) ? data : JSON.stringify(data),
    });
    return response;
  }
  async function seed(label) {
    const user = await User.create({ provider: "apple", appleUserId: "fixture-" + label });
    const account = { id: user._id, access: signAccessToken(user.id), refresh: signRefreshToken(user.id) };
    await User.updateOne({ _id: user._id }, { refreshToken: account.refresh });
    assert.equal((await request(account, "POST", "/training-sessions", { clientId: label, date: new Date() })).status, 201);
    assert.equal((await request(account, "POST", "/angle-tests", { clientId: label, date: new Date(), actualAngle: 30, userAngle: 31, pocketType: "corner" })).status, 201);
    assert.equal((await request(account, "PUT", "/user/avatar", Buffer.from([255, 216, label.charCodeAt(0), 255, 217]))).status, 200);
    await CustomFormation.create({ userId: user._id, clientId: label, revision: 1, deleted: false, schemaVersion: 1, modifiedAt: new Date(), template: { name: label } });
    await FormationChange.create({ userId: user._id, sequence: 1, operationId: label, digest: "fixture", record: { revision: 1 } });
    return account;
  }
  async function inventory(account) {
    const counts = {};
    const hash = crypto.createHash("sha256");
    // Read native documents so refresh tokens and stored identity fields are included in the comparison.
    for (const model of models) {
      const filter = model === User ? { _id: account.id } : { userId: account.id };
      const docs = await model.collection.find(filter).sort({ _id: 1 }).toArray();
      counts[model.collection.name] = docs.length;
      hash.update(JSON.stringify(docs));
    }
    const files = (await fs.readdir(avatars)).filter(name => name.startsWith(account.id + "-")).sort();
    counts.avatars = files.length;
    for (const name of files) hash.update(await fs.readFile(path.join(avatars, name)));
    return { counts, digest: hash.digest("hex") };
  }
  async function probe(account) {
    const status = {};
    for (const route of ["/user/profile", "/training-sessions", "/user/avatar", "/custom-formations"]) {
      status[route] = (await request(account, "GET", route)).status;
    }
    status.write = (await request(account, "POST", "/training-sessions", { clientId: "late-write", date: new Date() })).status;
    status.refresh = (await request(account, "POST", "/auth/refresh", { refreshToken: account.refresh })).status;
    return status;
  }
  try {
    source = await MongoMemoryReplSet.create(replicaOptions);
    await mongoose.connect(source.getUri(dbName));
    process.env.DELETION_LEDGER_URI = source.getUri("fixture_deletions");
    process.env.DELETION_CHECKPOINT_DIR = path.join(tmp, "witness");
    await fs.mkdir(process.env.DELETION_CHECKPOINT_DIR);
    await initializeLedger();
    await Promise.all(models.map(model => model.init()));
    await startApi();
    const deleted = await seed("A"), control = await seed("B");
    const interrupted = await seed("C");
    const aBefore = await inventory(deleted), bBefore = await inventory(control);
    assert.ok(Object.values(aBefore.counts).every(n => n === 1));
    assert.ok(Object.values(bBefore.counts).every(n => n === 1));
    await execFile("mongodump", ["--uri", source.getUri(dbName), "--archive=" + archive, "--gzip", "--quiet"]);
    await execFile("tar", ["-czf", avatarArchive, "-C", avatars, "."]);
    assert.equal((await request(deleted, "DELETE", "/user/account")).status, 200);
    report.afterDeletion = (await inventory(deleted)).counts;
    report.beforeRestoreAccess = await probe(deleted);
    assert.ok(Object.values(report.afterDeletion).every(n => n === 0));
    assert.ok(Object.values(report.beforeRestoreAccess).every(code => code === 401));
    assert.deepEqual(await inventory(control), bBefore);
    // Two duplicate requests for C reach the durable intent, then the writer crashes
    // before marking the owner row. The restored snapshot still contains an active C.
    await Promise.all([recordDeletion(interrupted.id, "requested"), recordDeletion(interrupted.id, "requested")]);
    await stopApi();
    await closeLedger();
    await mongoose.disconnect();

    target = await MongoMemoryReplSet.create(replicaOptions);
    const archiveStarted = performance.now();
    await execFile("mongorestore", ["--uri", target.getUri(), "--archive=" + archive, "--gzip", "--nsInclude=" + dbName + ".*", "--stopOnError", "--quiet"]);
    await fs.rename(avatars, path.join(tmp, "source-avatars"));
    await fs.mkdir(avatars);
    await execFile("tar", ["-xzf", avatarArchive, "-C", avatars]);
    await mongoose.connect(target.getUri(dbName));
    report.archiveRestoreMs = Math.round(performance.now() - archiveStarted);
    const anchor = mongoose.connection.db.collection("deletion_ledger_anchor");
    const baseline = await anchor.findOne({});
    await anchor.deleteOne({ _id: baseline._id });
    await assert.rejects(reconcileRestoredAccounts(avatars), /no valid deletion ledger anchor/);
    report.preLedgerBackupBlocked = true;
    await anchor.insertOne(baseline);

    const witness = path.join(process.env.DELETION_CHECKPOINT_DIR, baseline.identity);
    await fs.rename(witness, witness + ".missing");
    await assert.rejects(reconcileRestoredAccounts(avatars), { code: "ENOENT" });
    // Run the actual entry point with the broken checkpoint. It must exit before listen.
    await assert.rejects(execFile(process.execPath, [path.join(root, "backend/server.js")], {
      env: { ...process.env, MONGODB_URI: target.getUri(dbName) }, timeout: 15000,
    }), error => error.code === 1 && error.stderr.includes("Backend startup failed")
      && !error.stdout.includes("Server listening"));
    report.failedStartupBeforeListen = true;
    await fs.rename(witness + ".missing", witness);
    report.missingWitnessBlocked = true;

    const ledgerClient = await mongoose.createConnection(process.env.DELETION_LEDGER_URI).asPromise();
    try {
      const events = ledgerClient.db.collection("deletion_events");
      assert.equal(await events.countDocuments({}), 3);
      report.duplicateRequestsDeduplicated = true;
      const last = await events.findOne({ sequence: 3 });
      const heads = ledgerClient.db.collection("deletion_ledger_metadata");
      const original = await heads.findOne({});
      await events.deleteOne({ _id: last._id });
      await assert.rejects(reconcileRestoredAccounts(avatars), /incomplete or damaged/);
      report.missingEventBlocked = true;
      const previous = await events.findOne({ sequence: 2 });
      await heads.updateOne({ _id: original._id }, { $set: { sequence: 2, hash: previous.hash } });
      await assert.rejects(reconcileRestoredAccounts(avatars), /incomplete or damaged/);
      report.staleLedgerBlocked = true;
      await events.insertOne(last);
      await heads.replaceOne({ _id: original._id }, original);
    } finally { await ledgerClient.close(); }

    assert.deepEqual(await inventory(deleted), aBefore);
    // Simulate a filesystem interruption during replay; retry the whole operation.
    await fs.rename(avatars, avatars + ".saved");
    await fs.writeFile(avatars, "injected failure");
    await assert.rejects(reconcileRestoredAccounts(avatars), { code: "ENOTDIR" });
    await fs.unlink(avatars);
    await fs.rename(avatars + ".saved", avatars);
    report.interruptedReplayBlocked = true;
    const replayStarted = performance.now();
    await reconcileRestoredAccounts(avatars);
    report.replayMs = Math.round(performance.now() - replayStarted);
    await startApi();
    assert.ok(Object.values((await inventory(interrupted)).counts).every(n => n === 0));
    assert.ok(Object.values(await probe(interrupted)).every(code => code === 401));
    report.unfinishedDeletionReplayed = true;
    report.afterRestore = (await inventory(deleted)).counts;
    report.deletedAccountMatchesSnapshot = (await inventory(deleted)).digest === aBefore.digest;
    assert.deepEqual(await inventory(control), bBefore);
    report.controlMatchesSnapshot = true;
    const recovered = await request(control, "GET", "/training-sessions");
    assert.equal(recovered.status, 200);
    assert.deepEqual((await recovered.json()).map(row => row.clientId), ["B"]);
    report.controlRead = recovered.status;
    report.afterRestoreAccess = await probe(deleted);
    report.safeToReopen = Object.values(report.afterRestore).every(n => n === 0)
      && Object.values(report.afterRestoreAccess).every(code => code === 401);

    await reconcileRestoredAccounts(avatars);
    assert.deepEqual((await inventory(deleted)).counts, report.afterRestore);
    assert.deepEqual(await inventory(control), bBefore);
    report.repeatReplaySafe = true;
    console.log(JSON.stringify(report, null, 2));
    if (!report.safeToReopen) process.exitCode = 2;
  } finally {
    await stopApi();
    await mongoose.disconnect();
    await closeLedger();
    if (target) await target.stop();
    if (source) await source.stop();
    await fs.rm(tmp, { recursive: true, force: true });
  }
}
run().catch(error => { console.error(error); process.exitCode = 1; });
