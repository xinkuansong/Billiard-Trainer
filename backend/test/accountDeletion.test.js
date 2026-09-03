const assert = require("node:assert/strict");
const test = require("node:test");
const { deleteAccountData } = require("../src/services/accountDeletion");

function dependencies(events, avatarRevision = 7) {
  return {
    findUser: async (userId) => {
      events.push(`find:${userId}`);
      return { avatarRevision };
    },
    deleteAvatar: async (directory, userId, revision) => {
      events.push(`avatar:${directory}:${userId}:${revision}`);
    },
    deleteTrainingSessions: async (userId) => events.push(`training:${userId}`),
    deleteAngleTests: async (userId) => events.push(`angles:${userId}`),
    deleteUser: async (userId) => events.push(`user:${userId}`),
  };
}

test("account deletion removes avatar before deleting database ownership", async () => {
  const events = [];
  await deleteAccountData("user-a", "/avatars", dependencies(events));
  assert.deepEqual(events.slice(0, 2), ["find:user-a", "avatar:/avatars:user-a:7"]);
  assert.deepEqual(new Set(events.slice(2)), new Set([
    "training:user-a", "angles:user-a", "user:user-a",
  ]));
});

test("avatar storage failure keeps database records retryable", async () => {
  const events = [];
  const deps = dependencies(events);
  deps.deleteAvatar = async () => {
    events.push("avatar:failed");
    throw new Error("storage unavailable");
  };

  await assert.rejects(deleteAccountData("user-a", "/avatars", deps), /storage unavailable/);
  assert.deepEqual(events, ["find:user-a", "avatar:failed"]);
});
