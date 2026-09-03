require("dotenv").config();
const mongoose = require("mongoose");
const config = require("./src/config");
const { createApp } = require("./src/app");

const app = createApp();

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
