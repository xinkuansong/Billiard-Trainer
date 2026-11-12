const { randomUUID } = require("node:crypto");
const jwt = require("jsonwebtoken");
const config = require("../config");

function signAccessToken(userId) {
  return jwt.sign({ sub: userId, age14: true }, config.jwtSecret, { expiresIn: config.accessTokenExpiry });
}

function signRefreshToken(userId) {
  return jwt.sign({ sub: userId, age14: true, type: "refresh" }, config.jwtRefreshSecret, {
    expiresIn: config.refreshTokenExpiry,
    jwtid: randomUUID(),
  });
}

function verifyAccessToken(token) {
  return jwt.verify(token, config.jwtSecret);
}

function verifyRefreshToken(token) {
  return jwt.verify(token, config.jwtRefreshSecret);
}

module.exports = { signAccessToken, signRefreshToken, verifyAccessToken, verifyRefreshToken };
