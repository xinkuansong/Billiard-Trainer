# 依赖清单与 SDK 集成 SOP

> **负责角色**：iOS Architect + DevOps/Release
> **更新原则**：引入新依赖前在本文件评估，引入后记录版本。

---

## 一、Swift Package Manager 依赖

| 依赖 | 用途 | 仓库 URL | 最低版本要求 | 引入 Phase |
|------|------|---------|------------|----------|
| **Swift Charts**（系统内置） | 统计图表 | 系统库（iOS 16+，无需添加） | iOS 17 自带 | P6 |

> ~~LeanCloud Swift SDK~~（已于 ADR-001 移除，2026-03-29）：LeanCloud 停止国内新用户注册，改用自建 REST API 替代。

微信登录依赖本地 Swift 包 [CuePhysWeChat](../Packages/CuePhysWeChat/Package.swift)。App 用 SwiftPM 链接腾讯提供的 XCFramework 2.0.9，系统依赖及 SDK 的 PrivacyInfo.xcprivacy 由包声明。已将官方压缩包原样固定在仓库，供没有外网的构建使用。[官方二进制](https://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.9.zip) · [发布规格](https://trunk.cocoapods.org/api/v1/pods/WechatOpenSDK-XCFramework/specs/2.0.9)

## 二、微信登录配置（W6b）

- 上述 ZIP 的 SHA-256 为 `ebbdd935f840bedabe1c39ad6149356b37764645ff939ce0160a438520545697`。升级时从腾讯源取包、核对 SDK 模块、真机和模拟器架构、附带的隐私清单及授权接口，再分别构建与回归。主 App 通过 project.yml 引用包，链接参数包含 `-ObjC`。
- 已获移动应用资质后，把**完整**微信 AppID（含 wx 前缀）写入 `WECHAT_APP_ID`，客户端回调 Scheme 使用该值一次。AppSecret 仅在后端配置。后端要求 HTTPS；绑定还需本次账号的会话。
- 打开公司正式 App ID 的 Associated Domains 能力并更新签名配置。将 `WECHAT_LINK_HOST` 设为实际 HTTPS 域名（计划 cuephys.com），`WECHAT_UNIVERSAL_LINK` 设为平台注册的同域目录（计划 `https://cuephys.com/wechat/`，xcconfig 中用 `https:/$()/cuephys.com/wechat/`）。在目标配置中设 `CUEPHYS_ENTITLEMENTS = Config/WeChat.entitlements`。普通个人开发配置沿用原 Apple entitlement。
- 域名启用后，在 `/.well-known/apple-app-site-association` 提供 JSON，使用真实已签名 App 的 application-identifier。以下是准备模板，发布前以公司签名包回读的值替换占位。核对无重定向的 HTTPS 响应、签名权限及设备上实际 Universal Link 回调。

```json
{"applinks":{"apps":[],"details":[{"appID":"<已签名 App 的 application-identifier>","paths":["/wechat/*"]}]}}
```

- SwiftUI 入口接收 URL Scheme 和 Universal Link；授权后由 SDK 验证响应，App 只接收与当前随机 state 匹配的 code。新登录方式先查询已有身份，用户选择创建账号才发创建请求；已有账号从设置中绑定。正式 AppID、微信授权成功／拒绝／中断、Apple 真机授权及线上回执待验。

---

## 三、自建后端 API 客户端集成（ADR-001）

> 替代原 LeanCloud Swift SDK，使用系统原生 `URLSession` + `async/await`，零额外依赖。

### 3.1 APIClient 设计

```swift
// Data/Services/APIClient.swift
final class APIClient {
    static let shared = APIClient()
    private let baseURL = AppConfig.apiBaseURL   // 从 xcconfig 注入
    private let session = URLSession.shared

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        req.httpMethod = endpoint.method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainService.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = endpoint.body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw AppError.networkUnavailable }
        if http.statusCode == 401 { throw AppError.authRequired }
        guard (200..<300).contains(http.statusCode) else {
            let err = try? JSONDecoder().decode(APIError.self, from: data)
            throw AppError.serverError(err?.message ?? "未知错误")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

### 3.2 xcconfig 配置

`Config/Debug.xcconfig` 新增：
```
API_BASE_URL = https://dev.api.qiuji.app
```
`Config/Release.xcconfig` 通过 Secrets.xcconfig 覆盖为生产地址。

将变量注入 `Info.plist`：
```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
```

### 3.3 JWT 存储（Keychain）

```swift
// Data/Services/KeychainService.swift
enum KeychainService {
    static var accessToken: String? { get/set }   // Keychain 读写
    static var refreshToken: String? { get/set }
    static func clear()
}
```

### 3.4 后端部署 SOP（见 HUMAN-REQUIRED H-14 ~ H-16）

后端仓库独立维护（建议命名 `qiuji-backend`），部署到腾讯云轻量服务器。

---

## ~~三（旧）、LeanCloud Swift SDK 集成 SOP~~

> **已废弃（ADR-001，2026-03-29）**：LeanCloud 停止国内新用户注册。

---

## 四、系统库使用清单（无需安装）

| 库 | 用途 |
|----|------|
| `SwiftData` | 本地持久化 |
| `Foundation`（`URLSession`） | 自建 REST API（用户同步 + Drill/计划 OTA，ADR-002） |
| `StoreKit` | IAP 订阅 |
| `AuthenticationServices` | Sign in with Apple |
| `Charts`（Swift Charts） | 统计图表 |
| `OSLog` | 本地日志 |

---

## 五、版本锁定策略

- SPM 依赖：微信 SDK 版本及压缩包摘要见第二节。
- 微信 SDK 手动更新：每季度检查一次，大版本升级前在测试分支验证
- 依赖版本变更必须在本文件更新记录：

| 依赖 | 当前版本 | 上次更新 |
|------|---------|---------|
| ~~LeanCloud Swift SDK~~ | ~~TBD~~ | 已移除（ADR-001） |
| 微信 iOS SDK | 2.0.9（腾讯 XCFramework） | 2026-11-10 |
