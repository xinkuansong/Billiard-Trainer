/**
 * Seed Drill JSON files from QiuJi/Resources/Drills/ into MongoDB.
 * Usage: MONGODB_URI=... node src/scripts/seedDrills.js [path-to-Drills-dir]
 */
require("dotenv").config();
const fs = require("fs");
const path = require("path");
const mongoose = require("mongoose");
const config = require("../config");
const Drill = require("../models/Drill");

const DRILLS_DIR = process.argv[2] || path.resolve(__dirname, "../../..", "QiuJi/Resources/Drills");

async function main() {
  await mongoose.connect(config.mongodbUri);
  console.log("Connected to MongoDB");

  const indexPath = path.join(DRILLS_DIR, "index.json");
  const indexData = JSON.parse(fs.readFileSync(indexPath, "utf-8"));

  let count = 0;
  for (const group of indexData.categories) {
    for (const drillId of group.drills) {
      const filePath = path.join(DRILLS_DIR, group.category, `${drillId}.json`);
      if (!fs.existsSync(filePath)) {
        console.warn(`  SKIP: ${filePath} not found`);
        continue;
      }
      const content = JSON.parse(fs.readFileSync(filePath, "utf-8"));
      await Drill.findOneAndUpdate(
        { drillId },
        { drillId, content },
        { upsert: true, new: true }
      );
      count++;
    }
  }

  console.log(`Seeded ${count} drills`);
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
