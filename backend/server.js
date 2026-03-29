require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const config = require("./src/config");

const authRoutes = require("./src/routes/auth");
const userRoutes = require("./src/routes/user");
const trainingSessionRoutes = require("./src/routes/trainingSession");
const angleTestRoutes = require("./src/routes/angleTest");
const drillRoutes = require("./src/routes/drills");

const app = express();

app.use(cors());
app.use(express.json({ limit: "2mb" }));

app.get("/health", (_req, res) => res.json({ status: "ok" }));

app.use("/auth", authRoutes);
app.use("/user", userRoutes);
app.use("/training-sessions", trainingSessionRoutes);
app.use("/angle-tests", angleTestRoutes);
app.use("/drills", drillRoutes);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ message: err.message || "Internal Server Error" });
});

mongoose
  .connect(config.mongodbUri)
  .then(() => {
    console.log("MongoDB connected");
    app.listen(config.port, () => console.log(`Server listening on :${config.port}`));
  })
  .catch((err) => {
    console.error("MongoDB connection failed:", err);
    process.exit(1);
  });
