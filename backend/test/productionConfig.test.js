const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const { mkdtempSync, rmSync } = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { randomBytes } = require("node:crypto");
const test = require("node:test");

test("server refuses invalid signing keys before connecting or listening", t => {
  const cwd = mkdtempSync(path.join(os.tmpdir(), "cuephys-startup-"));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  const key = () => randomBytes(32).toString("hex");
  for (const [mode, access, refresh, field] of [
    ["production", "", key(), "JWT_SECRET"],
    ["production", key(), "", "JWT_REFRESH_SECRET"],
    ["production", "dev-secret-change-me", key(), "JWT_SECRET"],
    ["production", key(), "change-me-to-another-random-string", "JWT_REFRESH_SECRET"],
    ["production", key(), "too-short", "JWT_REFRESH_SECRET"],
    ["production", key(), " ".repeat(32), "JWT_REFRESH_SECRET"],
    ["production", key(), null, "distinct"],
    ["", "", key(), "JWT_SECRET"],
  ]) {
    const result = spawnSync(process.execPath, [require.resolve("../server")], {
      cwd, encoding: "utf8", timeout: 5000,
      env: { NODE_ENV: mode, JWT_SECRET: access, JWT_REFRESH_SECRET: refresh ?? access,
        MONGODB_URI: "mongodb://127.0.0.1:1/fixture" },
    });
    assert.equal(result.status, 1);
    assert.ok(result.stderr.includes(field));
    assert.doesNotMatch(result.stdout, /connected|listening/i);
    for (const value of [access, refresh]) {
      if (value && value.trim()) assert.ok(!result.stderr.includes(value));
    }
  }
});

test("production accepts independent keys and signs and verifies both token types", () => {
  const program = `
    const jwt = require(process.argv[1]);
    const access = jwt.signAccessToken("fixture");
    const refresh = jwt.signRefreshToken("fixture");
    require("node:assert/strict").equal(jwt.verifyAccessToken(access).sub, "fixture");
    require("node:assert/strict").equal(jwt.verifyRefreshToken(refresh).sub, "fixture");
    require("node:assert/strict").throws(() => jwt.verifyAccessToken(refresh));
  `;
  const result = spawnSync(process.execPath, ["-e", program, require.resolve("../src/utils/jwt")], {
    env: { NODE_ENV: "production", JWT_SECRET: randomBytes(32).toString("hex"),
      JWT_REFRESH_SECRET: randomBytes(32).toString("hex") },
  });
  assert.equal(result.status, 0);
});
