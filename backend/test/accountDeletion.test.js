const assert = require("node:assert/strict");
const test = require("node:test");
const { deleteAccountData } = require("../src/services/accountDeletion");

function dependencies(events) {
  return {
    recordDeletion: async (id, phase) => events.push(phase + ":" + id),
    deleteAvatars: async (directory, userId) => {
      events.push(`avatar:${directory}:${userId}`);
    },
    deleteTrainingSessions: async (userId) => events.push(`training:${userId}`),
    deleteAngleTests: async (userId) => events.push(`angles:${userId}`),
    markDeleting: async (userId) => events.push(`deleting:${userId}`),
    deleteFormations: async (userId) => events.push(`formations:${userId}`),
    deleteUser: async (userId) => events.push(`user:${userId}`),
  };
}

test("account deletion marks first and keeps the owner until cleanup finishes", async () => {
  const events = [];
  await deleteAccountData("user-a", "/avatars", dependencies(events));
  assert.deepEqual(events, [
    "requested:user-a", "deleting:user-a", "avatar:/avatars:user-a", "formations:user-a",
    "training:user-a", "angles:user-a", "user:user-a", "completed:user-a",
  ]);
});

test("avatar storage failure keeps database records retryable", async () => {
  const events = [];
  const deps = dependencies(events);
  deps.deleteAvatars = async () => {
    events.push("avatar:failed");
    throw new Error("storage unavailable");
  };

  await assert.rejects(deleteAccountData("user-a", "/avatars", deps), /storage unavailable/);
  assert.deepEqual(events, ["requested:user-a", "deleting:user-a", "avatar:failed"]);
});


test("template cleanup failure retains account for retry", async () => {
  const events = [], deps = dependencies(events);
  deps.deleteFormations = async () => { throw new Error("template storage unavailable"); };
  await assert.rejects(deleteAccountData("user-a", "/avatars", deps), /template storage unavailable/);
  assert.equal(events.includes("deleting:user-a"), true);
  assert.equal(events.includes("user:user-a"), false);
});

test("deletion journal failure cannot acknowledge or begin data removal", async () => {
  const events = [];
  const deps = dependencies(events);
  deps.recordDeletion = async () => { throw new Error("journal unavailable"); };
  await assert.rejects(deleteAccountData("user-a", "/avatars", deps), /journal unavailable/);
  assert.deepEqual(events, []);
});
