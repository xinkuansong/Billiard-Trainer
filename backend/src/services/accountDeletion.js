const User = require("../models/User");
const TrainingSession = require("../models/TrainingSession");
const AngleTest = require("../models/AngleTest");
const { CustomFormation, FormationChange } = require("../models/CustomFormation");
const { deleteAvatar } = require("./avatarStorage");

function productionDependencies() {
  return {
    findUser: (userId) => User.findById(userId).select("avatarRevision").lean(),
    deleteTrainingSessions: (userId) => TrainingSession.deleteMany({ userId }),
    deleteAngleTests: (userId) => AngleTest.deleteMany({ userId }),
    markDeleting: (userId) => User.updateOne({ _id: userId }, { $set: { deletionPending: true } }),
    deleteFormations: async (userId) => {
      await CustomFormation.deleteMany({ userId });
      await FormationChange.deleteMany({ userId });
    },
    deleteUser: (userId) => User.findByIdAndDelete(userId),
    deleteAvatar,
  };
}

async function deleteAccountData(userId, avatarStorageDir, dependencies = productionDependencies()) {
  const user = await dependencies.findUser(userId);

  // Delete the file first. If storage is unavailable, keep the account record intact so a
  // retry still knows the exact revision to remove instead of orphaning an undiscoverable file.
  await dependencies.deleteAvatar(avatarStorageDir, userId, user?.avatarRevision);

  // Contends with formation transactions on the user row before purging records.
  await dependencies.markDeleting(userId);
  await dependencies.deleteFormations(userId);
  await Promise.all([
    dependencies.deleteTrainingSessions(userId),
    dependencies.deleteAngleTests(userId),
    dependencies.deleteUser(userId),
  ]);
}

module.exports = { deleteAccountData };
