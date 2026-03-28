# REST API Backend (自建后端) Skill

> **替代 LeanCloud**（ADR-001，2026-03-29）：LeanCloud 停止国内新用户注册，改用腾讯云 Node.js + MongoDB 自建后端。

## 触发场景

在以下情况读取并遵循本技能：
- 实现用户登录/注册（微信 OAuth、手机验证码、Sign in with Apple）
- 实现用户私有数据的云端同步（训练记录、角度测试历史）
- 实现 JWT 管理与自动刷新
- 配置 `APIClient` 或 `BackendSyncService`

> ⚠️ **人工前置**：H-14（腾讯云服务器已购买部署）、H-15（腾讯云短信已申请）完成后才能执行相关功能。

---

## APIClient 核心实现

```swift
// Data/Services/APIClient.swift
final class APIClient {
    static let shared = APIClient()
    private let baseURL = AppConfig.apiBaseURL   // 从 xcconfig 注入，非硬编码
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

**AppConfig 配置（`xcconfig` 注入）**：
```swift
// Core/Extensions/AppConfig.swift
enum AppConfig {
    static var apiBaseURL: URL {
        let raw = Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? "https://api.qiuji.app"
        return URL(string: raw) ?? URL(string: "https://api.qiuji.app")!
    }
    static var wechatAppId: String {
        Bundle.main.infoDictionary?["WECHAT_APP_ID"] as? String ?? ""
    }
}
```

---

## 三种登录实现

### 1. 手机验证码登录

```swift
// 发送验证码
func sendSMSCode(phone: String) async throws {
    let body = ["phone": phone]
    let _: EmptyResponse = try await APIClient.shared.request(
        .post("/auth/send-sms", body: body)
    )
}

// 验证码登录/注册
func loginWithSMS(phone: String, code: String) async throws {
    struct Req: Encodable { let phone, code: String }
    struct Res: Decodable { let accessToken, refreshToken: String; let user: UserDTO }
    let res: Res = try await APIClient.shared.request(
        .post("/auth/login-sms", body: Req(phone: phone, code: code))
    )
    KeychainService.accessToken = res.accessToken
    KeychainService.refreshToken = res.refreshToken
    // 更新 AuthState
}
```

### 2. 微信登录

```swift
// 客户端只传 code，AppSecret 在服务端完成换取（安全）
func loginWithWechat(code: String) async throws {
    struct Req: Encodable { let code: String }
    struct Res: Decodable { let accessToken, refreshToken: String; let user: UserDTO }
    let res: Res = try await APIClient.shared.request(
        .post("/auth/login-wechat", body: Req(code: code))
    )
    KeychainService.accessToken = res.accessToken
    KeychainService.refreshToken = res.refreshToken
}
```

### 3. Sign in with Apple

```swift
func loginWithApple(identityToken: String) async throws {
    struct Req: Encodable { let identityToken: String }
    struct Res: Decodable { let accessToken, refreshToken: String; let user: UserDTO }
    let res: Res = try await APIClient.shared.request(
        .post("/auth/login-apple", body: Req(identityToken: identityToken))
    )
    KeychainService.accessToken = res.accessToken
    KeychainService.refreshToken = res.refreshToken
}
```

---

## JWT 自动刷新

```swift
// 401 时自动 refresh，失败则跳转登录
func refreshTokenIfNeeded() async throws {
    guard let refresh = KeychainService.refreshToken else { throw AppError.authRequired }
    struct Req: Encodable { let refreshToken: String }
    struct Res: Decodable { let accessToken: String }
    let res: Res = try await APIClient.shared.request(
        .post("/auth/refresh", body: Req(refreshToken: refresh))
    )
    KeychainService.accessToken = res.accessToken
}
```

---

## 用户数据同步

```swift
// BackendSyncService.swift
func syncSession(_ session: TrainingSession) async throws {
    let dto = TrainingSessionDTO(from: session)
    let _: EmptyResponse = try await APIClient.shared.request(
        .post("/training-sessions", body: dto)
    )
}

// 增量拉取（登录后或前台恢复）
func fetchUserSessionsAfter(_ date: Date) async throws -> [TrainingSessionDTO] {
    let iso = ISO8601DateFormatter().string(from: date)
    return try await APIClient.shared.request(
        .get("/training-sessions?after=\(iso)")
    )
}

// 匿名用户登录后批量迁移
func migrateLocalSessions(_ sessions: [TrainingSession]) async throws {
    let dtos = sessions.map { TrainingSessionDTO(from: $0) }
    let _: EmptyResponse = try await APIClient.shared.request(
        .post("/training-sessions/batch", body: dtos)
    )
}
```

---

## 匿名用户处理

```swift
// 检查登录状态
var isLoggedIn: Bool { KeychainService.accessToken != nil }

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

---

## 账号注销与数据删除（PIPL 要求）

```swift
func deleteAccount() async throws {
    // 1. 调用后端删除用户账号及所有关联数据
    let _: EmptyResponse = try await APIClient.shared.request(.delete("/user/account"))
    // 2. 清空 Keychain
    KeychainService.clear()
    // 3. 更新 AuthState → 未登录
}
```

---

## API 端点一览

| 方法 | 路径 | 用途 |
|------|------|------|
| POST | `/auth/send-sms` | 发送手机验证码 |
| POST | `/auth/login-sms` | 验证码登录/注册 |
| POST | `/auth/login-wechat` | 微信 code 换取 JWT |
| POST | `/auth/login-apple` | Apple identity token 验证 |
| POST | `/auth/refresh` | 刷新 Access Token |
| DELETE | `/auth/logout` | 服务端退出 |
| GET | `/user/profile` | 获取用户信息 |
| PUT | `/user/profile` | 更新用户信息 |
| DELETE | `/user/account` | 注销账号（删除所有数据） |
| GET | `/training-sessions` | 列表（支持 `?after=` 增量） |
| POST | `/training-sessions` | 创建单条 |
| POST | `/training-sessions/batch` | 批量上传（匿名迁移） |
| PUT | `/training-sessions/:id` | 更新 |
| DELETE | `/training-sessions/:id` | 删除 |
| GET | `/angle-tests` | 角度测试历史 |
| POST | `/angle-tests` | 创建 |

---

## Info.plist 配置

```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
<key>WECHAT_APP_ID</key>
<string>$(WECHAT_APP_ID)</string>
<key>WECHAT_UNIVERSAL_LINK</key>
<string>$(WECHAT_UNIVERSAL_LINK)</string>
```

`Config/Debug.xcconfig`：
```
API_BASE_URL = https://dev.api.qiuji.app
```
