// Actual Swift DTOs -> production Express routes -> disposable local MongoDB.
// No production URL, account or credential is read.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { randomBytes, createHash } = require('node:crypto');
const runtime = process.env.CUEPHYS_MONGO_TEST_RUNTIME;
assert(runtime && process.argv[2], 'Pass local runtime and exported Swift DTO JSON');
const { MongoMemoryReplSet } = require(path.join(runtime, 'node_modules/mongodb-memory-server'));
const mongoose = require('mongoose');
process.env.JWT_SECRET = randomBytes(32).toString('hex');
process.env.JWT_REFRESH_SECRET = randomBytes(32).toString('hex');
(async () => {
  const dtos = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  assert.deepEqual(new Set(dtos.map(x => x.kind)), new Set(['massePractice', 'jumpPractice', 'future-spatial-kind']));
  const mongo = await MongoMemoryReplSet.create({
    binary: { systemBinary: path.join(runtime, 'node_modules/mongodb-memory-server/mongodb-binaries/mongod-arm64-darwin-7.0.24'), version: '7.0.24' },
    replSet: { count: 1, ip: '127.0.0.1', storageEngine: 'wiredTiger' },
    instanceOpts: [{ args: ['--wiredTigerCacheSizeGB', '0.25'] }],
  });
  let server;
  const report = [];
  try {
    await mongoose.connect(mongo.getUri('cuephys_spatial_b4_test'));
    const { createApp } = require('../../src/app');
    const User = require('../../src/models/User');
    const Training = require('../../src/models/TrainingSession');
    const { signAccessToken } = require('../../src/utils/jwt');
    const a = await User.create({ provider: 'apple' }), b = await User.create({ provider: 'apple' });
    const token = signAccessToken(a.id), other = signAccessToken(b.id);
    const fixture = require('express')();
    let failNext = false;
    fixture.use((req,res,next) => {
      if (failNext && req.method === 'POST') { failNext = false; return res.status(503).json({ message: 'injected transient failure' }); }
      next();
    });
    fixture.use(createApp());
    server = fixture.listen(0, '127.0.0.1');
    await new Promise(resolve => server.once('listening', resolve));
    const base = `http://127.0.0.1:${server.address().port}`;
    async function request(method, route, body, credential=token) {
      const r=await fetch(base+route, { method, headers: { Authorization:`Bearer ${credential}`, 'Content-Type':'application/json' }, body: body===undefined ? undefined : JSON.stringify(body) });
      return { status:r.status, body:await r.json() };
    }
    for (const dto of dtos) {
      failNext = true;
      assert.equal((await request('POST','/training-sessions',dto)).status,503);
      assert.equal(await Training.countDocuments({userId:a.id,clientId:dto.clientId}),0);
      assert.equal((await request('POST','/training-sessions',dto)).status,201);
      assert.equal((await request('POST','/training-sessions',dto)).status,200);
      assert.equal(await Training.countDocuments({userId:a.id,clientId:dto.clientId}),1);
      const persisted=await Training.findOne({userId:a.id,clientId:dto.clientId}).lean();
      assert.equal(persisted.kind,dto.kind);assert.equal(persisted.sourcePayloadSnapshot,dto.sourcePayloadSnapshot);
      const list=await request('GET','/training-sessions?page=1');assert.equal(list.status,200);
      const restored=list.body.items.find(x=>x.clientId===dto.clientId);
      assert.equal(restored.kind,dto.kind);assert.equal(restored.sourcePayloadSnapshot,dto.sourcePayloadSnapshot);
      assert.deepEqual(Buffer.from(restored.sourcePayloadSnapshot,'base64'),Buffer.from(dto.sourcePayloadSnapshot,'base64'));
      const updated={...dto,note:'updated after retry'};
      assert.equal((await request('PUT','/training-sessions/'+persisted._id,updated)).status,200);
      assert.equal((await request('GET','/training-sessions',undefined,other)).body.length,0);
      assert.equal((await request('DELETE','/training-sessions/by-client/'+dto.clientId,undefined,other)).body.deletedCount,0);
      assert.equal((await request('DELETE','/training-sessions/by-client/'+dto.clientId)).body.deletedCount,1);
      assert.equal((await request('DELETE','/training-sessions/by-client/'+dto.clientId)).body.deletedCount,0);
      assert(!(await request('GET','/training-sessions')).body.some(x=>x.clientId===dto.clientId));
      report.push({kind:dto.kind, payloadBytes:Buffer.from(dto.sourcePayloadSnapshot,'base64').length,
        sha256:createHash('sha256').update(Buffer.from(dto.sourcePayloadSnapshot,'base64')).digest('hex'),
        checks:['503 retry','idempotent upload','actual Mongo bytes','paged restore','update','owner isolation','idempotent delete']});
      console.log('PASS',dto.kind,JSON.stringify(report.at(-1)));
    }
    if (process.argv[3]) fs.writeFileSync(process.argv[3],JSON.stringify(report,null,2)+'\n');
  } finally {
    if(server) await new Promise(resolve=>server.close(resolve));
    await mongoose.disconnect();await mongo.stop();
    console.log('CLOSED loopback HTTP and disposable MongoDB');
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
