const fs = require("node:fs");
const { createPrivateKey } = require("node:crypto");

const EXPECTED_BUNDLE_ID = "com.youbilliards.cuephys";

function nonEmpty(env, name) {
  const value = env[name];
  return typeof value === "string" && value.trim() !== "";
}

function validSigningKey(value) {
  return typeof value === "string" && value.trim() === value && Buffer.byteLength(value, "utf8") >= 32 &&
    !["change-me-to-a-random-string", "change-me-to-another-random-string"].includes(value);
}

function productionPreflight(env = process.env, filesystem = fs) {
  const blockers = [];
  const warnings = [];
  const checks = {};

  checks.nodeEnv = env.NODE_ENV === "production";
  if (!checks.nodeEnv) blockers.push("NODE_ENV 必须为 production");

  checks.jwt = validSigningKey(env.JWT_SECRET) && validSigningKey(env.JWT_REFRESH_SECRET) &&
    env.JWT_SECRET !== env.JWT_REFRESH_SECRET &&
    env.JWT_SECRET !== "dev-secret-change-me" &&
    env.JWT_REFRESH_SECRET !== "dev-refresh-secret-change-me";
  if (!checks.jwt) blockers.push("JWT_SECRET/JWT_REFRESH_SECRET 必须是不同的随机值（至少 32 字节）");

  checks.mongodb = nonEmpty(env, "MONGODB_URI");
  if (!checks.mongodb) blockers.push("MONGODB_URI 未配置");

  checks.appleBundleID = env.APPLE_BUNDLE_ID === EXPECTED_BUNDLE_ID;
  if (!checks.appleBundleID) blockers.push(`APPLE_BUNDLE_ID 必须为 ${EXPECTED_BUNDLE_ID}`);
  checks.appleTeam = /^[A-Z0-9]{10}$/.test(env.APPLE_TEAM_ID || "");
  if (!checks.appleTeam) blockers.push("APPLE_TEAM_ID 未配置或格式不正确");
  checks.appleKeyID = /^[A-Z0-9]{10}$/.test(env.APPLE_KEY_ID || "");
  if (!checks.appleKeyID) blockers.push("APPLE_KEY_ID 未配置或格式不正确");
  checks.appleTokenEncryption = /^[0-9a-f]{64}$/i.test(env.APPLE_TOKEN_ENCRYPTION_KEY || "");
  if (!checks.appleTokenEncryption) blockers.push("APPLE_TOKEN_ENCRYPTION_KEY 必须是 64 位十六进制随机值");

  const keyPath = typeof env.APPLE_SIGNIN_KEY_PATH === "string" ? env.APPLE_SIGNIN_KEY_PATH : "";
  let keyStat;
  try { keyStat = keyPath ? filesystem.statSync(keyPath) : null; } catch { keyStat = null; }
  checks.applePrivateKey = Boolean(keyStat?.isFile());
  if (!checks.applePrivateKey) {
    blockers.push("APPLE_SIGNIN_KEY_PATH 未指向服务器上的 .p8 文件");
  } else if ((keyStat.mode & 0o077) !== 0) {
    blockers.push("Apple .p8 文件权限必须收紧为仅服务账号可读（建议 0600）");
  }

  checks.appleKeyMaterial = false;
  if (checks.applePrivateKey) {
    try {
      const key = createPrivateKey(filesystem.readFileSync(keyPath));
      checks.appleKeyMaterial = key.asymmetricKeyType === "ec" &&
        key.asymmetricKeyDetails?.namedCurve === "prime256v1";
    } catch { /* Report only the field name; never key bytes or filesystem error text. */ }
  }
  if (!checks.appleKeyMaterial) blockers.push("Apple .p8 必须是有效的 P-256 私钥");

  checks.wechatMode = env.WECHAT_LOGIN_ENABLED === undefined ||
    ["true", "false"].includes(env.WECHAT_LOGIN_ENABLED);
  if (!checks.wechatMode) blockers.push("WECHAT_LOGIN_ENABLED 必须明确为 true 或 false");
  checks.wechatEnabled = env.WECHAT_LOGIN_ENABLED !== "false";
  checks.wechat = /^wx[0-9a-f]{16}$/i.test(env.WECHAT_APP_ID || "") &&
    /^[0-9a-f]{32}$/i.test(env.WECHAT_APP_SECRET || "") &&
    !/^wx0{16}$/i.test(env.WECHAT_APP_ID) && !/^0{32}$/.test(env.WECHAT_APP_SECRET);
  if (checks.wechatEnabled && !checks.wechat) blockers.push("WECHAT_APP_ID/WECHAT_APP_SECRET 尚未配置");
  if (!checks.wechatEnabled) warnings.push("微信登录已明确关闭；登录与绑定接口均不可用");

  // Website legal pages are validated separately; the API's legacy document
  // routes remain fail-closed until their own production facts are supplied.
  if (env.LEGAL_DOCUMENTS_PUBLISHED !== "true") {
    warnings.push("API 内置法律页未启用；App 当前使用官网法律页，需保持官网 200 可访问");
  }

  return { ok: blockers.length === 0, blockers, warnings, checks };
}

module.exports = { EXPECTED_BUNDLE_ID, productionPreflight };
