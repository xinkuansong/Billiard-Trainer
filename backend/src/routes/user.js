const express = require("express");
const auth = require("../middleware/auth");
const User = require("../models/User");
const TrainingSession = require("../models/TrainingSession");
const AngleTest = require("../models/AngleTest");

const router = express.Router();
router.use(auth);

// GET /user/profile
router.get("/profile", async (req, res, next) => {
  try {
    const user = await User.findById(req.userId).select("-refreshToken").lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (err) {
    next(err);
  }
});

// PUT /user/profile
router.put("/profile", async (req, res, next) => {
  try {
    const allowed = { displayName: req.body.displayName };
    const user = await User.findByIdAndUpdate(req.userId, allowed, { new: true })
      .select("-refreshToken")
      .lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (err) {
    next(err);
  }
});

// DELETE /user/account (PIPL: delete all user data)
router.delete("/account", async (req, res, next) => {
  try {
    await Promise.all([
      TrainingSession.deleteMany({ userId: req.userId }),
      AngleTest.deleteMany({ userId: req.userId }),
      User.findByIdAndDelete(req.userId),
    ]);
    res.json({ message: "账号及所有数据已删除" });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
