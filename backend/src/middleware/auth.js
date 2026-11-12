const { verifyAccessToken } = require("../utils/jwt");

const { eligibleProfile } = require("../services/accountAge");
const User = require("../models/User");
const { activeAccount } = require("../services/accountWrite");

function verifiedToken(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({ message: "未登录" });
  }
  try {
    const payload = verifyAccessToken(header.slice(7));
    if (typeof payload.sub !== "string" || !/^[a-f0-9]{24}$/i.test(payload.sub) || payload.type === "refresh") {
      return res.status(401).json({ message: "登录凭据无效" });
    }
    req.userId = payload.sub;
    req.age14 = payload.age14 === true;
  } catch {
    return res.status(401).json({ message: "登录已过期，请重新登录" });
  }
  next();
}

async function activeUser(req, res, next) {
  try {
    if (!req.age14 || !await User.exists({ ...activeAccount(req.userId), ...eligibleProfile() })) {
      return res.status(401).json({ message: "账号不可用" });
    }
    next();
  } catch (error) {
    next(error);
  }
}

module.exports = [verifiedToken, activeUser];
module.exports.verifiedToken = verifiedToken;
