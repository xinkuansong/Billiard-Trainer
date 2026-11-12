// Runs on the application host. Credentials never leave the root-only configuration.
const fs = require("node:fs/promises");
const path = require("node:path");
const { createRequire } = require("node:module");
const app = createRequire("/opt/qiuji-backend/package.json");
const mongoose = app("mongoose");
const ledger = app("./src/services/deletionLedger");

async function main() {
  const mode = process.argv[2];
  const settings = JSON.parse(await fs.readFile("/etc/cuephys-backup/reader.json", "utf8"));
  const journalUri = new URL(settings.uri);
  journalUri.pathname = '/cuephys_deletions';
  process.env.DELETION_LEDGER_URI = journalUri.toString();
  process.env.DELETION_CHECKPOINT_DIR = settings.checkpoints;
  const client = new mongoose.mongo.MongoClient(settings.uri, { serverSelectionTimeoutMS: 5000 });
  try {
    await client.connect();
    const business = client.db("qiuji");
    const journal = client.db("cuephys_deletions");
    const head = await journal.collection("deletion_ledger_metadata").findOne({ _id: "v1" });
    const anchor = await business.collection("deletion_ledger_anchor").findOne({ _id: "v1" });
    if (!head || !anchor || head.identity !== anchor.identity || head.sequence < anchor.sequence) {
      throw new Error("Ledger and application anchor disagree");
    }
    let token = null;
    if (mode === "full") {
      // All writes, including transaction commits, advance this fence. No-op heartbeats do not.
      const op = await client.db("local").collection("oplog.rs").find({ op: { $ne: "n" } })
        .sort({ $natural: -1 }).project({ ts: 1, _id: 0 }).limit(1).next();
      if (!op) throw new Error("Cannot fence database writes");
      token = op.ts.toString();
    }
    if (process.argv[3]) {
      const dir = process.argv[3];
      await mongoose.connect(settings.uri, { dbName: "qiuji" });
      await ledger.readDeletions();
      if (mode === "full") {
        const avatars = [];
        for await (const user of business.collection("users").find({ avatarRevision: { $gt: 0 } }, { projection: { avatarRevision: 1 } })) {
          const file = String(user._id) + "-" + user.avatarRevision + ".jpg";
          if (!/^[0-9a-f]{24}-[1-9][0-9]*\.jpg$/.test(file)) throw new Error("Invalid avatar reference");
          avatars.push(file);
        }
        await fs.writeFile(path.join(dir, "avatar-list"), avatars.length ? avatars.join("\n")+"\n" : "", { mode: 0o600 });
      }
    }
    console.log(JSON.stringify({ identity: head.identity, seq: head.sequence, hash: head.hash, token,
      checkpoints: process.env.DELETION_CHECKPOINT_DIR, avatars: settings.avatars }));
  } finally {
    await ledger.closeLedger(); await mongoose.disconnect(); await client.close();
  }
}
main().catch(error => { console.error("Backup source check failed:", error.codeName || error.name); process.exitCode = 1; });
