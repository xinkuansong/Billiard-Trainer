# LeanCloud iOS Skill

## 触发场景

在以下情况读取并遵循本技能：
- 实现用户登录/注册（微信、手机验证码、Apple）
- 实现用户私有数据的云端同步
- 配置 LeanCloud SDK

> ⚠️ **人工前置**：H-06（LeanCloud 账号注册 + API Key）完成后才能执行本技能相关代码。

## SDK 集成

**安装方式**（SPM，见 `tasks/dependencies.md`）：
```
https://github.com/leancloud/swift-sdk
Product: LeanCloud
```

**初始化**（`QiuJiApp.swift`）：
```swift
import LeanCloud

@main struct QiuJiApp: App {
    init() {
        do {
            try LCApplication.default.set(
                id: AppConfig.leanCloudAppId,          // 来自 xcconfig，非硬编码
                key: AppConfig.leanCloudAppKey,
                serverURL: "https://your-domain.lc-cn-n1-shared.com"  // 华北节点
            )
        } catch { fatalError("LeanCloud init failed: \(error)") }
    }
}
```

**AppConfig 配置（`xcconfig` 注入）**：
```swift
// Config/AppConfig.swift
enum AppConfig {
    static var leanCloudAppId: String  { Bundle.main.infoDictionary!["LEANCLOUD_APP_ID"] as! String }
    static var leanCloudAppKey: String { Bundle.main.infoDictionary!["LEANCLOUD_APP_KEY"] as! String }
}
```

## 三种登录实现

### 1. Sign in with Apple
```swift
func loginWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
    guard let tokenData = credential.identityToken,
          let token = String(data: tokenData, encoding: .utf8) else { throw AppError.authFailed }
    let user = try await LCUser.loginWithApple(token: token)
    // 保存 user.objectId 到本地 Keychain
}
```

### 2. 手机验证码
```swift
// 发送验证码
func sendSMSCode(phone: String) async throws {
    try await LCSMSClient.requestVerificationCode(mobilePhoneNumber: phone)
}

// 验证登录
func loginWithSMS(phone: String, code: String) async throws {
    let user = try await LCUser.signUpOrLogIn(mobilePhoneNumber: phone, verificationCode: code)
}
```

### 3. 微信登录

> ⚠️ **人工前置**：H-05（微信开放平台资质审核通过）+ H-13（域名校验文件部署）。

```swift
// 1. 发起微信授权（在 AppDelegate/SceneDelegate 处理回调）
func loginWithWeChat() {
    let req = SendAuthReq()
    req.scope = "snsapi_userinfo"
    req.state = UUID().uuidString
    WXApi.send(req)
}

// 2. 在 AppDelegate 中处理回调
func onResp(_ resp: BaseResp) {
    guard let authResp = resp as? SendAuthResp, authResp.errCode == 0 else { return }
    Task { try await loginWeChatWithCode(authResp.code) }
}

// 3. 用 code 换 LeanCloud 登录
func loginWeChatWithCode(_ code: String) async throws {
    // LeanCloud 微信登录（需配置微信 AppID + AppSecret 在 LeanCloud 控制台）
    let user = try await LCUser.loginWithWeChat(code: code)
}
```

**Info.plist 必需配置**（见 `tasks/compliance-checklist.md`）：
```xml
<key>LSApplicationQueriesSchemes</key>
<array><string>weixin</string><string>weixinULAPI</string></array>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>wx${WECHAT_APP_ID}</string></array>
  </dict>
</array>
```

## 用户数据同步

```swift
// 上传训练记录到 LeanCloud
func syncSession(_ session: TrainingSession) async throws {
    let object = LCObject(className: "TrainingSession")
    try object.set("localId", value: session.id.uuidString)
    try object.set("date", value: session.date)
    try object.set("ballType", value: session.ballType)
    // ... 其他字段
    try await object.save()
}

// 拉取增量（登录后或前台恢复）
func fetchUserSessionsAfter(_ date: Date) async throws -> [LCObject] {
    let query = LCQuery(className: "TrainingSession")
    query.whereKey("updatedAt", .greaterThan(date))
    query.whereKey("userId", .equalTo(LCUser.current!.objectId!))
    return try await query.find()
}
```

## 匿名用户处理

```swift
// 检查登录状态
var isLoggedIn: Bool { LCUser.current != nil }

// 匿名用户尝试同步时的引导
func requireLogin(for action: String) -> Bool {
    guard isLoggedIn else {
        // 触发登录引导弹窗，传入 action 描述（如「多设备同步」）
        showLoginPrompt(reason: action)
        return false
    }
    return true
}
```

## 账号注销与数据删除（PIPL 要求）

```swift
// 用户申请删除账号
func deleteAccount() async throws {
    // 1. 删除 LeanCloud 用户对象及关联数据
    // 2. 清空本地 SwiftData（可选：保留离线副本）
    // 3. 退出登录
    try await LCUser.current?.delete()
    LCUser.logOut()
}
```
