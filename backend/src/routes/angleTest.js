const express = require("express");
const auth = require("../middleware/auth");
const AngleTest = require("../models/AngleTest");

const { saveSyncRecord } = require("../services/syncRecord");
const { readSyncPage } = require("../services/syncPage");

const router = express.Router();
router.use(auth);

// GET /angle-tests?after=ISO8601
router.get("/", async (req, res, next) => {
  try {
    if (req.query.page === "1") return res.json(await readSyncPage(AngleTest, req.userId, req.query));
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
    const { record, status } = await saveSyncRecord(AngleTest, req.userId, req.body);
    res.status(status).json(record);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
