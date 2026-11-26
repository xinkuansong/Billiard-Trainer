# 外部平台接续核对

2026-11-25 19:22（北京时间）。用户授权继续核对付费协议／商品、微信审核与配置、App备案当前状态。

## 已完成的本轮检查

- 当前提交含本月概览修复 `2194d76c`；主App `com.youbilliards.cuephys`、扩展 `com.youbilliards.cuephys.liveactivity`、Team `KWH2GRNSKG` 的工程声明一致。
- Release 私密配置存在，API值与 `https://api.cuephys.com` 一致；仅核对布尔结果，未打印密钥。私密配置中没有真实微信AppID；Debug仍为占位值。
- 首发代码仍只请求并购买 `com.youbilliards.cuephys.premium.lifetime`，类型限定非消耗型；这不能证明正式后台已创建商品。
- 实时HTTPS检查：API健康、两份法律页、官网AASA、Apple CDN AASA均HTTP 200。两份AASA均为 `KWH2GRNSKG.com.youbilliards.cuephys` 和 `/cuephys/wechat/*`，与 `Config/WeChatLinks.xcconfig` 一致。证据：`output/platform-check-20261125/public-endpoints.json`。
- 已纠正主方案和商品核对表的当前状态入口：Apple生产凭据／同账号重登及冷启动已在当日真机验收；不再据旧文重复创建密钥。Store Server Notifications 不新增为本次首发必做项，沿用整改 I22 的范围决定。

## 当前明确阻塞

CUA首次调用因闲置重置，重新初始化后返回 `Browsers: Error: Local browser access is unavailable for this chat`，浏览器列表为空。只读取到了应用清单，没有读取任何控制台正文。未通过其他通道绕过访问限制，已请用户恢复本会话浏览器访问。

因此以下均为**待实时核实**，不是本轮确认的最新平台状态：

| 平台 | 恢复后读取内容 | 达标依据 |
|---|---|---|
| ASC商务 | 法律实体待办、付费协议是否出现接受入口、协议／税务／银行状态 | 当前页面正文；不把历史“新”状态推定为今天仍未变 |
| ASC内购 | App 6761309682下永久商品ID、类型、状态、价格、销售范围及缺失字段 | 实际商品详情；不以本地StoreKit代替 |
| 微信开放平台 | 企业认证结果、CuePhys移动应用是否已提交／获批、AppID和登录权限、Universal Link | 当前应用详情和审核回执；Secret不展示或写入Git |
| 腾讯云备案 | CuePhys App订单是否已提交、受理／退回／补件情况、App备案号 | 当前订单／回执；网站备案号不代替App备案号 |

恢复后先完成上述只读核对，再安排具备条件的真实OAuth和沙盒支付。首次新身份／绑定／注销用专用测试账号；不注销用户当前账号。本轮没有接受协议、创建商品、购买、上传build、提交备案或提审，也没有继续操作真机。

## 新会话接续诊断（2026-11-25，北京时间）

- 已读取原会话最近进展与当前验收记录，接续目标仍是上表四个平台的只读核对，不重复已经完成的球桌资源修复和真机验证。
- 当前会话显式打开 Edge、读取 CUA 状态均在 30 秒后超时；执行 `js_reset` 后再次显式打开 Edge 仍超时。三次均未取得控制台正文。
- 桌面客户端日志中，当前会话的 IAB 初始化多次报 `IAB browser belongs to another task.`；也有个别 getInfo 成功记录。因此确认存在会话归属错误，但尚不能证明它是 Edge 超时的唯一根因。早前 Chrome 扩展探测的 EPERM 不据此归因为本轮 Edge 故障。
- 脱敏日志摘要：`output/platform-check-20261125/browser-handoff-diagnostic.txt`。未改浏览器配置、跨会话归属、权限或客户端内部状态；未终止其他任务。
- 下一步：由用户尝试关闭客户端浏览器面板并重新进入本聊天；若仍失败，保存其他工作后重启桌面客户端，再从 ASC 商务页恢复核对。这是连接恢复尝试，尚未验证有效。Apple、微信和腾讯云后台状态继续标为待实时核实。
