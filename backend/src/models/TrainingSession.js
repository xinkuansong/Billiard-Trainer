const mongoose = require("mongoose");

// 客户端 SwiftData V2 起新增的成绩字段（契约 §4.1）必须在此登记：
// mongoose 默认 strict: true 会静默丢弃未声明字段，缺一行即服务器副本有损。
// 一律给 default、不加 required：客户端 DTO 侧也是 decodeIfPresent + 默认值，
// 两端都容忍缺字段，避免旧客户端写入被整条拒绝。
const drillSetSchema = new mongoose.Schema(
  {
    setNumber: Number,
    targetBalls: Number,
    madeBalls: Number,
    // 球形归属与显示名快照（契约 §4.1 / §6.5）。单球形 drill 为 null。
    formationToken: { type: String, default: null },
    formationName: { type: String, default: null },
    // made/target 的单位语义（契约 §5.2）："球" | "局" | "次"。
    // 丢失会让恢复数据语义错误（「局/次」被当「球」），默认与本地模型一致取 "球"。
    unitLabel: { type: String, default: "球" },
    // 达标线快照（契约 §5.5）。0/0 表示「未设定」。
    passMade: { type: Number, default: 0 },
    passTotal: { type: Number, default: 0 },
    // 每组用时（契约 §8.7）。未采集为 null。
    durationSeconds: { type: Number, default: null },
  },
  { _id: false }
);

const drillEntrySchema = new mongoose.Schema(
  {
    drillId: String,
    drillNameZh: String,
    // 训练内顺序（契约 §4.1）。旧数据统一为 0。
    orderIndex: { type: Number, default: 0 },
    // 该 drill 的训练心得（契约 §8.7）。
    note: { type: String, default: "" },
    // 达标说明快照，人类可读（契约 §6.5：写入即冻结）。
    criteriaText: { type: String, default: "" },
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
    scheduleItemId: { type: String, default: null },
    sourceKind: { type: String, default: null },
    sourceId: { type: String, default: null },
    sourceParentId: { type: String, default: null },
    sourceTitleSnapshot: { type: String, default: null },
    sourceSubtitleSnapshot: { type: String, default: null },
    sourcePayloadVersion: { type: Number, default: null },
    // Swift Codable encodes Data as base64 in JSON. Keep the exact frozen payload opaque.
    sourcePayloadSnapshot: { type: String, default: null },
    progressRole: { type: String, default: null },
    progressEffect: { type: String, default: null },
    lessonId: { type: String, default: null },
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
