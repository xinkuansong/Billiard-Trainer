const { withActiveAccount } = require("./accountWrite");

// Swift clients send field values, never Mongo update instructions.
function recordFields(input) {
  if (!input || Array.isArray(input) || typeof input !== "object" ||
      Object.keys(input).some(key => key.includes(".") || key.startsWith("$") ||
        ["__proto__", "prototype", "constructor"].includes(key))) {
    throw Object.assign(new Error("训练记录格式无效"), { status: 400 });
  }
  const { userId, _id, __v, ...fields } = input;
  return fields;
}

function syncFields(input) {
  const data = recordFields(input);
  if (typeof data.clientId !== "string" || !data.clientId.length) {
    throw Object.assign(new Error("缺少有效的 clientId"), { status: 400 });
  }
  return data;
}

function saveSyncRecord(Model, userId, input) {
  const data = syncFields(input);
  return withActiveAccount(userId, async session => {
    const filter = { userId, clientId: data.clientId };
    const existing = await Model.findOne(filter).session(session);
    const record = existing || new Model(filter);
    record.set(data);
    await record.save({ session });
    return { record, status: existing ? 200 : 201 };
  });
}

module.exports = { recordFields, syncFields, saveSyncRecord };
