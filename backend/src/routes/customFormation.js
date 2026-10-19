const express = require("express");
const auth = require("../middleware/auth");
const service = require("../services/customFormation");
const router = express.Router();
router.use(auth);
router.get("/", async (req, res, next) => {
  try { res.json(await service.changes(req.userId, req.query)); } catch (error) { next(error); }
});
for (const [method, deleted] of [["put", false], ["delete", true]]) {
  router[method]("/:clientId", async (req, res, next) => {
    try { res.json(await service.mutate(req.userId, service.validateMutation(req.params.clientId, req.body, deleted))); }
    catch (error) { next(error); }
  });
}
module.exports = router;
