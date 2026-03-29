const { verifyAccessToken } = require("../utils/jwt");

function auth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({ message: "未登录" });
  }
  try {
    const payload = verifyAccessToken(header.slice(7));
    req.userId = payload.sub;
    next();
  } catch {
    return res.status(401).json({ message: "登录已过期，请重新登录" });
  }
}

module.exports = auth;
