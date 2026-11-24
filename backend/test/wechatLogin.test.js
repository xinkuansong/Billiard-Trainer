const assert = require("node:assert/strict");
const test = require("node:test");
const { wechatIdentity } = require("../src/services/wechatLogin");

test("WeChat exchange fails closed when approval-gated login is disabled", async t => {
  const previous = process.env.WECHAT_LOGIN_ENABLED;
  t.after(() => {
    if (previous === undefined) delete process.env.WECHAT_LOGIN_ENABLED;
    else process.env.WECHAT_LOGIN_ENABLED = previous;
  });
  process.env.WECHAT_LOGIN_ENABLED = "false";
  await assert.rejects(
    () => wechatIdentity("fixture-code"),
    error => error?.status === 503 && error.message === "微信登录服务暂不可用"
  );
});
