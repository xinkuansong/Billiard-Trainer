const express = require("express");
const appleSignIn = require("apple-signin-auth");
const appleGrant = require("../services/appleGrant");
const { wechatIdentity } = require("../services/wechatLogin");
const auth = require("../middleware/auth");
const User = require("../models/User");
const { signAccessToken, signRefreshToken, verifyRefreshToken } = require("../utils/jwt");
const { activeAccount } = require("../services/accountWrite");
const config = require("../config");
const { normalizeDisplayName, serializeUser } = require("../services/userProfile");

const { eligibleProfile, latestEligibleBirthday, ageMessage, requireAgeDeclaration } = require("../services/accountAge");
const router = express.Router();

function httpError(status, message) {
  return Object.assign(new Error(message), { status });
}

async function appleIdentity(token) {
  if (typeof token !== "string" || !token) throw httpError(400, "需要 Apple 身份凭据");
  let payload;
  try {
    payload = await appleSignIn.verifyIdToken(token, { audience: config.appleBundleId, ignoreExpiration: false });
  } catch {
    throw httpError(401, "Apple 身份凭据验证失败");
  }
  if (typeof payload.sub !== "string" || !payload.sub) throw httpError(401, "Apple 身份无效");
  return payload;
}

async function appleAuthorization(code, subject) {
  if (typeof code !== "string" || !code.trim()) throw httpError(400, "需要有效的 Apple 授权码");
  return appleGrant.exchange(code, subject);
}

function newIdentity(res) {
  return res.status(409).json({ code: "IDENTITY_NOT_REGISTERED", message: "请先用原登录方式绑定已有账号，或选择创建新账号" });
}

async function createOrFind(identity, fields) {
  try {
    return await User.create({ ...identity, ...fields });
  } catch (error) {
    if (error.code !== 11000) throw error;
    return User.findOne(identity);
  }
}

async function login(res, user, changes = {}) {
  if (!user || user.deletionPending) throw httpError(401, "账号不可用");
  const accessToken = signAccessToken(user.id);
  const refreshToken = signRefreshToken(user.id);
  if (user.birthDate > latestEligibleBirthday()) throw httpError(403, ageMessage);
  const updated = await User.findOneAndUpdate({ ...activeAccount(user.id), ...eligibleProfile() },
    { $set: { ...changes, refreshToken, ageSurveyLogin: true } }, { new: true });
  if (!updated) throw httpError(401, "账号不可用");
  res.json({ accessToken, refreshToken, user: serializeUser(updated) });
}

router.post("/login-apple", requireAgeDeclaration, async (req, res, next) => {
  try {
    const { identityToken, authorizationCode, displayName, createIfMissing } = req.body;
    const payload = await appleIdentity(identityToken);
    const identity = { appleUserId: payload.sub };
    let user = await User.findOne(identity);
    if (user?.birthDate > latestEligibleBirthday()) throw httpError(403, ageMessage);
    if (user?.deletionPending) throw httpError(401, "账号正在注销");
    // Older Apple clients already use this endpoint for both signup and login.
    if (!user && createIfMissing !== undefined && createIfMissing !== true) return newIdentity(res);
    const name = displayName == null ? undefined : normalizeDisplayName(displayName);
    const changes = {};
    if (authorizationCode !== undefined || !user) {
      changes.appleGrant = await appleAuthorization(authorizationCode, payload.sub);
    }
    if (!user) user = await createOrFind(identity, { provider: "apple", email: payload.email, displayName: name, ...changes });
    if (name && !user?.displayName) changes.displayName = name;
    await login(res, user, changes);
  } catch (error) { next(error); }
});

router.post("/login-wechat", requireAgeDeclaration, async (req, res, next) => {
  try {
    const identity = { wechatIdentity: await wechatIdentity(req.body.code) };
    let user = await User.findOne(identity);
    if (!user && req.body.createIfMissing !== true) return newIdentity(res);
    if (!user) user = await createOrFind(identity, { provider: "wechat" });
    await login(res, user);
  } catch (error) { next(error); }
});

// Binding changes future access to all account data. Check the still-current session
// again in the actual write, so logout, refresh, and deletion invalidate stale requests.
async function bindingSession(req, res, next) {
  try {
    const token = req.body.refreshToken;
    let payload;
    try { payload = verifyRefreshToken(token); } catch { throw httpError(401, "请重新登录后绑定"); }
    const filter = { ...activeAccount(req.userId), refreshToken: token };
    if (payload.type !== "refresh" || payload.sub !== req.userId || !await User.exists(filter)) {
      throw httpError(401, "请重新登录后绑定");
    }
    req.bindingFilter = filter;
    next();
  } catch (error) { next(error); }
}

function bindingConflict(res) {
  return res.status(409).json({ code: "IDENTITY_CONFLICT", message: "当前账号或目标登录方式已有绑定，请使用原登录方式" });
}

async function bindIdentity(req, res, field, identity, extra = {}) {
  try {
    const updated = await User.findOneAndUpdate({
      ...req.bindingFilter, $or: [{ [field]: null }, { [field]: identity }],
    }, { $set: { [field]: identity, ...extra } }, { new: true });
    if (updated) return res.json({ user: serializeUser(updated) });
    if (!await User.exists(req.bindingFilter)) throw httpError(401, "请重新登录后绑定");
    return bindingConflict(res);
  } catch (error) {
    if (error.code === 11000) return bindingConflict(res);
    throw error;
  }
}

router.post("/bind-wechat", auth, bindingSession, async (req, res, next) => {
  try {
    await bindIdentity(req, res, "wechatIdentity", await wechatIdentity(req.body.code));
  } catch (error) { next(error); }
});

router.post("/bind-apple", auth, bindingSession, async (req, res, next) => {
  try {
    const { sub } = await appleIdentity(req.body.identityToken);
    // Do not exchange another account's grant on a known conflict. The unique index
    // and conditional write below remain authoritative if two requests race.
    if (await User.exists({ appleUserId: sub, _id: { $ne: req.userId } })) return bindingConflict(res);
    const sealed = await appleAuthorization(req.body.authorizationCode, sub);
    await bindIdentity(req, res, "appleUserId", sub, { appleGrant: sealed });
  } catch (error) { next(error); }
});

// POST /auth/refresh
router.post("/refresh", async (req, res, next) => {
  const { refreshToken } = req.body;
  if (!refreshToken) return res.status(400).json({ message: "refreshToken is required" });
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    return res.status(401).json({ message: "Refresh token 已过期，请重新登录" });
  }
  if (payload.age14 !== true || payload.type !== "refresh" || typeof payload.sub !== "string" || !/^[a-f0-9]{24}$/i.test(payload.sub)) {
    return res.status(401).json({ message: "Refresh token 无效" });
  }
  try {
    const newAccessToken = signAccessToken(payload.sub);
    const newRefreshToken = signRefreshToken(payload.sub);
    const rotated = await User.updateOne(
      { ...activeAccount(payload.sub), ...eligibleProfile(), refreshToken },
      { $set: { refreshToken: newRefreshToken } }
    );
    if (!rotated.matchedCount) return res.status(401).json({ message: "Refresh token 无效" });

    res.json({ accessToken: newAccessToken, refreshToken: newRefreshToken });
  } catch (error) {
    next(error);
  }
});

// DELETE /auth/logout
router.delete("/logout", async (req, res, next) => {
  try {
    const header = req.headers.authorization;
    if (header?.startsWith("Bearer ")) {
      const jwt = require("jsonwebtoken");
      try {
        const p = jwt.verify(header.slice(7), config.jwtSecret);
        await User.findByIdAndUpdate(p.sub, { $unset: { refreshToken: 1 } });
      } catch {
        // token expired — still clear refresh token if possible
      }
    }
    res.json({ message: "已退出登录" });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
