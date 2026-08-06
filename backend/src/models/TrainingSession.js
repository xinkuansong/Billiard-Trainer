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
    // 会话分类（契约 §5.3）："drill" 真实球台成绩 / "cognitive" 屏内认知测验 / "tool" 工具活跃度。
    // mongoose 默认 strict: true 会丢弃未声明字段，缺这行客户端上传的 kind 会被静默吞掉。
    // 不用 enum 约束：客户端 schema 里 kind 是 String，未知取值应原样存下而不是整条写入失败。
    kind: { type: String, default: "drill", index: true },
    drillEntries: [drillEntrySchema],
  },
  { timestamps: true }
);

trainingSessionSchema.index({ userId: 1, updatedAt: 1 });
trainingSessionSchema.index({ userId: 1, clientId: 1 }, { unique: true });

module.exports = mongoose.model("TrainingSession", trainingSessionSchema);
