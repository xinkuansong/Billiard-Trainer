const { Types } = require("mongoose");

const PAGE_SIZE = 200;
const invalid = () => Object.assign(new Error("无效的同步分页参数"), { status: 400, statusCode: 400 });
const date = value => {
  if (typeof value !== "string" || !Number.isFinite(Date.parse(value))) throw invalid();
  return new Date(value);
};

// Bound a traversal to server time and order ties by _id. A date-only cursor
// skips records when a batch shares the same updatedAt timestamp.
async function readSyncPage(Model, userId, query) {
  let after = query.after === undefined ? null : date(query.after);
  let through = new Date();
  let last;
  if (query.cursor !== undefined) {
    if (typeof query.cursor !== "string" || query.cursor.length > 2048) throw invalid();
    let cursor;
    try { cursor = JSON.parse(Buffer.from(query.cursor, "base64url").toString("utf8")); }
    catch { throw invalid(); }
    if (!cursor || cursor.v !== 1 || cursor.owner !== String(userId) || cursor.type !== Model.modelName
        || typeof cursor.id !== "string" || !/^[a-f0-9]{24}$/.test(cursor.id)) throw invalid();
    after = cursor.after === null ? null : date(cursor.after);
    through = date(cursor.through);
    last = { at: date(cursor.at), id: new Types.ObjectId(cursor.id) };
    if (last.at > through || (after && last.at <= after)) throw invalid();
  }
  const filter = { userId, updatedAt: { $lte: through, ...(after ? { $gt: after } : {}) } };
  if (last) filter.$or = [
    { updatedAt: { $gt: last.at } },
    { updatedAt: last.at, _id: { $gt: last.id } },
  ];
  const rows = await Model.find(filter).sort({ updatedAt: 1, _id: 1 }).limit(PAGE_SIZE + 1).lean();
  const hasMore = rows.length > PAGE_SIZE;
  const items = rows.slice(0, PAGE_SIZE);
  const end = items.at(-1);
  const nextCursor = hasMore ? Buffer.from(JSON.stringify({
    v: 1, owner: String(userId), type: Model.modelName, after: after?.toISOString() ?? null,
    through: through.toISOString(), at: end.updatedAt.toISOString(), id: String(end._id),
  })).toString("base64url") : null;
  return { items, nextCursor };
}

module.exports = { readSyncPage, PAGE_SIZE };
