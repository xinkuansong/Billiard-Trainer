const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    appleUserId: { type: String, unique: true, sparse: true },
    displayName: String,
    email: String,
    provider: { type: String, enum: ["apple", "phone", "wechat"], required: true },
    avatarRevision: { type: Number, min: 1 },
    preferredSport: { type: String, enum: ["chinese8", "nineBall", "both", "zhuifen", "other"] },
    skillLevel: { type: String, enum: ["beginner", "elementary", "intermediate", "advanced"] },
    // Keep the three v53 early-build aliases readable; all new writes use the iOS/DTO
    // canonical values and serializeUser normalizes old rows on response.
    yearsPlaying: {
      type: String,
      enum: [
        "lessThan1", "oneToThree", "threeToFive", "fivePlus",
        "oneTo3", "threeTo5", "moreThan5",
      ],
    },
    weeklyGoalDays: { type: Number, min: 1, max: 7 },
    gender: { type: String, enum: ["male", "female", null] },
    birthDate: { type: String, default: undefined },
    refreshToken: String,
    formationSequence: { type: Number, default: 0 },
    deletionPending: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model("User", userSchema);
