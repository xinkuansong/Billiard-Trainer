const test = require("node:test");
const assert = require("node:assert/strict");

const {
  normalizeDisplayName,
  serializeUser,
  validateProfileUpdate,
} = require("../src/services/userProfile");

test("serializeUser always exposes the public DTO shape and string id", () => {
  assert.deepEqual(
    serializeUser({ _id: 123, provider: "apple", displayName: "小王", email: undefined }),
    {
      id: "123",
      displayName: "小王",
      email: null,
      provider: "apple",
      avatarRevision: null,
      preferredSport: null,
      skillLevel: null,
      yearsPlaying: null,
      weeklyGoalDays: null,
    }
  );
});

test("serializeUser normalizes early years-playing aliases to the public DTO", () => {
  assert.equal(serializeUser({ id: "1", provider: "apple", yearsPlaying: "oneTo3" }).yearsPlaying,
    "oneToThree");
  assert.equal(serializeUser({ id: "1", provider: "apple", yearsPlaying: "threeTo5" }).yearsPlaying,
    "threeToFive");
  assert.equal(serializeUser({ id: "1", provider: "apple", yearsPlaying: "moreThan5" }).yearsPlaying,
    "fivePlus");
});

test("normalizeDisplayName trims and counts Unicode characters", () => {
  assert.equal(normalizeDisplayName("  台球小王子  "), "台球小王子");
  assert.throws(() => normalizeDisplayName("   "), /1–20/);
  assert.throws(() => normalizeDisplayName("球".repeat(21)), /1–20/);
});

test("validateProfileUpdate accepts partial updates without clearing other fields", () => {
  assert.deepEqual(validateProfileUpdate({ displayName: "  球徒  ", weeklyGoalDays: 4 }), {
    displayName: "球徒",
    weeklyGoalDays: 4,
  });
});

test("validateProfileUpdate rejects unknown, enum and range values", () => {
  assert.throws(() => validateProfileUpdate({ targetSessionMinutes: 30 }), /不支持/);
  assert.throws(() => validateProfileUpdate({ preferredSport: "snooker" }), /取值无效/);
  assert.throws(() => validateProfileUpdate({ weeklyGoalDays: 0 }), /1–7/);
  assert.throws(() => validateProfileUpdate({}), /没有可更新/);
  assert.throws(() => validateProfileUpdate({ yearsPlaying: "threeTo5" }), /取值无效/);
});
