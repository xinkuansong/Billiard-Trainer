const path = require("path");
const express = require("express");
const cors = require("cors");
const config = require("./config");

const authRoutes = require("./routes/auth");
const userRoutes = require("./routes/user");
const trainingSessionRoutes = require("./routes/trainingSession");
const angleTestRoutes = require("./routes/angleTest");
const drillRoutes = require("./routes/drills");
const { createLegalDocumentHandler } = require("./services/legalDocuments");

function createApp(overrides = {}) {
  const app = express();
  const legal = {
    published: overrides.legalDocumentsPublished ?? config.legalDocumentsPublished,
    operatorName: overrides.legalOperatorName ?? config.legalOperatorName,
    contactEmail: overrides.legalContactEmail ?? config.legalContactEmail,
    effectiveDate: overrides.legalEffectiveDate ?? config.legalEffectiveDate,
    infrastructureProvider:
      overrides.legalInfrastructureProvider ?? config.legalInfrastructureProvider,
    dataRegion: overrides.legalDataRegion ?? config.legalDataRegion,
    backupRetentionDays:
      overrides.legalBackupRetentionDays ?? config.legalBackupRetentionDays,
  };
  const publicDir = overrides.legalPublicDir ?? path.join(__dirname, "..", "public");

  app.disable("x-powered-by");
  app.use(cors());
  app.use(express.json({ limit: "2mb" }));

  app.get("/health", (_req, res) => res.json({ status: "ok" }));

  // Incomplete templates must never look like published policies. These routes return
  // 503 until every production fact below is configured and publishing is enabled.
  app.get(["/privacy", "/privacy/"], createLegalDocumentHandler("privacy", publicDir, legal));
  app.get(["/terms", "/terms/"], createLegalDocumentHandler("terms", publicDir, legal));
  app.get("/legal.css", (_req, res, next) => {
    if (!legal.published) return res.status(404).end();
    return res.sendFile(path.join(publicDir, "legal.css"), (error) => {
      if (error) next(error);
    });
  });

  app.use("/auth", authRoutes);
  app.use("/user", userRoutes);
  app.use("/training-sessions", trainingSessionRoutes);
  app.use("/angle-tests", angleTestRoutes);
  app.use("/drills", drillRoutes);

  app.use((err, _req, res, _next) => {
    console.error(err);
    res.status(err.status || 500).json({ message: err.message || "Internal Server Error" });
  });

  return app;
}

module.exports = { createApp };
