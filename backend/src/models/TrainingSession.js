const mongoose = require("mongoose");

const drillSetSchema = new mongoose.Schema(
  {
    setNumber: Number,
    targetBalls: Number,
    madeBalls: Number,
  },
  { _id: false }
);

const drillEntrySchema = new mongoose.Schema(
  {
    drillId: String,
    drillNameZh: String,
    sets: [drillSetSchema],
  },
  { _id: false }
);

const trainingSessionSchema = new mongoose.Schema(
  {
    clientId: { type: String, required: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    date: { type: Date, required: true },
    ballType: { type: String, default: "chinese8" },
    totalDurationMinutes: { type: Number, default: 0 },
    note: { type: String, default: "" },
    planId: String,
    drillEntries: [drillEntrySchema],
  },
  { timestamps: true }
);

trainingSessionSchema.index({ userId: 1, updatedAt: 1 });
trainingSessionSchema.index({ userId: 1, clientId: 1 }, { unique: true });

module.exports = mongoose.model("TrainingSession", trainingSessionSchema);
