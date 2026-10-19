const crypto = require("node:crypto");
const mongoose = require("mongoose");
const User = require("../models/User");
const { CustomFormation, FormationChange } = require("../models/CustomFormation");
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BALL = /^_(?:[1-9]|1[0-5])@[0-9a-f-]{36}$/i;
function fail(message, status = 422) { throw Object.assign(new Error(message), { status }); }
const object = v => v !== null && typeof v === "object" && !Array.isArray(v);
const finite = v => typeof v === "number" && Number.isFinite(v);
function validateTemplate(t, id) {
  if (!object(t) || t.id?.toLowerCase() !== id || !UUID.test(t.id)) fail("球形标识无效");
  if (typeof t.name !== "string" || !t.name.trim() || [...t.name].length > 120) fail("模板名称须为1至120字");
  if (typeof t.updatedAt !== "string" || !Number.isFinite(Date.parse(t.updatedAt))) fail("修改时间无效");
  const keys = t.ballKeys;
  if (!Array.isArray(keys) || keys.length < 1 || keys.length > 25 || new Set(keys).size !== keys.length ||
      keys.some(k => typeof k !== "string" || !BALL.test(k) || !UUID.test(k.split("@")[1]))) fail("最多25颗目标球，球实例不能重复");
  const positions = t.board?.onTable;
  const expected = new Set([...keys, "cueBall"]);
  if (!object(positions) || Object.keys(positions).length !== expected.size ||
      Object.entries(positions).some(([k,p]) => !expected.has(k) || !object(p) || !finite(p.x) || !finite(p.y) || p.x < 0 || p.x > 1 || p.y < 0 || p.y > .5)) fail("球位无效");
  if (t.drawing != null) {
    if (!object(t.drawing)) fail("辅助线数据无效");
    const { vertices, lines } = t.drawing;
    if (!Array.isArray(vertices) || !Array.isArray(lines) || vertices.length > 512 || lines.length > 256 || vertices.some(v => !object(v)) || lines.some(l => !object(l))) fail("最多256条辅助线和512个端点");
    const ids = new Set(vertices.map(v => v.id));
    if (ids.size !== vertices.length || vertices.some(v => !UUID.test(v.id) || !finite(v.x) || !finite(v.z) || Math.abs(v.x) > 1.270001 || Math.abs(v.z) > .635001)) fail("辅助线端点无效");
    if (new Set(lines.map(l => l.id)).size !== lines.length || lines.some(l => !UUID.test(l.id) || l.start === l.end || !ids.has(l.start) || !ids.has(l.end) || !Array.isArray(l.balls) || new Set(l.balls).size !== l.balls.length || l.balls.some(k => !expected.has(k)))) fail("辅助线关联无效");
  }
  if (Buffer.byteLength(JSON.stringify(t)) > 262144) fail("球形数据超过256KB");
  return t;
}
function canonical(v) {
  if (Array.isArray(v)) return v.map(canonical);
  if (object(v)) return Object.fromEntries(Object.keys(v).sort().map(k => [k, canonical(v[k])]));
  return v;
}
function validateMutation(id, body, deleted) {
  if (!UUID.test(id) || !object(body) || !UUID.test(body.operationId) || !Number.isSafeInteger(body.baseRevision) || body.baseRevision < 0 || body.schemaVersion !== 1) fail("同步请求格式无效");
  const clientId = id.toLowerCase();
  const template = deleted ? null : validateTemplate(body.template, clientId);
  const operationId = body.operationId.toLowerCase();
  const digest = crypto.createHash("sha256").update(JSON.stringify(canonical({ clientId, deleted, template, baseRevision: body.baseRevision, schemaVersion: 1 }))).digest("hex");
  return { clientId, template, operationId, digest, baseRevision: body.baseRevision, deleted };
}
function recordOf(row) {
  return { clientId: row.clientId, revision: row.revision, deleted: row.deleted,
    schemaVersion: row.schemaVersion, template: row.template ?? null, modifiedAt: row.modifiedAt };
}
async function mutate(userId, input) {
  // Counter, content, receipt and change are one transaction. A standalone MongoDB
  // cannot provide this contract; fail closed rather than acknowledge a partial write.
  return mongoose.connection.transaction(async session => {
    const user = await User.findOneAndUpdate({ _id: userId, deletionPending: { $ne: true } },
      { $inc: { formationSequence: 1 } }, { new: true, session }).lean();
    if (!user) fail("账号不可用", 401);
    const receipt = await FormationChange.findOne({ userId, operationId: input.operationId }).session(session).lean();
    if (receipt) {
      if (receipt.digest !== input.digest) fail("同步操作标识已用于其他内容", 409);
      // Counter gaps are harmless; all published changes remain ordered by commit.
      return { conflict: false, record: receipt.record };
    }
    const current = await CustomFormation.findOne({ userId, clientId: input.clientId }).session(session).lean();
    if ((current?.revision ?? 0) !== input.baseRevision || (current?.deleted && !input.deleted)) {
      return { conflict: true, record: current ? recordOf(current) : null };
    }
    const record = { clientId: input.clientId, revision: (current?.revision ?? 0) + 1,
      deleted: input.deleted, schemaVersion: 1, template: input.template, modifiedAt: new Date() };
    await CustomFormation.updateOne({ userId, clientId: input.clientId }, { $set: record }, { upsert: true, session });
    await FormationChange.create([{ userId, sequence: user.formationSequence, operationId: input.operationId, digest: input.digest, record }], { session });
    return { conflict: false, record };
  });
}
async function changes(userId, query) {
  const after = Number(query.after ?? 0);
  const supplied = query.through === undefined ? null : Number(query.through);
  if (!Number.isSafeInteger(after) || after < 0 || (supplied !== null && (!Number.isSafeInteger(supplied) || supplied < after))) fail("同步游标无效", 400);
  const user = await User.findOne({ _id: userId, deletionPending: { $ne: true } }).lean();
  if (!user) fail("账号不可用", 401);
  const maximum = user.formationSequence ?? 0;
  const through = supplied ?? maximum;
  if (through > maximum || after > maximum) fail("同步游标超出范围", 400);
  const rows = await FormationChange.find({ userId, sequence: { $gt: after, $lte: through } }).sort({ sequence: 1 }).limit(100).lean();
  const next = rows.length === 100 ? rows.at(-1).sequence : through;
  return { records: rows.map(r => r.record), next, through, hasMore: next < through };
}
module.exports = { validateTemplate, validateMutation, mutate, changes };
