const PROFILE_FIELDS = [
  "displayName",
  "preferredSport",
  "skillLevel",
  "yearsPlaying",
  "weeklyGoalDays",
];

const ENUMS = {
  preferredSport: new Set(["chinese8", "nineBall", "both"]),
  skillLevel: new Set(["beginner", "elementary", "intermediate", "advanced"]),
  yearsPlaying: new Set(["lessThan1", "oneToThree", "threeToFive", "fivePlus"]),
};

// v53 early backend builds briefly used numeric aliases that never matched the existing
// iOS enum. Normalize those values on read so an already-written profile does not fall
// back to “不到 1 年” after the client restores its session.
const YEARS_PLAYING_ALIASES = {
  oneTo3: "oneToThree",
  threeTo5: "threeToFive",
  moreThan5: "fivePlus",
};

class ProfileValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ProfileValidationError";
    this.status = 400;
  }
}

function normalizeDisplayName(value) {
  if (typeof value !== "string") {
    throw new ProfileValidationError("昵称必须是字符串");
  }
  const normalized = value.trim();
  const count = Array.from(normalized).length;
  if (count < 1 || count > 20) {
    throw new ProfileValidationError("昵称长度须为 1–20 个字符");
  }
  return normalized;
}

function validateProfileUpdate(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new ProfileValidationError("个人资料格式无效");
  }

  const unknown = Object.keys(input).filter((key) => !PROFILE_FIELDS.includes(key));
  if (unknown.length > 0) {
    throw new ProfileValidationError(`不支持的个人资料字段：${unknown.join(", ")}`);
  }
  if (Object.keys(input).length === 0) {
    throw new ProfileValidationError("没有可更新的个人资料字段");
  }

  const update = {};
  for (const [key, value] of Object.entries(input)) {
    if (key === "displayName") {
      update.displayName = normalizeDisplayName(value);
      continue;
    }
    if (key === "weeklyGoalDays") {
      if (!Number.isInteger(value) || value < 1 || value > 7) {
        throw new ProfileValidationError("每周训练目标须为 1–7 天");
      }
      update.weeklyGoalDays = value;
      continue;
    }
    if (!ENUMS[key]?.has(value)) {
      throw new ProfileValidationError(`${key} 取值无效`);
    }
    update[key] = value;
  }
  return update;
}

function serializeUser(user) {
  const source = user?.toObject ? user.toObject() : user;
  if (!source) return null;
  return {
    id: String(source._id ?? source.id),
    displayName: source.displayName ?? null,
    email: source.email ?? null,
    provider: source.provider,
    avatarRevision: source.avatarRevision ?? null,
    preferredSport: source.preferredSport ?? null,
    skillLevel: source.skillLevel ?? null,
    yearsPlaying: YEARS_PLAYING_ALIASES[source.yearsPlaying] ?? source.yearsPlaying ?? null,
    weeklyGoalDays: source.weeklyGoalDays ?? null,
  };
}

module.exports = {
  ProfileValidationError,
  normalizeDisplayName,
  serializeUser,
  validateProfileUpdate,
};
