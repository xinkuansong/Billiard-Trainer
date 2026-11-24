# 微信 Universal Links 部署与验证

> 历史初次部署记录。用户随后确定产品路径，当前请使用 `https://youbilliards.com/cuephys/wechat/`，详见[最新验证](微信UniversalLinks产品路径调整-20261124.md)。下方旧路径与证据保留用于追溯。

日期：2026-11-24。用户授权配置可实际使用的地址，以继续微信移动应用申请。

## 表单填写值

| 字段 | iPhone 与 iPad 共用值 |
|---|---|
| Bundle ID | `com.youbilliards.cuephys` |
| Universal Links | `https://youbilliards.com/wechat/`（保留末尾斜杠） |
| 测试版本 Bundle ID | 没有独立测试应用标识时留空 |
| 应用已上架 | 否；本轮未上传 build 或发布应用 |

官网承担 App 的 HTTPS 回跳关联，API 仍为 `https://api.cuephys.com`，两者用途不同。选已有网站备案与有效 HTTPS 的公司域名，未启用尚未核实的 cuephys.com 根域网站，也未将网站备案当成 App 备案。

## 已执行

- 官网 `public/.well-known/apple-app-site-association` 声明 `KWH2GRNSKG.com.youbilliards.cuephys`，仅匹配 `/wechat/*`。应用标识与现有公司 profile、实际新签名 Debug 包回读一致。
- Nginx 精确放行 AASA，类型 application/json，无重定向；其余隐藏文件继续拒绝。`/wechat/` 与子路径浏览器回退到既有产品页，不回显 OAuth 参数。
- Debug/Release 均选用 `Config/WeChat.entitlements`。公共配置 `Config/WeChatLinks.xcconfig` 固定域名和链接；Release 在私有配置之后包含该文件，避免旧空值覆盖。
- 官网正式版本 `0cf759fdb5ba8709fc0db81cb264a9ded8ceade4` 已部署，逐文件 SHA-256 校验后原子切换；前版 `8a038cf9108f35306410f252efe0ae2518d26490` 保留。官网源码提交已在本地保存，本轮未推送 GitHub。
- 同步服务器过期的切换脚本，使其与仓库已有八页正式发布白名单一致。备份：`/var/backups/youbilliards/universal-links-20261124T161748/`。

## 验证证据与边界

1. 官网 `build:release`、`check:release` 通过：8 页、258 链接、0 错误；release 测试 1/1 通过。
2. Ubuntu 隔离 Nginx/TLS 测试通过：AASA 200/JSON/无重定向，回调子路径 200，隐藏文件 403；原子切换/回滚、日志保留与轮转检查通过。
3. 正式 `nginx -t` 通过并完成 reload；公网 AASA、回调、首页、支持页、两份 App 法律页均 200，无重定向；`.env` 与 `/wechat/.env` 均 403；原后端 health 正常。
4. `make build` 对 generic iOS 设备执行，实际输出 BUILD SUCCEEDED。新签名包的 application-identifier、Associated Domains、Info.plist 中完整 HTTPS 链接及设备族 `[1,2]` 均断言通过。Debug/Release 构建设置展开一致；本轮未执行 Release Archive，也未安装或唤起真机。
5. **Apple CDN 尚未刷新**：最终检查仍返回 404，Apple-Failure-Reason 为旧的 `403 Forbidden`；源站现已 200。返回缓存 max-age=3600，本次 Age=71。此值不保证一小时后设备一定刷新，后续须重新查 CDN 并验证最终签名包回跳。Apple 关联域说明：[官方文档](https://developer.apple.com/documentation/xcode/supporting-associated-domains)。
6. **微信 AppID/Secret 尚未取得**，因此微信登录入口继续由既有配置门禁关闭。本轮完成申请地址和源站/签名配置，未将其标成微信 OAuth 登录成功。

证据：`output/wechat-universal-links-20261124/`（公网、部署、配置、隔离测试）；签名构建与回读：`output/local-test-runs/3d27556a97c0413fa3932255b43cf582/evidence/`。构建临时工作目录已由生命周期工具回收。

部署过程保留两次失败原始记录：首次 dry-run 发现服务器切换脚本仍为六页白名单，未切换；第二次 reload 后立即探测命中旧 worker，自动回滚成功。最终使用有界重试等待 reload 生效，AASA 第 2 次请求成功，其余第 1 次成功；没有删除旧版或放宽页面/隐藏文件检查。

## 后续闭环

- 用户在微信 iPhone、iPad 栏填上述同一地址并完成创建/提交；记录真实回执与 AppID。
- 获得 AppID 后更新客户端回调 Scheme/SDK 注册及后端 AppID；AppSecret 仅保存服务端，不能进 App、文档或 Git。
- 重新验证 Apple CDN，最终签名包在 iPhone/iPad 上验证微信授权成功、取消、超时和回跳；验证期间不将开发绕过 CDN 模式带入正式包。
- 回滚：用 `/opt/youbilliards-ops/switch-release.py` 切回前版，恢复上述备份 nginx.conf，`nginx -t` 通过后 reload；保留更新后的八页切换脚本才能回滚现有八页正式版本。
