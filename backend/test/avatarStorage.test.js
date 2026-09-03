const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

const {
  MAX_AVATAR_BYTES,
  deleteAvatar,
  readAvatar,
  validateJpeg,
  writeAvatar,
} = require("../src/services/avatarStorage");

function jpeg(payload = "avatar") {
  return Buffer.concat([Buffer.from([0xff, 0xd8]), Buffer.from(payload), Buffer.from([0xff, 0xd9])]);
}

test("validateJpeg rejects empty, oversized and non-JPEG data", () => {
  assert.throws(() => validateJpeg(Buffer.alloc(0)), /为空/);
  assert.throws(() => validateJpeg(Buffer.alloc(MAX_AVATAR_BYTES + 1, 1)), /1 MiB/);
  assert.throws(() => validateJpeg(Buffer.from("not jpeg")), /JPEG/);
});

test("write/read/delete avatar stays inside a temporary directory", async (t) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "qiuji-avatar-test-"));
  t.after(async () => fs.rm(directory, { recursive: true, force: true }));

  const data = jpeg();
  await writeAvatar(directory, "user_123", 1, data);
  assert.deepEqual(await readAvatar(directory, "user_123", 1), data);
  await deleteAvatar(directory, "user_123", 1);
  await assert.rejects(readAvatar(directory, "user_123", 1), { code: "ENOENT" });
});

test("unsafe user ids cannot escape the avatar directory", async () => {
  await assert.rejects(writeAvatar(os.tmpdir(), "../escape", 1, jpeg()), /用户标识无效/);
});
