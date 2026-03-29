const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    appleUserId: { type: String, unique: true, sparse: true },
    displayName: String,
    email: String,
    provider: { type: String, enum: ["apple", "phone", "wechat"], required: true },
    refreshToken: String,
  },
  { timestamps: true }
);

module.exports = mongoose.model("User", userSchema);
