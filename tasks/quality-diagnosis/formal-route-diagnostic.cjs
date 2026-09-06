// Frozen-source route diagnostics. Only loopback HTTP and deterministic model doubles.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {once} = require('node:events');
const {createRequire} = require('node:module');
const path = require('node:path');
const fs = require('node:fs');
const root = fs.realpathSync(process.env.QD_BACKEND_ROOT);
assert.ok(root.startsWith('/private/tmp/qd-formal-routes-'));
const req = createRequire(path.join(root, 'diagnostic.cjs'));
for (const dependency of ['express','mongoose','jsonwebtoken']) {
  assert.ok(fs.realpathSync(req.resolve(dependency)).startsWith(root + '/node_modules/'));
}
process.env.JWT_SECRET = 'isolated-quality-diagnostic-access-key';
process.env.JWT_REFRESH_SECRET = 'isolated-quality-diagnostic-refresh-key';
const mongoose = req('mongoose');
mongoose.connect = mongoose.createConnection = () => { throw Error('Database access forbidden in route diagnostic'); };
const express = req('express');
const {signAccessToken} = req('./src/utils/jwt');
const owner = '507f1f77bcf86cd799439011';
const other = '507f1f77bcf86cd799439012';
const headers = {Authorization: `Bearer ${signAccessToken(owner)}`, 'Content-Type': 'application/json'};

for (const [routeName, modelName, routeFile] of [
  ['training-sessions', 'TrainingSession', 'trainingSession'],
  ['angle-tests', 'AngleTest', 'angleTest'],
]) {
  test(routeName + ': authenticated route contract', {timeout: 30000}, async t => {
    const model = req('./src/models/' + modelName);
    let records = [], calls = 0, observedUpdate;
    model.find = filter => {
      calls++;
      let rows = records.filter(r => r.userId === filter.userId &&
        (!filter.updatedAt || r.updatedAt > filter.updatedAt.$gt));
      return {
        sort(spec) { rows.sort((a,b) => (+a.date - +b.date) * spec.date); return this; },
        limit(n) { rows = rows.slice(0,n); return this; },
        async lean() { return rows; },
      };
    };
    model.findOneAndUpdate = async (filter, update) => {
      calls++; observedUpdate = {filter, update};
      const row = records.find(r => r._id === filter._id && r.userId === filter.userId);
      return row ? {...row, ...update} : null;
    };
    for (const name of ['create','deleteOne','deleteMany','updateOne','updateMany','findOne']) {
      model[name] = () => { throw Error('Unexpected model operation: ' + name); };
    }
    const app = express(); app.use(express.json());
    app.use('/' + routeName, req('./src/routes/' + routeFile));
    const server = app.listen(0, '127.0.0.1');
    await once(server, 'listening');
    t.after(() => new Promise(resolve => server.close(resolve)));
    const url = `http://127.0.0.1:${server.address().port}/${routeName}`;
    const populate = (count, ordering = 'aligned') => {
      records = Array.from({length: count}, (_, i) => ({
        _id: String(i), clientId: 'record-' + i, userId: owner,
        date: new Date(Date.UTC(2026,0,1) + (ordering === 'reverse-date' ? -i : i) * 60000),
        updatedAt: new Date(Date.UTC(2026,0,1) + (ordering === 'same-update' ? 0 : i) * 60000),
      }));
      calls = 0; observedUpdate = undefined;
    };
    await t.test('no token rejected without model access', async () => {
      populate(1); assert.equal((await fetch(url)).status, 401); assert.equal(calls, 0);
    });
    await t.test('other owner cannot list these records', async () => {
      populate(1);
      const result = await fetch(url, {headers: {Authorization: `Bearer ${signAccessToken(other)}`}});
      assert.equal(result.status, 200); assert.deepEqual(await result.json(), []);
    });
    if (routeName === 'training-sessions') await t.test('body cannot reassign owner', async () => {
      populate(1);
      const result = await fetch(url + '/0', {method: 'PUT', headers, body: JSON.stringify({userId: other})});
      const body = await result.json();
      if (observedUpdate) assert.equal(observedUpdate.filter.userId, owner);
      assert.ok(result.status >= 400 || body.userId === owner,
        `HTTP ${result.status}: body owner reached update (${body.userId})`);
    });
    for (const [count, ordering] of [[499,'aligned'],[500,'aligned'],[501,'aligned'],[1000,'aligned'],[501,'same-update'],[501,'reverse-date']]) {
      await t.test(`restore completeness ${count}/${ordering}`, async () => {
        populate(count, ordering);
        const response = await fetch(url, {headers}); assert.equal(response.status, 200);
        const first = await response.json();
        const anchor = new Date(Math.max(...first.map(r => +new Date(r.updatedAt))));
        const nextResponse = await fetch(url + '?after=' + encodeURIComponent(anchor.toISOString()), {headers});
        assert.equal(nextResponse.status, 200);
        const next = await nextResponse.json();
        const merged = new Set([...first,...next].map(r => r.clientId));
        const missing = records.filter(r => !merged.has(r.clientId)).map(r => r.clientId);
        t.diagnostic(JSON.stringify({count, ordering, first: first.length, after: next.length,
          unique: merged.size, missingCount: missing.length, missingFirst: missing.slice(0,3)}));
        assert.equal(merged.size, count, 'No paging cursor recovers the missing records; this is route-level, not a real client or Mongo run');
      });
    }
  });
}
