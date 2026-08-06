const mongoose = require("mongoose");

const angleTestSchema = new mongoose.Schema(
  {
    clientId: { type: String, required: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    date: { type: Date, required: true },
    actualAngle: { type: Number, required: true },
    userAngle: { type: Number, required: true },
    pocketType: { type: String, required: true },
    // 契约 §8.13：题型与毫米误差此前未上传，服务端无法区分角度类与瞄准点类成绩。
    // mongoose 默认 strict: true 会丢弃未声明字段，故必须在此登记。
    quizType: { type: String, default: "table2D", index: true },
    errorMM: { type: Number, default: 0 },
    // 归属的 kind="cognitive" 会话 clientId（契约 §5.3）。
    sessionId: String,
  },
  { timestamps: true }
);

angleTestSchema.index({ userId: 1, updatedAt: 1 });
angleTestSchema.index({ userId: 1, clientId: 1 }, { unique: true });

module.exports = mongoose.model("AngleTest", angleTestSchema);
