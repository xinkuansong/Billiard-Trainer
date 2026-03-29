const express = require("express");
const Drill = require("../models/Drill");

const router = express.Router();

// GET /drills?updatedAfter=ISO8601
// Public endpoint — no auth required
router.get("/", async (req, res, next) => {
  try {
    const filter = {};
    if (req.query.updatedAfter) {
      filter.updatedAt = { $gt: new Date(req.query.updatedAfter) };
    }
    const drills = await Drill.find(filter).lean();
    const result = drills.map((d) => ({ ...d.content, _updatedAt: d.updatedAt }));
    res.json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
