# ASC Bundle ID 切换排障调研（2026-11-23）

## 官方流程核对

Apple 官方说明：如果 App Store Connect 的 App 记录尚未上传 build，可以修改 Bundle ID；步骤是先在真机上构建并运行新 Bundle ID，使 App ID 和 provisioning profile 注册/更新，再回到现有 App 的 App Information 页面，从 Bundle ID 菜单选择新 ID 并保存。

- [Changing the bundle identifier](https://developer.apple.com/documentation/xcode/changing-the-bundle-identifier)
- [Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/)
- [App information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information/)

## 已核实事实

- 现有 App Store Connect App：`6761309682`。
- 版本页目前没有上传 build，因此仍处于可切换窗口。
- Apple Developer 新显式 App ID：`com.youbilliards.cuephys`；已启用当前工程使用的 Associated Domains 和 Sign in with Apple。
- iPhone 16 Pro 真机已成功构建、安装、启动新包；Xcode 签发的开发描述文件与新 Bundle ID 一致。
- ASC 现有 App 的 Bundle ID 下拉仍只有 `QiuJi App - com.xinkuan.qiuji`，新 ID 没有出现。

### 用户新截图补充

- 用户在 App Store Connect 的“综合信息”下拉中已看到 `CuePhys - com.youbilliards.cuephys`，说明 ASC 侧同步已完成。
- 当前页面仍显示旧值 `QiuJi App - com.xinkuan.qiuji`，需要点右侧下拉箭头，选择第一项 CuePhys，再点击页面底部 Save/存储；下面的 `XC com...` 项是实验/辅助 App，不应选。

## 结论

本问题已排除工程 Bundle ID、真机注册和开发签名这三个本地原因。用户新截图显示新 ID 已出现在 ASC 菜单，说明同步已完成；当前只剩在现有 App 记录中选择新 ID 并保存。没有必要新建 App 记录。

Apple Developer [System Status](https://developer.apple.com/system-status/) 当前没有列出 App Store Connect、App Processing、App Upload 或 Certificates/Identifiers/Profiles 的进行中事件；因此暂不能把它归因于公开的系统级故障。

## 安全排障顺序

1. 在 Apple Developer 与 App Store Connect 分别确认当前登录的是同一个组织 Team（Team ID `KWH2GRNSKG`），并确认 Account Holder/Admin 权限与付费协议状态正常。
2. 在同一组织下重新打开 App ID 详情，确认 `com.youbilliards.cuephys` 没有被其他 App 记录或其他 Team 使用；不删除旧 ID。
3. 退出 ASC、重新登录并用新标签页复查 Bundle ID 菜单；保留新 ID 已在真机运行的证据。
4. 若从真机注册起超过一个工作日仍只有旧值，向 Apple Developer Support 提交“existing App record Bundle ID menu not showing newly registered explicit App ID”的后台同步请求，附 App ID `6761309682`、旧/新 Bundle ID、Team ID、真机运行时间和截图。
5. 在新 ID 出现前，禁止保存旧值、上传旧 Bundle ID build、删除 App 记录或创建重复 App；官方文档明确上传 build 后 Bundle ID 将不能再改。

## 给 Apple 支持的工单要点（暂不代发）

> Existing App Store Connect app `6761309682` has no uploaded build. We registered the explicit App ID `com.youbilliards.cuephys` under Team ID `KWH2GRNSKG`, enabled the capabilities used by the app, and built and ran it successfully on a physical iPhone. However, the Bundle ID menu in App Information still shows only `com.xinkuan.qiuji`; the new identifier is absent. Please refresh or repair the association between the existing app record and the newly registered Bundle ID. We have not uploaded a build, saved the old identifier, or created a duplicate app.

附件应包括：App Information 页面下拉截图、新 App ID 详情截图、真机构建/签名证据，以及现有 App Apple ID `6761309682`。不要附私钥、验证码或完整 JWT。

## 本轮没有做的事

- 未上传 build、未创建重复 App、未删除旧 App ID。
- 未创建生产 Apple 登录密钥；该动作要等 Bundle ID 关联确定、HTTPS 和服务端 `aud` 一致后再做。
