// Only the mobile app's server-side code exchange establishes the WeChat identity.
async function wechatIdentity(code) {
  if (typeof code !== "string" || !code.trim() || code.length > 1024) {
    throw Object.assign(new Error("需要有效的微信授权码"), { status: 400 });
  }
  const appID = process.env.WECHAT_APP_ID;
  const secret = process.env.WECHAT_APP_SECRET;
  const unavailable = () => Object.assign(new Error("微信登录服务暂不可用"), { status: 503 });
  if (!appID || !secret) throw unavailable();
  const endpoint = new URL("https://api.weixin.qq.com/sns/oauth2/access_token");
  endpoint.search = new URLSearchParams({ appid: appID, secret, code, grant_type: "authorization_code" });
  let result;
  try {
    const response = await fetch(endpoint, { redirect: "error", signal: AbortSignal.timeout(8000) });
    if (!response.ok) throw unavailable();
    result = await response.json();
  } catch {
    // Do not log the provider URL, authorization code, tokens or upstream response.
    throw unavailable();
  }
  if ([40029, 40163, 42003].includes(result?.errcode)) {
    throw Object.assign(new Error("微信授权已失效，请重新授权"), { status: 401 });
  }
  if (
    result?.errcode ||
    typeof result?.access_token !== "string" ||
    !result.access_token ||
    typeof result.openid !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(result.openid)
  )
    throw unavailable();
  return appID + ":" + result.openid;
}

module.exports = { wechatIdentity };
