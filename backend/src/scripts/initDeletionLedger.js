require("dotenv").config();
const mongoose = require("mongoose");
const config = require("../config");
const { initializeLedger, closeLedger } = require("../services/deletionLedger");

async function main() {
  if (process.argv[2] !== "--initialize-live-baseline") throw new Error("Explicit live baseline initialization required");
  try {
    await mongoose.connect(config.mongodbUri);
    await initializeLedger();
    console.log("Deletion ledger initialized. Take a new backup of the business database.");
  } finally {
    await closeLedger();
    await mongoose.disconnect();
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
