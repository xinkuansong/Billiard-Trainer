const mongoose = require("mongoose");
const schema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  clientId: { type: String, required: true },
  revision: { type: Number, required: true },
  deleted: { type: Boolean, required: true },
  schemaVersion: { type: Number, required: true },
  template: mongoose.Schema.Types.Mixed,
  modifiedAt: { type: Date, required: true },
});
schema.index({ userId: 1, clientId: 1 }, { unique: true });
const changeSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, required: true },
  sequence: { type: Number, required: true },
  operationId: { type: String, required: true },
  digest: { type: String, required: true },
  record: { type: mongoose.Schema.Types.Mixed, required: true },
});
changeSchema.index({ userId: 1, sequence: 1 }, { unique: true });
changeSchema.index({ userId: 1, operationId: 1 }, { unique: true });
module.exports = {
  CustomFormation: mongoose.model("CustomFormation", schema),
  FormationChange: mongoose.model("FormationChange", changeSchema),
};
