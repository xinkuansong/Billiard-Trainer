const mongoose = require("mongoose");

const angleTestSchema = new mongoose.Schema(
  {
    clientId: { type: String, required: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    date: { type: Date, required: true },
    actualAngle: { type: Number, required: true },
    userAngle: { type: Number, required: true },
    pocketType: { type: String, required: true },
  },
  { timestamps: true }
);

angleTestSchema.index({ userId: 1, updatedAt: 1 });
angleTestSchema.index({ userId: 1, clientId: 1 }, { unique: true });

module.exports = mongoose.model("AngleTest", angleTestSchema);
