require("dotenv").config();
// A service launched without an explicit development mode uses production checks.
process.env.NODE_ENV ||= "production";
const mongoose = require("mongoose");
const config = require("./src/config");
const { createApp } = require("./src/app");

const { resumePendingDeletions, reconcileRestoredAccounts } = require("./src/services/accountDeletion");

const app = createApp();

mongoose
  .connect(config.mongodbUri)
  .then(async () => {
    console.log("MongoDB connected");
    // Schedule the next sweep only after the previous cursor finishes.
    async function recover() {
      try {
        await resumePendingDeletions(config.avatarStorageDir);
      } catch (error) {
        console.error("Account recovery failed", error.code || error.name);
      } finally {
        setTimeout(recover, 60_000).unref();
      }
    }
    await require("./src/models/User").init(); // Binding requires both unique identity indexes.
    await reconcileRestoredAccounts(config.avatarStorageDir);
    void recover();
    app.listen(config.port, () => console.log(`Server listening on :${config.port}`));
  })
  .catch((err) => {
    console.error("Backend startup failed:", err);
    process.exit(1);
  });
