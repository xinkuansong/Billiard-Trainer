const { createCipheriv, createDecipheriv, randomBytes } = require("node:crypto");
const apple = require("apple-signin-auth");
const config = require("../config");

function unavailable() {
  return Object.assign(new Error("Apple 授权服务暂时不可用，请稍后重试"), { status: 503 });
}

function encryptionKey() {
  const key = process.env.APPLE_TOKEN_ENCRYPTION_KEY || "";
  if (!/^[0-9a-f]{64}$/i.test(key)) throw unavailable();
  return Buffer.from(key, "hex");
}

function seal(token, subject, key) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  cipher.setAAD(Buffer.from(subject));
  const data = Buffer.concat([cipher.update(token, "utf8"), cipher.final()]);
  return [iv, cipher.getAuthTag(), data].map(part => part.toString("base64")).join(".");
}

function open(sealed, subject) {
  const [iv, tag, data] = sealed.split(".").map(part => Buffer.from(part, "base64"));
  const cipher = createDecipheriv("aes-256-gcm", encryptionKey(), iv);
  cipher.setAAD(Buffer.from(subject));
  cipher.setAuthTag(tag);
  return Buffer.concat([cipher.update(data), cipher.final()]).toString("utf8");
}

async function appleRequest(path, fields) {
  try {
    const secret = apple.getClientSecret({
      clientID: config.appleBundleId, teamID: process.env.APPLE_TEAM_ID,
      keyIdentifier: process.env.APPLE_KEY_ID, privateKeyPath: process.env.APPLE_SIGNIN_KEY_PATH,
    });
    const response = await fetch("https://appleid.apple.com/auth/" + path, {
      method: "POST", redirect: "error", signal: AbortSignal.timeout(8000),
      body: new URLSearchParams({ client_id: config.appleBundleId, client_secret: secret, ...fields }),
    });
    if (response.status === 200) return path === "token" ? await response.json() : undefined;
    if (path === "token" && response.status === 400 && (await response.json()).error === "invalid_grant") {
      throw Object.assign(new Error("Apple 授权码已失效，请重新登录"), { status: 401 });
    }
  } catch (error) {
    if (error.status === 401) throw error;
  }
  throw unavailable();
}

async function exchange(code, subject) {
  const key = encryptionKey();
  const tokens = await appleRequest("token", { grant_type: "authorization_code", code });
  if (!tokens.id_token || typeof tokens.refresh_token !== "string" || !tokens.refresh_token) throw unavailable();
  const verified = await apple.verifyIdToken(tokens.id_token, { audience: config.appleBundleId });
  if (verified.sub !== subject) throw Object.assign(new Error("Apple 授权身份不一致"), { status: 401 });
  return seal(tokens.refresh_token, subject, key);
}

async function revoke(sealed, subject) {
  await appleRequest("revoke", { token: open(sealed, subject), token_type_hint: "refresh_token" });
}

module.exports = { exchange, revoke };
