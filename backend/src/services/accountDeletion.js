const { recordDeletion, readDeletions } = require("./deletionLedger");
const appleGrant = require("./appleGrant");
const User = require("../models/User");
const TrainingSession = require("../models/TrainingSession");
const AngleTest = require("../models/AngleTest");
const { CustomFormation, FormationChange } = require("../models/CustomFormation");
const { deleteAccountAvatars } = require("./avatarStorage");

// Only one worker contacts Apple at a time. A crashed worker releases its claim by expiry.
async function finishDeletion(userId) {
  const leaseUntil = new Date(Date.now() + 60_000);
  const owner = await User.findOneAndUpdate(
    { _id: userId, deletionPending: true, $or: [
      { appleRevokeLeaseUntil: null }, { appleRevokeLeaseUntil: { $lte: new Date() } },
    ] },
    { $set: { appleRevokeLeaseUntil: leaseUntil } }, { new: true }
  ).select("provider appleUserId +appleGrant").lean();
  if (!owner) return await User.exists({ _id: userId }) ? "pending" : "alreadyDeleted";

  let outcome = owner.appleUserId || owner.provider === "apple" ? "manual" : "notLinked";
  if (owner.appleGrant) {
    try {
      await appleGrant.revoke(owner.appleGrant, owner.appleUserId);
    } catch {
      console.error("Apple grant revocation pending; scheduled for retry");
      return "pending";
    }
    outcome = "revoked";
  }
  const removed = await User.deleteOne({ _id: userId, appleRevokeLeaseUntil: leaseUntil });
  return removed.deletedCount ? outcome : "pending";
}

function productionDependencies() {
  return {
    recordDeletion: async (id, phase) => {
      try {
        await recordDeletion(id, phase);
      } catch (error) {
        console.error("Deletion ledger write failed", error.code || error.name);
        throw Object.assign(new Error("注销记录暂时无法保存，请稍后重试"), { status: 503 });
      }
    },
    deleteTrainingSessions: (userId) => TrainingSession.deleteMany({ userId }),
    deleteAngleTests: (userId) => AngleTest.deleteMany({ userId }),
    markDeleting: (userId) => User.updateOne({ _id: userId }, { $set: { deletionPending: true }, $unset: { refreshToken: 1, email: 1, displayName: 1, avatarRevision: 1, preferredSport: 1, skillLevel: 1, yearsPlaying: 1, weeklyGoalDays: 1, gender: 1, birthDate: 1 } }),
    deleteFormations: async (userId) => {
      await CustomFormation.deleteMany({ userId });
      await FormationChange.deleteMany({ userId });
    },
    deleteUser: finishDeletion,
    deleteAvatars: deleteAccountAvatars,
  };
}

async function clearAccountData(userId, avatarStorageDir, dependencies) {
  // The marker outlives every cleanup step, including filesystem failures and process restarts.
  await dependencies.markDeleting(userId);
  await dependencies.deleteAvatars(avatarStorageDir, userId);
  await dependencies.deleteFormations(userId);
  await dependencies.deleteTrainingSessions(userId);
  await dependencies.deleteAngleTests(userId);
}

async function deleteAccountData(userId, avatarStorageDir, dependencies = productionDependencies()) {
  await dependencies.recordDeletion(userId, "requested");
  await clearAccountData(userId, avatarStorageDir, dependencies);
  const outcome = await dependencies.deleteUser(userId);
  if (outcome !== "pending") await dependencies.recordDeletion(userId, "completed");
  return outcome;
}

async function resumePendingDeletions(avatarStorageDir) {
  for await (const row of User.find({ deletionPending: true }).select("_id").lean().cursor()) {
    try {
      await deleteAccountData(row._id, avatarStorageDir);
    } catch (error) {
      console.error("Pending account cleanup failed", error.code || error.name);
    }
  }
}

// Run before opening the HTTP listener, with the restore target isolated from other writers.
async function reconcileRestoredAccounts(avatarStorageDir) {
  const accounts = await readDeletions();
  const dependencies = productionDependencies();
  for (const [id, phase] of accounts) {
    if (phase === "completed") {
      // Never revoke a grant from an old snapshot for an already completed deletion.
      await clearAccountData(id, avatarStorageDir, dependencies);
      await User.deleteOne({ _id: id, deletionPending: true });
    } else {
      await deleteAccountData(id, avatarStorageDir);
      // Pending Apple revocation may be retried by the normal worker. The local owner
      // is already frozen and its data cleared. Cleanup or ledger errors propagate.
    }
  }
}

module.exports = { deleteAccountData, resumePendingDeletions, reconcileRestoredAccounts };
