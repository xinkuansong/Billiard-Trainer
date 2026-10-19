// Isolated real MongoDB replica set + production Express routes. Never production data.
const path = require('node:path');
const fs = require('node:fs');
const runtime = process.env.FORMATION_TEST_RUNTIME;
if (!runtime) throw new Error('FORMATION_TEST_RUNTIME must point to an isolated mongodb-memory-server installation');
const { MongoMemoryReplSet } = require(path.join(runtime, 'node_modules/mongodb-memory-server'));
const mongoose = require('mongoose');
const { createApp } = require('../../src/app');
const User = require('../../src/models/User');
const { CustomFormation, FormationChange } = require('../../src/models/CustomFormation');
const { signAccessToken } = require('../../src/utils/jwt');
(async () => {
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger' }, instanceOpts: [{ args: ['--wiredTigerCacheSizeGB', '0.25'] }] });
  await mongoose.connect(mongo.getUri('formation_test'));
  await Promise.all([User.init(), CustomFormation.init(), FormationChange.init()]);
  const a = await User.create({ provider: 'apple', displayName: 'Formation Test A' });
  const b = await User.create({ provider: 'apple', displayName: 'Formation Test B' });
  const server = createApp().listen(0, '127.0.0.1', () => {
    const fixture = { baseURL: `http://127.0.0.1:${server.address().port}`, mongoURI: mongo.getUri('formation_test'),
      userID: String(a._id), token: signAccessToken(String(a._id)), otherUserID: String(b._id), otherToken: signAccessToken(String(b._id)),
      templateID: require('node:crypto').randomUUID() };
    fs.writeFileSync(process.env.FORMATION_TEST_FIXTURE, JSON.stringify(fixture), { mode: 0o600 });
    console.log('Isolated formation test server ready');
  });
  const close = async () => { server.close(); await mongoose.disconnect(); await mongo.stop(); process.exit(0); };
  process.on('SIGTERM', close); process.on('SIGINT', close);
})().catch(e => { console.error(e); process.exit(1); });
