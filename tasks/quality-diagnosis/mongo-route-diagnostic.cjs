'use strict';
// DRAFT: run only after parent review. Owns a fresh mongod child; never connects to an existing DB.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { createRequire } = require('node:module');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const net = require('node:net');
const frozen = '/Users/song/projects/13.billiard_trainer/build/quality-diagnosis/snapshot-002/backend';
let mongoose, Training, Angle, sign, server, child, run, base;
const digest = f => crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
function tree(dir, prefix = '') {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => {
    assert(!e.isSymbolicLink(), 'No source symlinks');
    const rel = path.join(prefix, e.name);
    return e.isDirectory() ? tree(path.join(dir, e.name), rel) : [rel];
  }).sort();
}
function summary(label, values) { console.log(JSON.stringify({ label, ...values })); }
const owner = n => n.toString(16).padStart(24, '0');
async function request(route, who, method = 'GET', body) {
  const response = await fetch(base + route, {
    method, redirect: 'error', signal: AbortSignal.timeout(5000),
    headers: { 'content-type': 'application/json', ...(who ? { authorization: 'Bearer ' + sign(who) } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, data: await response.json() };
}
before(async () => {
  assert.equal(process.env.QD_ALLOW_REAL_MONGO, 'NEW_OWNED_LOOPBACK_INSTANCE');
  const backend = fs.realpathSync(process.env.QD_BACKEND_ROOT);
  assert(backend.startsWith('/private/tmp/qd-mongo-'), 'Copied backend must be in dedicated temp area');
  assert(!fs.existsSync(path.join(backend, '.env')), 'Do not copy env files');
  const sourceFiles = tree(path.join(frozen, 'src'));
  assert.deepEqual(tree(path.join(backend, 'src')), sourceFiles);
  for (const rel of sourceFiles) assert.equal(digest(path.join(backend, 'src', rel)), digest(path.join(frozen, 'src', rel)), 'Frozen source mismatch');
  for (const rel of ['package.json', 'package-lock.json']) assert.equal(digest(path.join(backend, rel)), digest(path.join(frozen, rel)));
  const load = createRequire(path.join(backend, 'package.json'));
  for (const dependency of ['express', 'mongoose', 'jsonwebtoken']) {
    assert(fs.realpathSync(load.resolve(dependency)).startsWith(backend + '/node_modules/'), 'Dependency escaped copied backend');
  }
  const binary = fs.realpathSync(process.env.QD_MONGOD);
  assert.equal(digest(binary), process.env.QD_MONGOD_SHA256, 'Approved binary hash required');
  const port = Number(process.env.QD_MONGO_PORT);
  assert(Number.isInteger(port) && port >= 37000 && port <= 37999, 'Only dedicated high port range');
  // Probe availability only, then still verify child identity after launch to handle races.
  const probe = net.createServer();
  await new Promise((resolve, reject) => { probe.once('error', reject); probe.listen(port, '127.0.0.1', resolve); });
  await new Promise(resolve => probe.close(resolve));
  run = fs.mkdtempSync('/private/tmp/qd-mongo-real-');
  const db = path.join(run, 'db'); fs.mkdirSync(db); assert.deepEqual(fs.readdirSync(db), []);
  const log = path.join(run, 'mongod.log');
  child = spawn(binary, ['--dbpath', db, '--bind_ip', '127.0.0.1', '--port', String(port), '--nounixsocket', '--logpath', log], {
    env: { PATH: '/usr/bin:/bin', TMPDIR: run }, stdio: 'ignore',
  });
  let spawnError = false; child.once('error', () => { spawnError = true; });
  let ready = false;
  for (let i = 0; i < 150; i++) {
    assert(!spawnError && child.exitCode === null, 'Owned mongod failed; do not connect');
    if (fs.existsSync(log) && fs.readFileSync(log, 'utf8').includes('Waiting for connections')) { ready = true; break; }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  assert(ready, 'Owned mongod did not become ready');
  const uri = `mongodb://127.0.0.1:${port}/qd_isolated_run001?directConnection=true`;
  process.env.MONGODB_URI = uri;
  process.env.JWT_SECRET = 'qd-local-only-fixed-access-never-production';
  process.env.JWT_REFRESH_SECRET = 'qd-local-only-fixed-refresh-never-production';
  mongoose = load('mongoose');
  // No models imported until connection identity verified: avoids automatic index writes to a wrong DB.
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 3000 });
  const admin = mongoose.connection.db.admin();
  const opts = await admin.command({ getCmdLineOpts: 1 });
  const status = await admin.command({ serverStatus: 1 });
  assert.equal(fs.realpathSync(opts.parsed.storage.dbPath), db);
  assert.equal(opts.parsed.net.bindIp, '127.0.0.1'); assert.equal(opts.parsed.net.port, port);
  assert.equal(Number(status.pid), child.pid, 'Must be our own process');
  assert.equal(mongoose.connection.name, 'qd_isolated_run001');
  assert.equal((await mongoose.connection.db.listCollections().toArray()).length, 0);
  Training = load('./src/models/TrainingSession'); Angle = load('./src/models/AngleTest');
  await Training.init(); await Angle.init();
  sign = load('./src/utils/jwt').signAccessToken;
  const express = load('express'); const app = express(); app.use(express.json());
  app.use('/training-sessions', load('./src/routes/trainingSession'));
  app.use('/angle-tests', load('./src/routes/angleTest'));
  // Frozen src has auth middleware only; wrapper error response deliberately contains no error/token dump.
  app.use((err, req, res, next) => res.status(500).json({ diagnosticError: true }));
  server = app.listen(0, '127.0.0.1'); await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}`;
  summary('identity', { run, dbpath: db, pid: child.pid, port, database: mongoose.connection.name, sourceFiles: sourceFiles.length });
}, { timeout: 30000 });
after(async () => {
  if (server) await new Promise(resolve => server.close(resolve));
  if (mongoose) await mongoose.disconnect();
  if (child && child.pid && child.exitCode === null && child.signalCode === null) {
    const ended = once(child, 'exit'); child.kill('SIGTERM');
    let timer;
    try { await Promise.race([ended, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Owned mongod SIGTERM timeout; preserve process handle for parent')), 10000); })]); }
    finally { clearTimeout(timer); }
  }
  // Preserve fresh DB/log for evidence. Never dropDatabase, remove files, or kill another PID.
}, { timeout: 20000 });
test('QD007 ownership must remain A after attempted userId reassignment', async () => {
  const A = owner(1), B = owner(2);
  const doc = await Training.create({ clientId: 'qd007-one', userId: A, date: new Date('2026-01-01Z') });
  assert.equal((await request('/training-sessions')).status, 401);
  const initialA = await request('/training-sessions', A), initialB = await request('/training-sessions', B);
  assert.equal(initialA.status, 200); assert.equal(initialB.status, 200);
  assert.equal(initialA.data.length, 1); assert.equal(initialB.data.length, 0);
  const put = await request('/training-sessions/' + doc._id, A, 'PUT', { userId: B });
  const persisted = await Training.findById(doc._id).lean();
  const a = await request('/training-sessions', A), b = await request('/training-sessions', B);
  const remainsA = String(persisted.userId) === A;
  summary('QD007', { putStatus: put.status, persistedOwner: remainsA ? 'A' : String(persisted.userId) === B ? 'B' : 'other', aStatus: a.status, bStatus: b.status, aCount: a.data.length, bCount: b.data.length });
  assert(remainsA && a.status === 200 && b.status === 200 && a.data.length === 1 && b.data.length === 0, 'Owner changed persistently or visibility crossed');
});
for (const [kind, endpoint, getModel, id] of [
  ['training', '/training-sessions', () => Training, 10], ['angle', '/angle-tests', () => Angle, 20],
]) for (const count of [500, 501]) test(`QD008 ${kind} ${count} complete recovery`, async () => {
  const Model = getModel(), userId = owner(id + (count === 501 ? 1 : 0));
  const docs = Array.from({ length: count }, (_, i) => {
    const time = new Date(Date.UTC(2026, 0, 1) + i * 1000);
    return { userId, clientId: `${kind}-${count}-${i}`, date: time, createdAt: time, updatedAt: time,
      ...(kind === 'angle' ? { actualAngle: 45, userAngle: 40, pocketType: 'corner', quizType: 'table2D' } : {}) };
  });
  await Model.insertMany(docs, { timestamps: false });
  const saved = await Model.find({ userId }).sort({ date: 1 }).lean();
  assert.equal(saved.length, count);
  for (let i = 0; i < count; i++) {
    assert.equal(saved[i].clientId, docs[i].clientId, 'Fixture ID mismatch');
    assert.equal(saved[i].date.getTime(), docs[i].date.getTime(), 'Fixture date changed');
    assert.equal(saved[i].updatedAt.getTime(), docs[i].updatedAt.getTime(), 'Fixture timestamp changed; invalid fixture');
  }
  const first = await request(endpoint, userId); assert.equal(first.status, 200); assert.equal(first.data.length, 500);
  const anchor = new Date(Math.max(...first.data.map(d => Date.parse(d.updatedAt)))).toISOString();
  const second = await request(endpoint + '?after=' + encodeURIComponent(anchor), userId); assert.equal(second.status, 200);
  const actual = new Set([...first.data, ...second.data].map(d => d.clientId));
  const expected = new Set(saved.map(d => d.clientId));
  const missing = [...expected].filter(x => !actual.has(x)); const extra = [...actual].filter(x => !expected.has(x));
  summary(`QD008-${kind}-${count}`, { count, first: first.data.length, after: second.data.length, anchor, recovered: actual.size, missingClientIds: missing, extraClientIds: extra });
  assert.equal(missing.length, 0, 'Recovery omitted persisted records'); assert.equal(extra.length, 0);
});
