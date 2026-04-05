# 依赖清单与 SDK 集成 SOP

> **负责角色**：iOS Architect + DevOps/Release
> **更新原则**：引入新依赖前在本文件评估，引入后记录版本。

---

## 一、Swift Package Manager 依赖

| 依赖 | 用途 | 仓库 URL | 最低版本要求 | 引入 Phase |
|------|------|---------|------------|----------|
| **Swift Charts**（系统内置） | 统计图表 | 系统库（iOS 16+，无需添加） | iOS 17 自带 | P6 |

> ~~LeanCloud Swift SDK~~（已于 ADR-001 移除，2026-03-29）：LeanCloud 停止国内新用户注册，改用自建 REST API 替代。

> **当前 SPM 第三方依赖为 0 个**，全部使用系统能力 + 自建后端 REST API（URLSession）。

---

## 二、微信 SDK（非 SPM，需手动集成）

> ⚠️ 微信 SDK **不支持 SPM**，需手动集成。人工前置：H-05 完成后执行。
>
> **与原方案的区别（ADR-001）**：微信 OAuth 的 AppSecret 不再放客户端，客户端只传 `code`，由自建后端完成 code-to-token 换取，保证 AppSecret 安全。

### 2.1 集成步骤

**Step 1：下载 SDK**
- 前往 [微信开放平台 SDK 下载](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Resource_Center_and_FAQ/iOS_Resource.html)
- 下载最新版 iOS SDK（`WeChatSDK_xxx.zip`）

**Step 2：添加到 Xcode 项目**
```
将以下文件拖入 Xcode 项目（Target: QiuJi）：
├── libWeChatSDK.a          （静态库，或 .xcframework）
├── WXApi.h
├── WXApiObject.h
└── WechatAuthSDK.h
```
- 在 Xcode → Build Settings → Other Linker Flags 添加：`-ObjC`

**Step 3：系统 Framework 依赖**

在 Xcode → Target → General → Frameworks, Libraries 添加：
- `CoreTelephony.framework`
- `SystemConfiguration.framework`
- `libz.tbd`
- `libc++.tbd`

**Step 4：Bridging Header（Swift 项目）**

创建 `QiuJi-Bridging-Header.h`：
```objc
#import "WXApi.h"
#import "WXApiObject.h"
```

在 Xcode → Build Settings → Objective-C Bridging Header 填写路径。

**Step 5：AppDelegate 注册**
```swift
// AppDelegate.swift
import UIKit

@objc class AppDelegate: NSObject, UIApplicationDelegate, WXApiDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        WXApi.registerApp(AppConfig.wechatAppId, universalLink: AppConfig.wechatUniversalLink)
        return true
    }

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return WXApi.handleOpen(url, delegate: self)
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return WXApi.handleOpenUniversalLink(userActivity, delegate: self)
    }

    // WXApiDelegate 回调
    func onReq(_ req: BaseReq) {}
    func onResp(_ resp: BaseResp) {
        NotificationCenter.default.post(name: .wechatAuthResponse, object: resp)
    }
}

extension Notification.Name {
    static let wechatAuthResponse = Notification.Name("WechatAuthResponse")
}
```

**Step 6：SwiftUI App Entry 接入 AppDelegate**
```swift
@main struct QiuJiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // ...
}
```

### 2.2 Info.plist 配置（完整）

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>weixin</string>
    <string>weixinULAPI</string>
</array>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>wx$(WECHAT_APP_ID)</string>
        </array>
    </dict>
</array>
```

> `$(WECHAT_APP_ID)` 从 `xcconfig` 注入，不硬编码。

### 2.3 Universal Links 配置（H-13）

在你的域名根目录部署（必须 HTTPS）：
```
https://yourdomain.com/apple-app-site-association
```

文件内容：
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appIDs": ["TEAMID.com.yourname.billiardtrainer"],
        "paths": ["/wechat/*"]
      }
    ]
  }
}
```

在微信开放平台填写 Universal Link：`https://yourdomain.com/wechat/`

> **临时方案（无域名时）**：使用 URL Scheme（`wx{AppID}://`）替代 Universal Links。在微信开放平台勾选「不使用 Universal Links」。需在 ADR 中记录，App Store 发布前补全。

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

- SPM 依赖：当前无第三方依赖
- 微信 SDK 手动更新：每季度检查一次，大版本升级前在测试分支验证
- 依赖版本变更必须在本文件更新记录：

| 依赖 | 当前版本 | 上次更新 |
|------|---------|---------|
| ~~LeanCloud Swift SDK~~ | ~~TBD~~ | 已移除（ADR-001） |
| 微信 iOS SDK | TBD（集成时填写） | — |
