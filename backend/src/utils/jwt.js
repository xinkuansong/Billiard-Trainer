const jwt = require("jsonwebtoken");
const config = require("../config");

function signAccessToken(userId) {
  return jwt.sign({ sub: userId }, config.jwtSecret, { expiresIn: config.accessTokenExpiry });
}

function signRefreshToken(userId) {
  return jwt.sign({ sub: userId, type: "refresh" }, config.jwtRefreshSecret, {
    expiresIn: config.refreshTokenExpiry,
  });
}

function verifyAccessToken(token) {
  return jwt.verify(token, config.jwtSecret);
}

function verifyRefreshToken(token) {
  return jwt.verify(token, config.jwtRefreshSecret);
}

module.exports = { signAccessToken, signRefreshToken, verifyAccessToken, verifyRefreshToken };
