require("dotenv").config();
// A service launched without an explicit development mode uses production checks.
process.env.NODE_ENV ||= "production";
const mongoose = require("mongoose");
const config = require("./src/config");
// Gate the real service entry, including direct node/systemd launches.
// Development remains explicit; production never opens a socket on partial identity config.
if (process.env.NODE_ENV !== "development" && process.env.NODE_ENV !== "test") {
  const result = require("./src/config/productionPreflight").productionPreflight(process.env);
  if (!result.ok) {
    console.error(JSON.stringify({ event: "production-preflight-failed", ...result }));
    process.exit(1);
  }
}
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
