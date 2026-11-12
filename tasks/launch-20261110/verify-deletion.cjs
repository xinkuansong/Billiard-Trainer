// Run from any directory. Uses the existing isolated fixture runtime and a fresh local replica.
const path = require("node:path");
const fs = require("node:fs/promises");
const os = require("node:os");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const { once } = require("node:events");
const { createRequire } = require("node:module");
const root = path.resolve(__dirname, "../..");
const backend = createRequire(path.join(root, "backend/package.json"));
const runtime = path.join(root, "output/custom-formation-sync-20261019/runtime/node_modules/mongodb-memory-server");
const { MongoMemoryReplSet } = require(runtime);
const mongoose = backend("mongoose");

async function run() {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "cuephys-w4-"));
  process.env.AVATAR_STORAGE_DIR = directory;
  process.env.JWT_SECRET = crypto.randomBytes(32).toString("hex");
  process.env.JWT_REFRESH_SECRET = crypto.randomBytes(32).toString("hex");
  const { createApp } = backend("./src/app");
  const { signAccessToken, signRefreshToken } = backend("./src/utils/jwt");
  const User = backend("./src/models/User");
  const Training = backend("./src/models/TrainingSession");
  const Angle = backend("./src/models/AngleTest");
  const { CustomFormation, FormationChange } = backend("./src/models/CustomFormation");
  const owned = [Training, Angle, CustomFormation, FormationChange];
  const report = {};
  let mongo, server;
  try {
    mongo = await MongoMemoryReplSet.create({
      binary: { systemBinary: path.join(runtime, "mongodb-binaries/mongod-arm64-darwin-7.0.24"), version: "7.0.24" },
      replSet: { count: 1, ip: "127.0.0.1", storageEngine: "wiredTiger" },
      instanceOpts: [{ args: ["--setParameter", "enableTestCommands=1", "--wiredTigerCacheSizeGB", "0.25"] }],
    });
    await mongoose.connect(mongo.getUri("cuephys_w4"), { appName: "cuephys-w4", retryWrites: false });
    process.env.DELETION_LEDGER_URI = mongo.getUri("w4_deletions");
    process.env.DELETION_CHECKPOINT_DIR = path.join(directory, "deletion-checkpoints");
    await fs.mkdir(process.env.DELETION_CHECKPOINT_DIR);
    await backend("./src/services/deletionLedger").initializeLedger();
    await Promise.all([User, ...owned].map(model => model.init()));
    server = createApp().listen(0, "127.0.0.1");
    await once(server, "listening");
    async function call(account, method, route, body) {
      const bytes = Buffer.isBuffer(body);
      const res = await fetch("http://127.0.0.1:" + server.address().port + route, {
        method, headers: { Authorization: "Bearer " + account.token, "Content-Type": bytes ? "image/jpeg" : "application/json" },
        body: bytes ? body : JSON.stringify(body),
      });
      return { status: res.status, body: await res.json() };
    }
    const session = clientId => ({ clientId, date: new Date().toISOString() });
    const angle = clientId => ({ ...session(clientId), actualAngle: 30, userAngle: 31, pocketType: "corner" });
    async function user() {
      const row = await User.create({ provider: "apple" });
      const id = String(row._id);
      const refresh = signRefreshToken(id);
      await User.updateOne({ _id: id }, { refreshToken: refresh });
      return { id, token: signAccessToken(id), refresh };
    }
    async function seed(account) {
      assert.equal((await call(account, "POST", "/training-sessions", session("shared"))).status, 201);
      assert.equal((await call(account, "POST", "/angle-tests", angle("shared"))).status, 201);
      await CustomFormation.create({ userId: account.id, clientId: "shared", revision: 1, deleted: false, schemaVersion: 1, modifiedAt: new Date() });
      await FormationChange.create({ userId: account.id, sequence: 1, operationId: "shared", digest: "fixture", record: {revision:1} });
      assert.equal((await call(account, "PUT", "/user/avatar", Buffer.from([255,216,255,217]))).status, 200);
    }
    async function counts(account) {
      const counts = { user: await User.countDocuments({ _id: account.id }) };
      for (const model of owned) counts[model.modelName] = await model.countDocuments({ userId: account.id });
      counts.avatar = (await fs.readdir(directory)).filter(name => name.startsWith(account.id + "-")).length;
      return counts;
    }
    async function snapshot(account) {
      const data = [await User.findById(account.id).lean()];
      for (const model of owned) data.push(await model.find({ userId: account.id }).sort({_id: 1}).lean());
      for (const file of (await fs.readdir(directory)).filter(s => s.startsWith(account.id + "-"))) data.push(await fs.readFile(path.join(directory, file)));
      return crypto.createHash("sha256").update(JSON.stringify(data)).digest("hex");
    }
    const remove = account => call(account, "DELETE", "/user/account");
    const refresh = account => call(account, "POST", "/auth/refresh", { refreshToken: account.refresh });
    const a = await user(), b = await user();
    await seed(a); await seed(b);
    const bBefore = await snapshot(b);
    const pre = await call(a, "GET", "/training-sessions?userId=" + b.id);
    assert.equal(pre.body.length, 1); assert.equal(pre.body[0].userId, a.id);
    const earlyBatch = await call(a, "POST", "/training-sessions/batch", [session("before-batch")]);
    const earlyRefresh = await refresh(a);
    assert.equal(earlyRefresh.status, 200);
    a.refresh = earlyRefresh.body.refreshToken;
    report.before = { bHidden: true, batch: earlyBatch.status, refresh: earlyRefresh.status, counts: await counts(a) };
    report.normal = { status: (await remove(a)).status, counts: await counts(a) };
    assert.equal(report.normal.status, 200);
    assert(Object.values(report.normal.counts).every(n => n === 0));
    report.old = {
      single: (await call(a, "POST", "/training-sessions", { ...session("old"), userId: b.id })).status,
      batch: (await call(a, "POST", "/training-sessions/batch", [session("old-batch")])).status,
      angle: (await call(a, "POST", "/angle-tests", angle("old"))).status,
      readTraining: (await call(a, "GET", "/training-sessions")).status,
      readFormations: (await call(a, "GET", "/custom-formations")).status,
      refresh: (await refresh(a)).status, counts: await counts(a),
    };
    assert.deepEqual([report.old.single, report.old.batch, report.old.angle, report.old.readTraining,
      report.old.readFormations, report.old.refresh], Array(6).fill(401));
    const empty = counts => Object.values(counts).every(n => n === 0);
    assert(empty(report.old.counts));
    const admin = mongoose.connection.db.admin();
    async function block(command) {
      const fp = await admin.command({ configureFailPoint: "failCommand", mode: {times:1},
        data: { failCommands:[command], appName:"cuephys-w4", blockConnection:true, blockTimeMS:2400 } });
      return () => admin.command({waitForFailPoint:"failCommand", timesEntered: Number(fp.count) + 1, maxTimeMS:5000});
    }
    const pending = await user();
    const waitDelete = await block("delete");
    let deleteFinished = false;
    const deleting = remove(pending).then(res => { deleteFinished = true; return res; });
    await waitDelete();
    const pendingMarked = (await User.findById(pending.id)).deletionPending;
    const pendingValues = {
      single: (await call(pending, "POST", "/training-sessions", session("pending"))).status,
      batch: (await call(pending, "POST", "/training-sessions/batch", [session("pending-batch")])).status,
      refresh: (await refresh(pending)).status,
      read: (await call(pending, "GET", "/training-sessions?userId="+b.id)).status,
    };
    assert(pendingMarked && !deleteFinished);
    report.deleting = { pendingMarked, requestsCompletedBeforeDeletion:true, ...pendingValues, deletion: (await deleting).status, counts: await counts(pending) };
    assert.deepEqual(Object.values(pendingValues), [401, 401, 401, 401]);
    assert.equal(report.deleting.deletion, 200);
    assert(empty(report.deleting.counts));
    const late = await user();
    const waitInsert = await block("insert");
    const incoming = call(late, "POST", "/training-sessions", session("in-flight"));
    await waitInsert(); // The transaction holds the account row while its insert is paused.
    const deletingLate = remove(late);
    report.late = { insert:(await incoming).status, deletion:(await deletingLate).status, counts:await counts(late) };
    assert.equal(report.late.insert, 201);
    assert.equal(report.late.deletion, 200);
    assert(empty(report.late.counts));
    const losingWriter = await user();
    const waitForLock = await block("findAndModify");
    const delayed = call(losingWriter, "POST", "/training-sessions", session("late-lock"));
    await waitForLock(); // Authentication passed; the protected write has not acquired the user row.
    const firstDelete = await remove(losingWriter);
    const lateWrite = await delayed;
    report.deleteFirst = { deletion:firstDelete.status, write:lateWrite.status, counts:await counts(losingWriter) };
    assert.equal(firstDelete.status, 200);
    assert.equal(lateWrite.status, 401);
    assert(empty(report.deleteFirst.counts));

    const retry = await user(); await seed(retry);
    const avatarName = (await fs.readdir(directory)).find(name => name.startsWith(retry.id));
    const avatarPath = path.join(directory, avatarName);
    const bytes = await fs.readFile(avatarPath);
    // Remnants from a prior release must also disappear when account cleanup succeeds.
    await fs.writeFile(path.join(directory, retry.id + "-99.jpg"), bytes);
    await fs.writeFile(path.join(directory, retry.id + "-100.jpg.123.456.tmp"), bytes);
    await fs.unlink(avatarPath); await fs.mkdir(avatarPath);
    const failure = (await remove(retry)).status;
    const failedCounts = await counts(retry);
    assert.equal((await call(retry, "GET", "/user/profile")).status, 401);
    assert.equal((await refresh(retry)).status, 401);
    await fs.rmdir(avatarPath); await fs.writeFile(avatarPath, bytes);
    report.avatarFailure = { failure, failedCounts, retry: (await remove(retry)).status, counts: await counts(retry) };
    assert.equal(failure, 500);
    assert.equal(failedCounts.user, 1);
    assert.equal(report.avatarFailure.retry, 200);
    assert(empty(report.avatarFailure.counts));
    const dbRetry = await user(); await seed(dbRetry);
    await admin.command({configureFailPoint:"failCommand", mode:{skip:2}, data:{
      failCommands:["delete"], appName:"cuephys-w4", errorCode:2,
    }});
    const dbFailure = (await remove(dbRetry)).status;
    assert.equal(dbFailure, 500, "database fault must reach the real cleanup");
    await admin.command({configureFailPoint:"failCommand",mode:"off"});
    const afterFailure = await counts(dbRetry);
    assert.equal(afterFailure.user, 1);
    assert((await User.findById(dbRetry.id)).deletionPending);
    assert.equal((await refresh(dbRetry)).status, 401);
    // The startup/periodic recovery path needs no client credential.
    await backend("./src/services/accountDeletion").resumePendingDeletions(directory);
    report.databaseFailure = { failure:dbFailure, failedCounts:afterFailure, recoveredCounts:await counts(dbRetry),
      repeatDelete:(await remove(dbRetry)).status };
    assert(empty(report.databaseFailure.recoveredCounts));
    report.b = { untouched: bBefore === await snapshot(b), reads: (await call(b, "GET", "/training-sessions")).status,
      writes: (await call(b, "POST", "/training-sessions", session("active"))).status };
    assert(report.b.untouched && report.b.writes === 201);
    const target = await user();
    await seed(target);
    const targetRecord = await Training.findOne({ userId:target.id });
    const own = await Training.findOne({ userId:b.id, clientId:"shared" });
    const targetBefore = await snapshot(target);
    const direct = await call(b, "PUT", "/training-sessions/" + targetRecord.id, {note:"cross-user"});
    const changeOwner = await call(b, "PUT", "/training-sessions/" + own.id, {userId:target.id});
    const injected = await call(b, "PUT", "/training-sessions/" + own.id, {$set:{userId:target.id}});
    const edit = await call(b, "PUT", "/training-sessions/" + own.id, {note:"my note"});
    const stale = await call(a, "PUT", "/training-sessions/" + targetRecord.id, {note:"old"});
    report.crossAccount = { directOtherRecord:direct.status, changeOwner:changeOwner.status,
      mongoOperator:injected.status, staleToken:stale.status, legitimateEdit:edit.status,
      untouched:targetBefore === await snapshot(target) };
    assert.deepEqual(report.crossAccount, { directOtherRecord:404, changeOwner:400, mongoOperator:400,
      staleToken:401, legitimateEdit:200, untouched:true });
    const avatars = await user();
    await seed(avatars);
    const firstRevision = (await User.findById(avatars.id)).avatarRevision;
    const cleared = await call(avatars, "DELETE", "/user/avatar");
    assert.equal(cleared.status, 200);
    const uploaded = await call(avatars, "PUT", "/user/avatar", Buffer.from([255,216,0,255,217]));
    assert.equal(uploaded.status, 200);
    assert(uploaded.body.avatarRevision > firstRevision);
    assert.equal((await counts(avatars)).avatar, 1);
    const group = await Promise.all([1, 2].map(n => call(avatars, "PUT", "/user/avatar",
      Buffer.from([255,216,n,255,217]))));
    assert(group.every(r => r.status === 200));
    assert.notEqual(group[0].body.avatarRevision, group[1].body.avatarRevision);
    assert.equal((await counts(avatars)).avatar, 1);
    assert.equal((await remove(avatars)).status, 200);
    assert(empty(await counts(avatars)));
    report.avatars = { clearAndReupload:true, concurrentUploads:true, purged:true };

    const legacy = await user();
    await User.collection.updateOne({_id: new mongoose.Types.ObjectId(legacy.id)},
      {$unset:{ deletionPending:"", accountWriteSequence:"", avatarSequence:"" }});
    assert.equal((await call(legacy,"POST","/training-sessions",session("before-upgrade"))).status,201);
    const refreshed = await refresh(legacy);
    assert.equal(refreshed.status,200);
    assert.equal((await refresh(legacy)).status,401);
    assert.equal((await remove(legacy)).status,200);
    assert(empty(await counts(legacy)));
    report.legacy = { accountWithoutNewFields:true, previousRefreshRejected:true };
    const appleResult = await require("./verify-apple-grant.cjs")({backend,directory,call,seed,counts,block,report});
    await fs.writeFile(path.join(root, "output/launch-20261110/apple-revocation-local.json"),
      JSON.stringify(appleResult,null,2) + "\n");
    const file = path.join(root, "output/launch-20261110/account-deletion-fixed.json");
    await fs.writeFile(file, JSON.stringify(report,null,2) + "\n");
    console.log(file);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect();
    await backend("./src/services/deletionLedger").closeLedger();
    if (mongo) await mongo.stop();
    await fs.rm(directory, { recursive:true, force:true });
  }
}
run().catch(error => { console.error(error); process.exitCode = 1; });
