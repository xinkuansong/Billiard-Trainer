const test = require("node:test");
const assert = require("node:assert/strict");
const TrainingSession = require("../src/models/TrainingSession");

test("training session schema preserves v54 provenance fields", () => {
  const payload = {
    clientId: "11111111-2222-3333-4444-555555555555",
    userId: "507f1f77bcf86cd799439011",
    date: new Date("2026-09-03T00:00:00Z"),
    scheduleItemId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    sourceKind: "officialLesson",
    sourceId: "plan_beginner.stage01.lesson01",
    sourceParentId: "plan_beginner",
    sourceTitleSnapshot: "第 1 课",
    sourceSubtitleSnapshot: "基本功 · 第 1 课",
    sourcePayloadVersion: 1,
    sourcePayloadSnapshot: "ZnJvemVu",
    progressRole: "advanceEligible",
    progressEffect: "advanced:1",
    lessonId: "plan_beginner.stage01.lesson01",
  };
  const object = new TrainingSession(payload).toObject();
  for (const key of Object.keys(payload)) {
    if (["date", "userId"].includes(key)) continue;
    assert.equal(object[key], payload[key], `${key} must survive strict mongoose schema`);
  }
});

test("old clients may omit all v54 provenance fields", () => {
  const doc = new TrainingSession({
    clientId: "old-client",
    userId: "507f1f77bcf86cd799439011",
    date: new Date("2026-09-03T00:00:00Z"),
  });
  const error = doc.validateSync();
  assert.equal(error, undefined);
  assert.equal(doc.scheduleItemId, null);
  assert.equal(doc.sourceKind, null);
  assert.equal(doc.progressEffect, null);
});
