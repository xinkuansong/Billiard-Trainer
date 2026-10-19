const assert = require('node:assert/strict');
const test = require('node:test');
const { randomUUID } = require('node:crypto');
const { validateMutation } = require('../src/services/customFormation');
function fixture() {
  const id = randomUUID(), keys = [1,1].map(n => `_${n}@${randomUUID()}`);
  const a = { id: randomUUID(), x: -0.5, z: 0 }, b = { id: randomUUID(), x: 0.5, z: 0 };
  return { id, body: { operationId: randomUUID(), baseRevision: 0, schemaVersion: 1,
    template: { id, name: '重复球', updatedAt: new Date().toISOString(), ballKeys: keys,
      board: { onTable: { cueBall: { x: .2, y: .4 }, [keys[0]]: { x: .3, y: .25 }, [keys[1]]: { x: .7, y: .25 } } },
      drawing: { vertices: [a,b], lines: [{ id: randomUUID(), start: a.id, end: b.id, balls: keys }] } } } };
}
test('duplicate numbers retain independent identities and line order', () => {
  const { id, body } = fixture(); const input = validateMutation(id, body, false);
  assert.deepEqual(input.template, body.template);
});
test('reordered JSON properties retain idempotency digest', () => {
  const { id, body } = fixture(); const digest = validateMutation(id, body, false).digest;
  const t = body.template; body.template = Object.fromEntries(Object.entries(t).reverse());
  assert.equal(validateMutation(id, body, false).digest, digest);
});
for (const [name, corrupt] of [
  ['26 targets', t => { while (t.ballKeys.length < 26) { const k = `_1@${randomUUID()}`; t.ballKeys.push(k); t.board.onTable[k] = {x:.5,y:.25}; } }],
  ['duplicate identity', t => t.ballKeys[1] = t.ballKeys[0]],
  ['missing cue', t => delete t.board.onTable.cueBall],
  ['off table', t => t.board.onTable.cueBall.x = 1.1],
  ['nonfinite coordinate', t => t.board.onTable.cueBall.x = NaN],
  ['null vertex', t => t.drawing.vertices[0] = null],
  ['null line', t => t.drawing.lines[0] = null],
  ['unknown line endpoint', t => t.drawing.lines[0].end = randomUUID()],
  ['unknown line ball', t => t.drawing.lines[0].balls.push('missing')],
  ['empty name', t => t.name = ' '],
  ['long name', t => t.name = '球'.repeat(121)],
]) test(`rejects ${name}`, () => {
  const { id, body } = fixture(); corrupt(body.template);
  assert.throws(() => validateMutation(id, body, false), e => e.status === 422);
});
test('25 targets plus one cue is allowed', () => {
  const { id, body } = fixture(); while (body.template.ballKeys.length < 25) {
    const k = `_1@${randomUUID()}`; body.template.ballKeys.push(k); body.template.board.onTable[k] = {x:.5,y:.25};
  }
  assert.doesNotThrow(() => validateMutation(id, body, false));
});
test('schema and revision are explicit', () => {
  const { id, body } = fixture(); body.baseRevision = -1;
  assert.throws(() => validateMutation(id, body, false)); body.baseRevision = 0; body.schemaVersion = 2;
  assert.throws(() => validateMutation(id, body, false));
});
module.exports = { fixture };
