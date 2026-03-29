module.exports = {
  mongodbUri: process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/qiuji",
  jwtSecret: process.env.JWT_SECRET || "dev-secret-change-me",
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || "dev-refresh-secret-change-me",
  accessTokenExpiry: "1h",
  refreshTokenExpiry: "30d",
  port: parseInt(process.env.PORT, 10) || 3000,
};
