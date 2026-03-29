const express = require("express");
const auth = require("../middleware/auth");
const AngleTest = require("../models/AngleTest");

const router = express.Router();
router.use(auth);

// GET /angle-tests?after=ISO8601
router.get("/", async (req, res, next) => {
  try {
    const filter = { userId: req.userId };
    if (req.query.after) {
      filter.updatedAt = { $gt: new Date(req.query.after) };
    }
    const tests = await AngleTest.find(filter)
      .sort({ date: -1 })
      .limit(500)
      .lean();
    res.json(tests);
  } catch (err) {
    next(err);
  }
});

// POST /angle-tests
router.post("/", async (req, res, next) => {
  try {
    const data = { ...req.body, userId: req.userId };
    const existing = await AngleTest.findOne({ userId: req.userId, clientId: data.clientId });
    if (existing) {
      Object.assign(existing, data);
      await existing.save();
      return res.json(existing);
    }
    const test = await AngleTest.create(data);
    res.status(201).json(test);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
