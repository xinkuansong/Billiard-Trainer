const fs = require("fs/promises");
const path = require("path");

const MAX_AVATAR_BYTES = 1024 * 1024;

class AvatarValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "AvatarValidationError";
    this.status = 400;
  }
}

function safeUserId(userId) {
  const value = String(userId);
  if (!/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new AvatarValidationError("用户标识无效");
  }
  return value;
}

function validateJpeg(data) {
  if (!Buffer.isBuffer(data) || data.length === 0) {
    throw new AvatarValidationError("头像文件为空");
  }
  if (data.length > MAX_AVATAR_BYTES) {
    throw new AvatarValidationError("头像文件不能超过 1 MiB");
  }
  const isJpeg = data.length >= 4 && data[0] === 0xff && data[1] === 0xd8 &&
    data[data.length - 2] === 0xff && data[data.length - 1] === 0xd9;
  if (!isJpeg) {
    throw new AvatarValidationError("头像必须是 JPEG 图片");
  }
}

function avatarPath(storageDir, userId, revision) {
  return path.join(storageDir, `${safeUserId(userId)}-${revision}.jpg`);
}

async function writeAvatar(storageDir, userId, revision, data) {
  validateJpeg(data);
  await fs.mkdir(storageDir, { recursive: true });
  const target = avatarPath(storageDir, userId, revision);
  const temporary = `${target}.${process.pid}.${Date.now()}.tmp`;
  try {
    await fs.writeFile(temporary, data, { flag: "wx", mode: 0o600 });
    await fs.rename(temporary, target);
  } catch (error) {
    await fs.rm(temporary, { force: true }).catch(() => {});
    throw error;
  }
  return target;
}

async function readAvatar(storageDir, userId, revision) {
  return fs.readFile(avatarPath(storageDir, userId, revision));
}

async function deleteAvatar(storageDir, userId, revision) {
  if (!revision) return;
  await fs.rm(avatarPath(storageDir, userId, revision), { force: true });
}

module.exports = {
  AvatarValidationError,
  MAX_AVATAR_BYTES,
  avatarPath,
  deleteAvatar,
  readAvatar,
  validateJpeg,
  writeAvatar,
};
