const mongoose = require("mongoose");
const User = require("../models/User");

const activeAccount = userId => ({ _id: userId, deletionPending: { $ne: true } });

function unavailable() {
  return Object.assign(new Error("账号不可用"), { status: 401 });
}

// A real write to the user row serializes the transaction with the deletion marker.
// After a conflict Mongo retries the callback against the new account state.
function withActiveAccount(userId, operation) {
  return mongoose.connection.transaction(async session => {
    const user = await User.findOneAndUpdate(activeAccount(userId),
      { $inc: { accountWriteSequence: 1 } }, { session, new: true }).lean();
    if (!user) throw unavailable();
    return operation(session, user);
  });
}

module.exports = { activeAccount, unavailable, withActiveAccount };
