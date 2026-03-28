# 合规检查清单（Compliance Checklist）

> **负责角色**：DevOps/Release + Data Engineer
> **最终确认时机**：P8-T-P8-01 完成后全部勾选，提交审核前复查一遍。

---

## 一、Apple Privacy Manifest（iOS 17 强制，审核必须通过）

> 文件路径：`QiuJi/PrivacyInfo.xcprivacy`
> 参考：[Apple Privacy Manifest 文档](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

### 1.1 跟踪声明

- [ ] `NSPrivacyTracking = false`（本 App 不进行跨 App/网站追踪）
- [ ] `NSPrivacyTrackingDomains`：空数组

### 1.2 数据收集声明（`NSPrivacyCollectedDataTypes`）

| 数据类型 | 是否收集 | 用途 | 是否关联用户 |
|---------|---------|------|------------|
| 用户 ID（后端用户 ID） | ✅ | App 功能（账号同步） | ✅ |
| 手机号（登录用） | ✅ | App 功能（身份验证） | ✅（哈希存储）|
| 训练记录（自生成数据） | ✅ | App 功能（数据同步） | ✅ |
| 设备 ID | ❌ | — | — |
| 精确位置 | ❌ | — | — |
| 健康与健身数据 | ❌ | — | — |

- [ ] `PrivacyInfo.xcprivacy` 中 `NSPrivacyCollectedDataTypes` 仅包含实际收集的类型（手机号、用户生成内容、用户 ID）
- [ ] 每个类型标注正确的用途（`NSPrivacyCollectedDataTypePurposes`）：`NSPrivacyCollectedDataTypePurposeAppFunctionality`

### 1.3 Required Reason API 声明

如果代码中使用了以下 API，必须在 Privacy Manifest 中声明原因：

- [ ] `UserDefaults`：若用于 App 功能（如保存设置），声明 `CA92.1`
- [ ] `FileTimestamp`（文件访问时间）：若用到，声明 `C617.1`
- [ ] `SystemBootTime`（`clock_gettime` CLOCK_MONOTONIC）：若用到，声明 `35F9.1`

> **操作**：在 Xcode 中使用「Privacy Report」功能扫描，确保无未声明 API。

---

## 二、PIPL（个人信息保护法）合规

> 适用于：在中国大陆境内处理中国用户个人信息的 App

### 2.1 告知与同意

- [ ] App 首次启动时展示隐私政策弹窗，用户主动点击「同意」后才进入主界面
- [ ] 隐私政策弹窗包含：数据收集范围、使用目的、保存期限、第三方共享情况
- [ ] 未同意时 App 可正常退出（不强制同意）

### 2.2 最小必要原则

- [ ] 不收集与 App 功能无关的数据（不申请相机/位置/通讯录等无关权限）
- [ ] 手机号仅用于登录身份验证，不用于营销
- [ ] 后端用户数据仅存储训练相关内容

### 2.3 用户权利保障

- [ ] App 内有「账号注销」功能（T-P8-06）：注销后调用 `DELETE /user/account` 删除云端数据
- [ ] 隐私政策中说明用户可申请数据访问和删除
- [ ] 提供联系方式（邮箱）供用户行使数据权利

### 2.4 数据本地化

- [ ] 腾讯云服务器部署在国内节点（上海/北京，数据存储在中国大陆）
- [ ] CloudKit 通过「云上贵州」访问，数据在中国大陆

---

## 三、App Store 审核合规（IAP 相关）

> 参考：App Store Review Guidelines § 3.1.1

### 3.1 IAP 强制要求

- [ ] **数字内容必须使用 Apple IAP**：订阅功能不通过任何第三方支付（微信支付等）
- [ ] **不引导外部支付**：App 内任何文字、按钮、链接不得暗示用户去 App Store 外购买
  - ❌ 禁止：「在官网购买更优惠」「扫码支付」
  - ✅ 允许：「订阅管理」链接到 Apple 订阅管理页
- [ ] **已开放的免费功能不得降级为付费**（见 `docs/08` 约束）
- [ ] 订阅页底部包含：服务条款链接 + 隐私政策链接 + 自动续费说明

### 3.2 订阅说明文案（必须在订阅页显示）

```
订阅将通过您的 Apple ID 账户收费。
订阅在当前订阅期结束前 24 小时内自动续订，费用从 Apple ID 账户扣除。
您可以在 iPhone「设置」→「Apple ID」→「订阅」中管理或取消订阅。
购买后不支持退款（Apple 退款政策除外）。
```

- [ ] 上述文案已添加至订阅页底部

### 3.3 年龄分级

- [ ] App Store Connect 年龄分级问卷：无暴力、无成人内容 → 4+
- [ ] App 内无用户生成内容（UGC）公开分享功能（心得仅本人可见）

---

## 四、微信 SDK 集成合规

> 参考：微信开放平台移动应用接入文档

### 4.1 Info.plist 配置

- [ ] `LSApplicationQueriesSchemes` 包含：`weixin`、`weixinULAPI`
- [ ] `CFBundleURLTypes` 包含微信 URL Scheme：`wx${WECHAT_APP_ID}`
- [ ] Associated Domains（Universal Links）：`applinks:yourdomain.com`（或使用 URL Scheme 临时方案）

### 4.2 微信开放平台要求

- [ ] H-05 完成：移动应用资质审核通过（AppID 已获取）
- [ ] App 名称与微信开放平台登记一致
- [ ] H-13 完成：Universal Links 域名校验文件已部署（或 URL Scheme 临时方案已记录 ADR）

### 4.3 隐私声明

- [ ] 隐私政策中声明「使用微信 SDK 获取微信授权登录，不获取微信好友关系、消息等数据」

---

## 五、Sign in with Apple 合规

> App Store Review Guidelines § 4.8

- [ ] 提供任何第三方登录（微信/手机号）时，**必须同时提供** Sign in with Apple ✅（已满足）
- [ ] Sign in with Apple 按钮样式符合 Apple 设计规范（黑底白字 / 白底黑字，不变形）
- [ ] 不要求用户公开真实姓名（允许使用 Apple 提供的匿名邮件）

---

## 六、最终提交前复查

> 在 T-P8-10 前完成全部勾选

- [ ] Privacy Manifest 已添加且无 Xcode 警告
- [ ] PIPL 弹窗已实现
- [ ] IAP 订阅文案合规
- [ ] 微信 SDK 配置完整
- [ ] 账号注销功能可用
- [ ] 隐私政策 URL 可访问（H-09）
- [ ] App Store Connect 年龄分级问卷已填写（H-12）
