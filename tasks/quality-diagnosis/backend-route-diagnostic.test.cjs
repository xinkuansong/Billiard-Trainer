// Diagnostic-only HTTP routes, with deterministic in-memory model doubles.
// No MongoDB connection, real account, or product writes.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
process.env.JWT_SECRET = 'quality-diagnostic-only-access-key';
process.env.JWT_REFRESH_SECRET = 'quality-diagnostic-only-refresh-key';
const express = require('../../backend/node_modules/express');
const model = require('../../backend/src/models/TrainingSession');
const { signAccessToken } = require('../../backend/src/utils/jwt');
const routes = require('../../backend/src/routes/trainingSession');

test('isolated authenticated training routes', async t => {
  const owner = '507f1f77bcf86cd799439011';
  const other = '507f1f77bcf86cd799439012';
  const records = Array.from({ length: 501 }, (_, i) => ({
    _id: String(i), clientId: `record-${i}`, userId: owner,
    date: new Date(2026, 0, 1, 0, i), updatedAt: new Date(2026, 0, 1, 0, i),
  }));
  let observedUpdate;
  model.find = filter => {
    let rows = records.filter(r => r.userId === filter.userId &&
      (!filter.updatedAt || r.updatedAt > filter.updatedAt.$gt));
    return {
      sort(spec) { rows.sort((a,b) => (a.date - b.date) * spec.date); return this; },
      limit(n) { rows = rows.slice(0,n); return this; },
      async lean() { return rows; },
    };
  };
  model.findOneAndUpdate = async (filter, update) => {
    observedUpdate = { filter, update };
    const record = records.find(r => r._id === filter._id && r.userId === filter.userId);
    return record ? { ...record, ...update } : null;
  };
  const app = express();
  app.use(express.json());
  app.use('/training-sessions', routes);
  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/training-sessions`;
  const headers = { Authorization: `Bearer ${signAccessToken(owner)}`, 'Content-Type':'application/json' };

  await t.test('unauthenticated request rejected before model access', async () => {
    assert.equal((await fetch(url)).status, 401);
  });
  await t.test('a different owner receives no records', async () => {
    const res = await fetch(url, { headers: { Authorization: `Bearer ${signAccessToken(other)}` } });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), []);
  });
  await t.test('PUT cannot change record owner through body', async () => {
    const res = await fetch(url+'/0', { method:'PUT', headers, body:JSON.stringify({userId:other}) });
    assert.equal(observedUpdate.filter.userId, owner);
    const body = await res.json();
    // Safe outcomes: reject mutation or return original ownership.
    assert.ok(res.status >= 400 || body.userId === owner,
      `owner supplied in body reached update; HTTP ${res.status}, returned owner ${body.userId}`);
  });
  await t.test('full restore plus after-anchor requests can retrieve all 501 records', async () => {
    const first = await (await fetch(url, {headers})).json();
    const anchor = new Date(Math.max(...first.map(r => +new Date(r.updatedAt))));
    const next = await (await fetch(url+'?after='+encodeURIComponent(anchor.toISOString()), {headers})).json();
    assert.equal(new Set([...first,...next].map(r => r.clientId)).size, records.length,
      `first=${first.length}, after=${next.length}; truncated rows have no cursor to retrieve them`);
  });
});
