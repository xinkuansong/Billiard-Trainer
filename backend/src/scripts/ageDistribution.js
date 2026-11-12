// Internal aggregate report. Requires the same database URI as the app service.
const mongoose = require("mongoose");
const User = require("../models/User");
const { eligibleProfile, surveyAgeBands } = require("../services/accountAge");

async function ageDistribution({ beginnersOnly = false } = {}) {
  const cohort = beginnersOnly ? { yearsPlaying: "lessThan1" } : {};
  const groups = await User.aggregate([
    { $match: { ageSurveyLogin: true, deletionPending: { $ne: true }, ...cohort, ...eligibleProfile() } },
    { $group: { _id: { $ifNull: ["$ageBand", null] }, accounts: { $sum: 1 } } },
  ]);
  const counts = new Map(groups.map(group => [group._id, group.accounts]));
  const total = groups.reduce((sum, group) => sum + group.accounts, 0);
  const answered = surveyAgeBands.reduce((sum, band) => sum + (counts.get(band) || 0), 0);
  const percent = (value, base) => base ? Math.round(value * 1000 / base) / 10 : null;
  return {
    loggedInAccounts: total, answered, unanswered: total - answered,
    responsePercent: percent(answered, total),
    distribution: surveyAgeBands.map(ageBand => ({
      ageBand, accounts: counts.get(ageBand) || 0,
      percentOfRespondents: percent(counts.get(ageBand) || 0, answered),
    })),
  };
}

if (require.main === module) {
  require("dotenv").config();
  (async () => {
    try {
      await mongoose.connect(process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/qiuji", { autoIndex: false, autoCreate: false });
      console.log(JSON.stringify(await ageDistribution({ beginnersOnly: process.argv.includes("--beginners") }), null, 2));
    } finally {
      await mongoose.disconnect();
    }
  })().catch(() => { console.error("无法读取年龄段统计，请检查数据库连接与只读权限。"); process.exitCode = 1; });
}

module.exports = { ageDistribution };
