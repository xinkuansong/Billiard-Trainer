const express = require("express");
const config = require("../config");
const auth = require("../middleware/auth");
const User = require("../models/User");
const { serializeUser, validateProfileUpdate } = require("../services/userProfile");
const { deleteAvatar, readAvatar, writeAvatar } = require("../services/avatarStorage");
const { deleteAccountData } = require("../services/accountDeletion");

const router = express.Router();
router.use(auth);

// GET /user/profile
router.get("/profile", async (req, res, next) => {
  try {
    const user = await User.findById(req.userId).select("-refreshToken").lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(serializeUser(user));
  } catch (err) {
    next(err);
  }
});

// PUT /user/profile
router.put("/profile", async (req, res, next) => {
  try {
    const update = validateProfileUpdate(req.body);
    const user = await User.findByIdAndUpdate(req.userId, update, { new: true, runValidators: true })
      .select("-refreshToken")
      .lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(serializeUser(user));
  } catch (err) {
    next(err);
  }
});

// PUT /user/avatar — client sends a normalized JPEG body (max 1 MiB).
router.put("/avatar", express.raw({ type: "image/jpeg", limit: "1mb" }), async (req, res, next) => {
  let newRevision;
  try {
    const current = await User.findById(req.userId).select("avatarRevision").lean();
    if (!current) return res.status(404).json({ message: "User not found" });

    const oldRevision = current.avatarRevision ?? null;
    newRevision = (oldRevision ?? 0) + 1;
    await writeAvatar(config.avatarStorageDir, req.userId, newRevision, req.body);

    const user = await User.findByIdAndUpdate(
      req.userId,
      { $set: { avatarRevision: newRevision } },
      { new: true, runValidators: true }
    ).select("-refreshToken").lean();
    if (!user) {
      await deleteAvatar(config.avatarStorageDir, req.userId, newRevision);
      return res.status(404).json({ message: "User not found" });
    }
    await deleteAvatar(config.avatarStorageDir, req.userId, oldRevision);
    res.json(serializeUser(user));
  } catch (err) {
    if (newRevision) {
      await deleteAvatar(config.avatarStorageDir, req.userId, newRevision).catch(() => {});
    }
    next(err);
  }
});

// GET /user/avatar — private avatar for the currently authenticated account.
router.get("/avatar", async (req, res, next) => {
  try {
    const user = await User.findById(req.userId).select("avatarRevision").lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    if (!user.avatarRevision) return res.status(404).json({ message: "Avatar not found" });
    const data = await readAvatar(config.avatarStorageDir, req.userId, user.avatarRevision);
    res.set("Content-Type", "image/jpeg");
    res.set("Cache-Control", "private, max-age=31536000, immutable");
    res.send(data);
  } catch (err) {
    if (err.code === "ENOENT") return res.status(404).json({ message: "Avatar not found" });
    next(err);
  }
});

// DELETE /user/avatar
router.delete("/avatar", async (req, res, next) => {
  try {
    const user = await User.findByIdAndUpdate(
      req.userId,
      { $unset: { avatarRevision: 1 } },
      { new: false }
    ).lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    await deleteAvatar(config.avatarStorageDir, req.userId, user.avatarRevision);
    const updated = await User.findById(req.userId).select("-refreshToken").lean();
    res.json(serializeUser(updated));
  } catch (err) {
    next(err);
  }
});

// DELETE /user/account (PIPL: delete all user data)
router.delete("/account", async (req, res, next) => {
  try {
    await deleteAccountData(req.userId, config.avatarStorageDir);
    res.json({ message: "账号及所有数据已删除" });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
