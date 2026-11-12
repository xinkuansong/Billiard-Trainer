const express = require("express");
const config = require("../config");
const auth = require("../middleware/auth");
const User = require("../models/User");
const { serializeUser, validateProfileUpdate, initialProfileImportPipeline } = require("../services/userProfile");
const { deleteAvatar, readAvatar, writeAvatar } = require("../services/avatarStorage");
const { deleteAccountData } = require("../services/accountDeletion");

const { activeAccount, withActiveAccount } = require("../services/accountWrite");

const router = express.Router();
// DELETE /user/account (PIPL: delete all user data)
router.delete("/account", auth.verifiedToken, async (req, res, next) => {
  try {
    const appleRevocation = await deleteAccountData(req.userId, config.avatarStorageDir);
    const pending = appleRevocation === "pending";
    res.status(pending ? 202 : 200).json({ appleRevocation,
      message: pending ? "云端训练数据已删除，Apple 授权撤销将在后台重试" : "账号及云端数据已删除",
    });
  } catch (err) {
    next(err);
  }
});

router.use(auth);

// GET /user/profile
router.get("/profile", async (req, res, next) => {
  try {
    const user = await User.findOne(activeAccount(req.userId)).select("-refreshToken").lean();
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
    const user = await User.findOneAndUpdate(activeAccount(req.userId), update, { new: true, runValidators: true })
      .select("-refreshToken")
      .lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(serializeUser(user));
  } catch (err) {
    next(err);
  }
});

// POST /user/profile/import-initial — explicit consent, atomic fill-only write.
router.post("/profile/import-initial", async (req, res, next) => {
  try {
    const pipeline = initialProfileImportPipeline(req.body, req.userId);
    const user = await User.findOneAndUpdate(activeAccount(req.userId), pipeline, { new: true })
      .select("-refreshToken").lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(serializeUser(user));
  } catch (err) { next(err); }
});

// PUT /user/avatar — client sends a normalized JPEG body (max 1 MiB).
router.put("/avatar", express.raw({ type: "image/jpeg", limit: "1mb" }), async (req, res, next) => {
  try {
    const { oldRevision, updated } = await withActiveAccount(req.userId, async (session, user) => {
      const oldRevision = user.avatarRevision;
      const revision = Math.max(user.avatarSequence || 0, oldRevision || 0) + 1;
      await writeAvatar(config.avatarStorageDir, req.userId, revision, req.body);
      const updated = await User.findByIdAndUpdate(req.userId,
        { $set: { avatarRevision: revision, avatarSequence: revision } },
        { new: true, runValidators: true, session }).lean();
      return { oldRevision, updated };
    });
    await deleteAvatar(config.avatarStorageDir, req.userId, oldRevision);
    res.json(serializeUser(updated));
  } catch (err) {
    next(err);
  }
});

// GET /user/avatar — private avatar for the currently authenticated account.
router.get("/avatar", async (req, res, next) => {
  try {
    const user = await User.findOne(activeAccount(req.userId)).select("avatarRevision").lean();
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
    const before = await User.findOneAndUpdate(activeAccount(req.userId),
      [{ $set: { avatarSequence: { $max: ["$avatarSequence", "$avatarRevision", 0] } } },
       { $unset: "avatarRevision" }], { new: false }).lean();
    if (!before) return res.status(401).json({ message: "账号不可用" });
    await deleteAvatar(config.avatarStorageDir, req.userId, before.avatarRevision);
    const updated = { ...before, avatarRevision: null };
    res.json(serializeUser(updated));
  } catch (err) {
    next(err);
  }
});

module.exports = router;
