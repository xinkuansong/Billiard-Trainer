const express = require("express");
const appleSignIn = require("apple-signin-auth");
const User = require("../models/User");
const { signAccessToken, signRefreshToken, verifyRefreshToken } = require("../utils/jwt");

const router = express.Router();

// POST /auth/login-apple
router.post("/login-apple", async (req, res, next) => {
  try {
    const { identityToken } = req.body;
    if (!identityToken) {
      return res.status(400).json({ message: "identityToken is required" });
    }

    const payload = await appleSignIn.verifyIdToken(identityToken, {
      audience: "com.qiuji.app",
      ignoreExpiration: false,
    });

    const appleUserId = payload.sub;
    let user = await User.findOne({ appleUserId });

    if (!user) {
      user = await User.create({
        appleUserId,
        email: payload.email || undefined,
        provider: "apple",
      });
    }

    const accessToken = signAccessToken(user._id.toString());
    const refreshToken = signRefreshToken(user._id.toString());

    user.refreshToken = refreshToken;
    await user.save();

    res.json({
      accessToken,
      refreshToken,
      user: {
        id: user._id,
        displayName: user.displayName,
        email: user.email,
        provider: user.provider,
      },
    });
  } catch (err) {
    if (err.message?.includes("Token")) {
      return res.status(401).json({ message: "Apple identity token 验证失败" });
    }
    next(err);
  }
});

// POST /auth/refresh
router.post("/refresh", async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ message: "refreshToken is required" });
    }

    const payload = verifyRefreshToken(refreshToken);
    const user = await User.findById(payload.sub);

    if (!user || user.refreshToken !== refreshToken) {
      return res.status(401).json({ message: "Refresh token 无效" });
    }

    const newAccessToken = signAccessToken(user._id.toString());
    const newRefreshToken = signRefreshToken(user._id.toString());

    user.refreshToken = newRefreshToken;
    await user.save();

    res.json({ accessToken: newAccessToken, refreshToken: newRefreshToken });
  } catch {
    return res.status(401).json({ message: "Refresh token 已过期，请重新登录" });
  }
});

// DELETE /auth/logout
router.delete("/logout", async (req, res, next) => {
  try {
    const header = req.headers.authorization;
    if (header?.startsWith("Bearer ")) {
      const jwt = require("jsonwebtoken");
      const config = require("../config");
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
