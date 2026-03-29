const mongoose = require("mongoose");

const drillSchema = new mongoose.Schema(
  {
    drillId: { type: String, unique: true, required: true },
    content: { type: mongoose.Schema.Types.Mixed, required: true },
  },
  { timestamps: true }
);

drillSchema.index({ updatedAt: 1 });

module.exports = mongoose.model("Drill", drillSchema);
