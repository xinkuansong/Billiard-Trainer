# CuePhys 微信回跳产品路径定稿

2026-11-24：用户确认公司域名下按产品划分回跳路径。本记录覆盖此前 `/wechat/` 方案中的当前填写值。

**微信后台 iPhone 与 iPad 两栏均填写 `https://youbilliards.com/cuephys/wechat/`，末尾斜杠保留。Bundle ID 仍为 `com.youbilliards.cuephys`。** 本轮未操作微信后台，用户若已填旧路径，须同步替换；没有代替用户提交申请。

## 已执行和验证

- 公共 App 配置 `Config/WeChatLinks.xcconfig` 改为新链接；Debug/Release 共用。域名权限继续为 `applinks:youbilliards.com`。
- 官网 AASA 只匹配 `/cuephys/wechat/*`，appID 为 `KWH2GRNSKG.com.youbilliards.cuephys`；Nginx 回退入口同步改到新路径。
- 正式官网版本 `0dd87119437e67a5c18b06664369cfc156addcd1` 已部署，42 文件 SHA-256 校验通过；上一版 `0cf759fdb5ba8709fc0db81cb264a9ded8ceade4` 保留。Nginx 备份 `/var/backups/youbilliards/cuephys-path-20261124T162758/nginx.conf`。
- 官网生产 build/check：8 页、258 链接、0 错误；release 测试 1/1 通过；Ubuntu 隔离 Nginx/TLS/回调/隐藏文件/回滚/日志检查通过。
- 公网 AASA 为 200 application/json，路径规则为新值；新入口及 `/auth` 子路径均 200，无重定向；旧 `/wechat/` 为 404，隐藏文件仍 403；支持页与 API health 正常。
- 新一轮 generic iOS 签名 Debug 构建成功；实际包 Info.plist 链接、签名 application-identifier、Associated Domains、设备族 `[1,2]` 回读断言通过。Release 构建设置展开为新链接；未执行 Release Archive 或真机唤起。
- Apple CDN 仍返回此前的失败缓存，未视为设备关联完成。等待刷新并取得真实微信 AppID/Secret 后，继续 iPhone/iPad 微信登录与回跳验证。

公网、发布、隔离测试、Release 设置证据：`output/wechat-product-path-20261124/`。签名构建与产物回读：`output/local-test-runs/259697091aa34bfcab19f4f7c6a136d4/evidence/`，临时构建目录已自动回收。官网提交已本地保存，本轮未推送 GitHub。

回滚：用现行 `/opt/youbilliards-ops/switch-release.py` 切回前版，恢复上述 nginx.conf 备份，`nginx -t` 后 reload。App 配置和微信后台须随同回退，不得留下三方路径不一致。

## 微信申请已提交回执

2026-11-24 用户提供创建成功页：移动应用已创建并提交审核，页面预计 1–7 个工作日，复杂逻辑或特殊情况可能延长；审核通过后可获得 AppID 和 AppSecret。记录日期为收到回执的日期，截图未显示提交时分或申请编号，不补造。当前为审核中，不是已通过。

[回执截图](../../output/wechat-submission-20261124/submitted.png)。页面未展示最终平台字段详情，因此不将此回执视为 iPhone/iPad 字段再次读回；AppID/Secret 获取、SDK/后端配置、Apple CDN 与双设备回跳验证仍待后续。
