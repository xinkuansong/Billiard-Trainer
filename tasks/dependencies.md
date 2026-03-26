# 依赖清单与 SDK 集成 SOP

> **负责角色**：iOS Architect + DevOps/Release
> **更新原则**：引入新依赖前在本文件评估，引入后记录版本。

---

## 一、Swift Package Manager 依赖

| 依赖 | 用途 | 仓库 URL | 最低版本要求 | 引入 Phase |
|------|------|---------|------------|----------|
| **LeanCloud Swift SDK** | 用户认证 + 数据同步 | `https://github.com/leancloud/swift-sdk` | 最新稳定版 | P1 |
| **Swift Charts**（系统内置） | 统计图表 | 系统库（iOS 16+，无需添加） | iOS 17 自带 | P6 |

> 当前 SPM 依赖精简为 1 个第三方库，充分利用系统能力。

---

## 二、微信 SDK（非 SPM，需手动集成）

> ⚠️ 微信 SDK **不支持 SPM**，需手动集成。人工前置：H-05 完成后执行。

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

## 三、LeanCloud Swift SDK 集成 SOP

> H-06 完成后执行（需要 App ID 和 App Key）。

### 3.1 SPM 添加

1. Xcode → File → Add Package Dependencies
2. 输入：`https://github.com/leancloud/swift-sdk`
3. 选择版本：**Up to Next Major**（最新稳定版）
4. 勾选 Product：`LeanCloud`

### 3.2 初始化配置

`Config/Debug.xcconfig` 配置项（不提交 Git，使用 `Secrets.xcconfig` 存真实值）：

```
// Debug.xcconfig 示例（占位符）
LEANCLOUD_APP_ID = YOUR_APP_ID_HERE
LEANCLOUD_APP_KEY = YOUR_APP_KEY_HERE
LEANCLOUD_SERVER_URL = https://your-domain.lc-cn-n1-shared.com

// Secrets.xcconfig（加入 .gitignore，填真实值）
LEANCLOUD_APP_ID = abc123...
LEANCLOUD_APP_KEY = xyz456...
LEANCLOUD_SERVER_URL = https://abc123.lc-cn-n1-shared.com
```

将 `xcconfig` 中的变量注入 `Info.plist`：
```xml
<key>LEANCLOUD_APP_ID</key>
<string>$(LEANCLOUD_APP_ID)</string>
<key>LEANCLOUD_APP_KEY</key>
<string>$(LEANCLOUD_APP_KEY)</string>
<key>LEANCLOUD_SERVER_URL</key>
<string>$(LEANCLOUD_SERVER_URL)</string>
```

### 3.3 LeanCloud 控制台配置

登录 [LeanCloud 控制台](https://console.leancloud.cn) 后：
1. **开启短信服务**：设置 → 短信 → 开启「验证码服务」
2. **配置微信登录**（H-05 完成后）：内建账号 → 第三方账号 → 微信，填入微信 AppID + AppSecret
3. **配置 Apple 登录**：内建账号 → 第三方账号 → Apple，填入 App Bundle ID
4. **设置数据 ACL**：存储 → 设置 → Class 默认权限，TrainingSession 等设为「仅创建者可读写」

---

## 四、系统库使用清单（无需安装）

| 库 | 用途 |
|----|------|
| `SwiftData` | 本地持久化 |
| `CloudKit` | 公开内容热更新 |
| `StoreKit` | IAP 订阅 |
| `AuthenticationServices` | Sign in with Apple |
| `Charts`（Swift Charts） | 统计图表 |
| `OSLog` | 本地日志 |

---

## 五、版本锁定策略

- SPM 依赖使用 **Up to Next Major**（允许 minor/patch 自动更新）
- 微信 SDK 手动更新：每季度检查一次，大版本升级前在测试分支验证
- 依赖版本变更必须在本文件更新记录：

| 依赖 | 当前版本 | 上次更新 |
|------|---------|---------|
| LeanCloud Swift SDK | TBD（集成时填写） | — |
| 微信 iOS SDK | TBD（集成时填写） | — |
