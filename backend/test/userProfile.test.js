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
      gender: null,
      birthDate: null,
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


test("optional basics support partial updates and explicit clearing", () => {
  assert.deepEqual(validateProfileUpdate({ gender: "female" }), { gender: "female" });
  assert.deepEqual(validateProfileUpdate({ birthDate: "2000-02-29" }), { birthDate: "2000-02-29" });
  assert.deepEqual(validateProfileUpdate({ gender: null, birthDate: null }), { gender: null, birthDate: null });
  const user = serializeUser({ id: "1", gender: "male", birthDate: "2000-02-29" });
  assert.equal(user.gender, "male");
  assert.equal(user.birthDate, "2000-02-29");
});

test("birthday rejects impossible, noncanonical and future dates", () => {
  for (const birthDate of ["2001-02-29", "2000-02-30", "2000-13-01", "2000-2-1", "1899-12-31", "2999-01-01", "", 20000101]) {
    assert.throws(() => validateProfileUpdate({ birthDate }), /有效生日/);
  }
  assert.throws(() => validateProfileUpdate({ gender: "unspecified" }), /性别/);
  assert.deepEqual(validateProfileUpdate({ birthDate: new Date(Date.now() + 14 * 3600000).toISOString().slice(0, 10) }),
    { birthDate: new Date(Date.now() + 14 * 3600000).toISOString().slice(0, 10) });
});


test("onboarding sports retain legacy nineBall and independently accept zhuifen and other", () => {
  for (const preferredSport of ["chinese8", "nineBall", "both", "zhuifen", "other"]) {
    assert.equal(validateProfileUpdate({ preferredSport }).preferredSport, preferredSport);
  }
  assert.throws(() => validateProfileUpdate({ preferredSport: "unknown" }));
});

const { initialProfileImportPipeline } = require('../src/services/userProfile');
test('initial import binds account and accepts only supplied basics', () => {
  assert.throws(() => initialProfileImportPipeline({ accountID: 'B', fields: { gender: 'male' } }, 'A'),
    error => error.status === 409);
  for (const fields of [{}, { displayName: 'name' }, { gender: null }, { birthDate: null },
    { preferredSport: 'invalid' }, { birthDate: '2001-02-29' }, { weeklyGoalDays: 2 }]) {
    assert.throws(() => initialProfileImportPipeline({ accountID: 'A', fields }, 'A'));
  }
  assert.throws(() => initialProfileImportPipeline({ accountID: 'A', fields: { gender: 'male' }, extra: true }, 'A'));
  const pipeline = initialProfileImportPipeline({ accountID: 'A', fields: { preferredSport: 'zhuifen', birthDate: '2000-02-29' } }, 'A');
  assert.deepEqual(pipeline, [{ $set: {
    preferredSport: { $ifNull: ['$preferredSport', { $literal: 'zhuifen' }] },
    birthDate: { $ifNull: ['$birthDate', { $literal: '2000-02-29' }] }
  } }]);
});
