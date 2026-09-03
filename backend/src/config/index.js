const path = require("path");

module.exports = {
  mongodbUri: process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/qiuji",
  jwtSecret: process.env.JWT_SECRET || "dev-secret-change-me",
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || "dev-refresh-secret-change-me",
  // Apple identityToken 的 `aud` claim = App 的 Bundle ID，必须与 `project.yml` 的
  // PRODUCT_BUNDLE_IDENTIFIER 完全一致，否则 verifyIdToken 抛 "jwt audience invalid"。
  // ⛔ 不要写死成臆想值：仓库里曾长期是 "com.qiuji.app"（真实 Bundle ID 是
  // com.xinkuan.qiuji），线上靠有人手改服务器文件绕过，一次 rsync 部署即把线上登录打挂。
  appleBundleId: process.env.APPLE_BUNDLE_ID || "com.xinkuan.qiuji",
  accessTokenExpiry: "1h",
  refreshTokenExpiry: "30d",
  avatarStorageDir: process.env.AVATAR_STORAGE_DIR || path.join(process.cwd(), "data", "avatars"),
  legalDocumentsPublished: process.env.LEGAL_DOCUMENTS_PUBLISHED === "true",
  legalOperatorName: process.env.LEGAL_OPERATOR_NAME || "",
  legalContactEmail: process.env.LEGAL_CONTACT_EMAIL || "feedback@qiuji.app",
  legalEffectiveDate: process.env.LEGAL_EFFECTIVE_DATE || "",
  legalInfrastructureProvider: process.env.LEGAL_INFRASTRUCTURE_PROVIDER || "",
  legalDataRegion: process.env.LEGAL_DATA_REGION || "",
  legalBackupRetentionDays: process.env.LEGAL_BACKUP_RETENTION_DAYS || "",
  port: parseInt(process.env.PORT, 10) || 3000,
};
