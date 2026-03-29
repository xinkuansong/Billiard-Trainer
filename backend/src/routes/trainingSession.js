const express = require("express");
const auth = require("../middleware/auth");
const TrainingSession = require("../models/TrainingSession");

const router = express.Router();
router.use(auth);

// GET /training-sessions?after=ISO8601
router.get("/", async (req, res, next) => {
  try {
    const filter = { userId: req.userId };
    if (req.query.after) {
      filter.updatedAt = { $gt: new Date(req.query.after) };
    }
    const sessions = await TrainingSession.find(filter)
      .sort({ date: -1 })
      .limit(500)
      .lean();
    res.json(sessions);
  } catch (err) {
    next(err);
  }
});

// POST /training-sessions
router.post("/", async (req, res, next) => {
  try {
    const data = { ...req.body, userId: req.userId };
    const existing = await TrainingSession.findOne({ userId: req.userId, clientId: data.clientId });
    if (existing) {
      Object.assign(existing, data);
      await existing.save();
      return res.json(existing);
    }
    const session = await TrainingSession.create(data);
    res.status(201).json(session);
  } catch (err) {
    next(err);
  }
});

// POST /training-sessions/batch
router.post("/batch", async (req, res, next) => {
  try {
    const items = req.body;
    if (!Array.isArray(items)) {
      return res.status(400).json({ message: "Body must be an array" });
    }
    const ops = items.map((item) => ({
      updateOne: {
        filter: { userId: req.userId, clientId: item.clientId },
        update: { $set: { ...item, userId: req.userId } },
        upsert: true,
      },
    }));
    const result = await TrainingSession.bulkWrite(ops);
    res.json({ upserted: result.upsertedCount, modified: result.modifiedCount });
  } catch (err) {
    next(err);
  }
});

// PUT /training-sessions/:id
router.put("/:id", async (req, res, next) => {
  try {
    const session = await TrainingSession.findOneAndUpdate(
      { _id: req.params.id, userId: req.userId },
      req.body,
      { new: true }
    );
    if (!session) return res.status(404).json({ message: "Not found" });
    res.json(session);
  } catch (err) {
    next(err);
  }
});

// DELETE /training-sessions/:id
router.delete("/:id", async (req, res, next) => {
  try {
    const result = await TrainingSession.findOneAndDelete({
      _id: req.params.id,
      userId: req.userId,
    });
    if (!result) return res.status(404).json({ message: "Not found" });
    res.json({ message: "Deleted" });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
