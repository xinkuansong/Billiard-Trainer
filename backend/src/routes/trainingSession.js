const express = require("express");
const auth = require("../middleware/auth");
const TrainingSession = require("../models/TrainingSession");

const { withActiveAccount } = require("../services/accountWrite");
const { recordFields, syncFields, saveSyncRecord } = require("../services/syncRecord");

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
    const { record, status } = await saveSyncRecord(TrainingSession, req.userId, req.body);
    res.status(status).json(record);
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
    const ops = items.map(item => {
      const data = syncFields(item);
      return { updateOne: {
        filter: { userId: req.userId, clientId: data.clientId },
        update: { $set: { ...data, userId: req.userId } },
        upsert: true,
      } };
    });
    const result = await withActiveAccount(req.userId, session => TrainingSession.bulkWrite(ops, { session }));
    res.json({ upserted: result.upsertedCount, modified: result.modifiedCount });
  } catch (err) {
    next(err);
  }
});

// DELETE /training-sessions/by-client/:clientId
// 客户端只持有本地 SwiftData UUID（clientId），拿不到 Mongo `_id`，故提供按 clientId
// 的硬删端点（v36 D-v36-2）。注册在 `DELETE /:id` 之前：express 按注册顺序匹配，
// 先注册即可保证不被抢匹配（`/:id` 只匹配单段路径，双段本不冲突，这里是双保险）。
//
// 不存在时同样返回 200：DELETE 语义本就幂等，且「重复删除」「记录从未上传成功过就被删」
// 都是常态；返 404 会被客户端判为 4xx 永久失败 —— 出队结果与成功相同，却白白打一条
// 错误日志。实际删了几条用 deletedCount 表达，调用方需要时可自行区分。
router.delete("/by-client/:clientId", async (req, res, next) => {
  try {
    const result = await TrainingSession.deleteOne({
      userId: req.userId,
      clientId: req.params.clientId,
    });
    res.json({ message: "Deleted", deletedCount: result.deletedCount });
  } catch (err) {
    next(err);
  }
});

// PUT /training-sessions/:id
router.put("/:id", async (req, res, next) => {
  try {
    if (req.body?.userId !== undefined && req.body.userId !== req.userId) {
      return res.status(400).json({ message: "记录归属不能修改" });
    }
    const fields = recordFields(req.body);
    const record = await withActiveAccount(req.userId, session => TrainingSession.findOneAndUpdate(
      { _id: req.params.id, userId: req.userId },
      { $set: fields },
      { new: true, session }
    ));
    if (!record) return res.status(404).json({ message: "Not found" });
    res.json(record);
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
