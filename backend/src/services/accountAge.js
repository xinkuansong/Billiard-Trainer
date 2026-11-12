// Compare civil dates in the time zone of the mainland launch.
function latestEligibleBirthday(now = new Date()) {
  const today = new Date(now.getTime() + 8 * 3600000).toISOString().slice(0, 10);
  return String(Number(today.slice(0, 4)) - 14) + today.slice(4);
}

function eligibleProfile() {
  return { $or: [{ birthDate: null }, { birthDate: { $lte: latestEligibleBirthday() } }] };
}

const surveyAgeBands = ["14-17", "18-24", "25-34", "35-44", "45-54", "55+"];

const ageMessage = "不满 14 周岁可继续使用本机训练，暂不开放账号功能";

function requireAgeDeclaration(req, res, next) {
  if (req.body?.age14Confirmed !== true) {
    return res.status(403).json({ code: "AGE_CONFIRMATION_REQUIRED", message: "请先确认已满 14 周岁" });
  }
  next();
}

module.exports = { surveyAgeBands, latestEligibleBirthday, eligibleProfile, ageMessage, requireAgeDeclaration };
