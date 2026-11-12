// Loopback-only test observer. Run against a fresh, disposable local MongoDB replica.
// Pass a private temporary directory and a destination for the anonymized evidence.
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const crypto = require("node:crypto");
const { createRequire } = require("node:module");
const root = path.resolve(__dirname, "../..");
const backend = createRequire(path.join(root, "backend/package.json"));
const runtime = path.join(root, "output/custom-formation-sync-20261019/runtime/node_modules/mongodb-memory-server");
const { MongoMemoryReplSet } = require(runtime);
const mongoose = backend("mongoose");
const [directory, output] = process.argv.slice(2);
const phases = {
  guest: [], offA: [], offB: [], beforeDecline: [],
  decline: ["A:account-a"], disabled: ["A:account-a"], beforeAccept: ["A:account-a"],
  accept: ["A:account-a", "A:deferred-a", "A:guest"],
  syncB: ["A:account-a", "A:deferred-a", "A:guest", "B:account-b", "B:cloud-b"],
  offAgain: ["A:account-a", "A:deferred-a", "A:guest", "B:account-b", "B:cloud-b"],
};
phases.childGuest = phases.offAgain;
phases.afterChildGuest = phases.offAgain;
async function run() {
  assert(directory && output);
  const replica = await MongoMemoryReplSet.create({
    binary: { systemBinary: path.join(runtime, "mongodb-binaries/mongod-arm64-darwin-7.0.24"), version: "7.0.24" },
    replSet: { count: 1, ip: "127.0.0.1", storageEngine: "wiredTiger" },
    instanceOpts: [{ args: ["--wiredTigerCacheSizeGB", "0.25"] }],
  });
  let server;
  try {
    process.env.JWT_SECRET = crypto.randomBytes(32).toString("hex");
    process.env.JWT_REFRESH_SECRET = crypto.randomBytes(32).toString("hex");
    await mongoose.connect(replica.getUri("cuephys_privacy_fixture"));
    const User = backend("./src/models/User");
    const Training = backend("./src/models/TrainingSession");
    const jwt = backend("./src/utils/jwt");
    const actors = {};
    const labels = {};
    for (const [label, provider] of [["A","apple"], ["B","wechat"]]) {
      const user = await User.create({provider});
      const id = user.id;
      actors[label] = {id, token: jwt.signAccessToken(id)};
      labels[id] = label;
    }
    const host = backend("express")();
    const checkpoints = {};
    let phase, requests = [];
    async function observe() {
      if (!phase) return;
      const rows = await Training.find({}, {userId:1, note:1}).lean();
      const cloud = rows.map(row => labels[row.userId] + ":" + row.note).sort();
      console.log(JSON.stringify({phase, requests, cloud}));
      assert.deepEqual(cloud, [...phases[phase]].sort(), phase);
      const upload = {decline:1, accept:2, syncB:1}[phase];
      if (upload) {
        assert.equal(requests.filter(r => r.method === "POST" && r.path === "/training-sessions" && r.status === 201).length, upload, phase);
        assert(requests.every(r => r.account === (phase === "syncB" ? "B" : "A")), phase);
        assert(requests.every(r => r.status >= 200 && r.status < 300 && r.cache === "no-store"), phase);
        assert.deepEqual(requests.filter(r => r.method === "GET").map(r => r.path).sort(),
          ["/angle-tests", "/custom-formations", "/training-sessions"], phase);
      } else if (phase === "afterChildGuest") {
        assert.deepEqual(requests.map(r => r.path).sort(), ["/angle-tests", "/custom-formations", "/training-sessions"]);
        assert(requests.every(r => r.method === "GET" && r.account === "A" && r.status === 200));
      } else assert.equal(requests.length, 0, phase);
      checkpoints[phase] = {requests, cloud};
    }
    host.post("/fixture/:phase", async (req,res) => {
      try {
        const next = req.params.phase;
        assert.equal(next, [...Object.keys(phases), "done"][Object.keys(checkpoints).length + (phase ? 1 : 0)]);
        await observe();
        phase = next;
        requests = [];
        if (next === "syncB") {
          await Training.create({userId:actors.B.id, clientId:crypto.randomUUID(), date:new Date(),
            ballType:"chinese8", kind:"drill", totalDurationMinutes:1, note:"cloud-b", drillEntries:[]});
        }
        if (next === "done") await fs.writeFile(output, JSON.stringify({testedAt:new Date().toISOString(), checkpoints}, null, 2) + "\n");
        res.sendStatus(200);
      } catch (error) { console.error(error.stack); res.sendStatus(409); }
    });
    host.use((req,res,next) => {
      let account = "unauthenticated";
      try { account = labels[jwt.verifyAccessToken((req.headers.authorization || "").slice(7)).sub] || "unknown"; }
      catch { /* The observer counts unauthenticated requests; the real router decides their status. */ }
      const batch = requests;
      res.on("finish", () => batch.push({method:req.method, path:req.originalUrl.split("?")[0], account, status:res.statusCode, cache:res.get("Cache-Control")}));
      next();
    });
    host.use(backend("./src/app").createApp());
    server = await new Promise(resolve => { const s = host.listen(0,"127.0.0.1",()=>resolve(s)); });
    const file = path.join(directory,"fixture.json");
    await fs.writeFile(file + ".tmp", JSON.stringify({url:"http://127.0.0.1:"+server.address().port, ...actors}), {mode:0o600});
    await fs.rename(file + ".tmp", file);
    console.log("Loopback fixture ready");
    await new Promise(resolve => { process.once("SIGTERM",resolve); process.once("SIGINT",resolve); });
  } finally {
    if (server) { server.closeAllConnections(); await new Promise(resolve=>server.close(resolve)); }
    await mongoose.disconnect();
    await replica.stop();
    await fs.rm(path.join(directory,"fixture.json"),{force:true});
  }
}
run().catch(error => {console.error(error.message); process.exitCode=1;});
