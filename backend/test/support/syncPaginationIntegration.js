// Real HTTP + disposable MongoDB only. No production connection or credentials.
const assert = require("node:assert/strict");
const path = require("node:path");
const { randomUUID, randomBytes } = require("node:crypto");
const runtime = process.env.CUEPHYS_MONGO_TEST_RUNTIME;
assert(runtime, "Set CUEPHYS_MONGO_TEST_RUNTIME to the local Mongo test runtime");
const { MongoMemoryReplSet } = require(path.join(runtime, "node_modules/mongodb-memory-server"));
const mongoose = require("mongoose");
process.env.JWT_SECRET = randomBytes(32).toString("hex");
process.env.JWT_REFRESH_SECRET = randomBytes(32).toString("hex");

(async () => {
  const mongo = await MongoMemoryReplSet.create({
    binary: { systemBinary: path.join(runtime, "node_modules/mongodb-memory-server/mongodb-binaries/mongod-arm64-darwin-7.0.24"), version: "7.0.24" },
    replSet: { count: 1, ip: "127.0.0.1", storageEngine: "wiredTiger" },
    instanceOpts: [{ args: ["--wiredTigerCacheSizeGB", "0.25"] }],
  });
  let server;
  try {
    await mongoose.connect(mongo.getUri("cuephys_sync_pagination_test"));
    const { createApp } = require("../../src/app");
    const User = require("../../src/models/User");
    const Training = require("../../src/models/TrainingSession");
    const Angle = require("../../src/models/AngleTest");
    const { signAccessToken } = require("../../src/utils/jwt");
    const a = await User.create({ provider: "apple" }), b = await User.create({ provider: "apple" });
    const token = signAccessToken(a.id), otherToken = signAccessToken(b.id);
    server = createApp().listen(0, "127.0.0.1");
    await new Promise(resolve => server.once("listening", resolve));
    const base = `http://127.0.0.1:${server.address().port}`;
    async function get(route, credential = token) {
      const r = await fetch(base + route, { headers: { Authorization: `Bearer ${credential}` } });
      return { status: r.status, body: await r.json() };
    }
    const sameTime = new Date("2026-01-01T00:00:00.123Z");
    const baseline = [];
    for (const [Model, route] of [[Training, "/training-sessions"], [Angle, "/angle-tests"]]) {
      const rows = Array.from({ length: 1201 }, (_, i) => ({
        _id: new mongoose.Types.ObjectId(), userId: a._id, clientId: randomUUID(),
        date: new Date(sameTime.getTime() - i * 1000), updatedAt: sameTime, createdAt: sameTime,
        actualAngle: 30, userAngle: 29, pocketType: "corner", note: "isolated-pagination-fixture",
      }));
      await Model.collection.insertMany(rows);
      await Model.collection.insertOne({ ...rows[0], _id: new mongoose.Types.ObjectId(), userId: b._id, clientId: randomUUID() });
      baseline.push({ Model, route, rows });
      const first = await get(route + "?page=1");
      assert.equal(first.status, 200); assert.equal(first.body.items.length, 200);
      assert.equal((await get(route + "?page=1&cursor=" + first.body.nextCursor, otherToken)).status, 400);
      const opposite = route === "/training-sessions" ? "/angle-tests" : "/training-sessions";
      assert.equal((await get(opposite + "?page=1&cursor=" + first.body.nextCursor)).status, 400);
      const through = new Date(JSON.parse(Buffer.from(first.body.nextCursor, "base64url")).through);
      while (Date.now() <= through.getTime()) await new Promise(resolve => setTimeout(resolve, 2));
      const lateAt = new Date();
      const late = { ...rows[0], _id: new mongoose.Types.ObjectId(), clientId: randomUUID(), updatedAt: lateAt, createdAt: lateAt };
      await Model.collection.insertOne(late);
      await Model.collection.updateOne({ _id: rows[0]._id }, { $set: { updatedAt: lateAt } });
      let page = first.body, records = [...page.items], pages = 1;
      while (page.nextCursor) {
        const next = await get(route + "?page=1&cursor=" + page.nextCursor);
        assert.equal(next.status, 200); page = next.body; records.push(...page.items); pages++;
      }
      assert.equal(pages, 7); assert.equal(records.length, 1201);
      assert.equal(new Set(records.map(r => r.clientId)).size, 1201);
      assert(records.every(r => String(r.userId) === a.id));
      assert(!records.some(r => r.clientId === late.clientId));
      const incremental = await get(route + "?page=1&after=" + sameTime.toISOString());
      assert.equal(incremental.status, 200); assert.equal(incremental.body.items.length, 2);
      assert.equal(incremental.body.nextCursor, null);
      assert.deepEqual(new Set(incremental.body.items.map(r => r.clientId)), new Set([rows[0].clientId, late.clientId]));
      for (const query of ["cursor=not-json", "after=not-a-date", "cursor[]=x"]) {
        assert.equal((await get(route + "?page=1&" + query)).status, 400);
      }
      assert.equal((await get(route + "?page=1", "invalid")).status, 401);
      assert.equal((await get(route)).body.length, 500, "Ordinary bounded listing keeps its contract");
      console.log(`PASS ${route}: 1201 tied timestamps / 7 pages / ownership / scope / stable upper bound / incremental / invalid cursor`);
    }
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
