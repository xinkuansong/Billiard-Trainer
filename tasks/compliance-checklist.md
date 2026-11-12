# 合规检查清单（Compliance Checklist）

> **负责角色**：DevOps/Release + Data Engineer
> **最终确认时机**：P8-T-P8-01 完成后全部勾选，提交审核前复查一遍。

---

## 一、Apple Privacy Manifest（iOS 17 强制，审核必须通过）

> 文件路径：`QiuJi/PrivacyInfo.xcprivacy`
> 参考：[Apple Privacy Manifest 文档](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

### 1.1 跟踪声明

- [x] `NSPrivacyTracking = false`（本 App 不进行跨 App/网站追踪）✅ 2026-04-05
- [x] `NSPrivacyTrackingDomains`：空数组 ✅ 2026-04-05

### 1.2 数据收集声明（`NSPrivacyCollectedDataTypes`）

首发 9 项逐项填报见 [ASC 隐私填表稿](launch-20261110/ASC隐私填表稿.md)。覆盖用户 ID、姓名、邮箱、头像、真实台球训练、其他用户内容、生日等资料、工具使用和购买历史。全部用于 App 功能，工具使用另含分析。

- [x] 2026-11-11 本地未签名 Release 包中，9 项均关联账号、跟踪为否。已比对打包的微信 SDK 清单与供应商原件。[构建核验](launch-20261110/隐私清单包内核验.json)
- [ ] 正式签名归档导出聚合报告，核对真实微信授权链路、网关日志与商店预览。

### 1.3 Required Reason API 声明

- [x] 主 App 的 UserDefaults 用于保存自身偏好，声明 CA92.1。
- [x] 主 App 的 systemUptime 用于测量事件间隔与计时，声明 SystemBootTime / 35F9.1。
- [ ] 最终 Archive 再核主 App、扩展和第三方 SDK 采用的 API 与原因。

---

## 二、PIPL（个人信息保护法）合规

> 适用于：在中国大陆境内处理中国用户个人信息的 App

### 2.1 告知与同意

- [ ] 首次启动按必要与可选处理告知，验证拒绝非必要处理后仍能使用本地基础练习
- [ ] 隐私政策弹窗包含：数据收集范围、使用目的、保存期限、第三方共享情况
- [ ] 拒绝、撤回、主动登录／开启云同步分别实测，记录客户端及服务端在各阶段的数据流。[个保法第 15、16 条](https://www.cac.gov.cn/2021-08/20/c_1631050028355286.htm) · [本周验收口径](LAUNCH-READINESS-20261109.md)

### 2.2 最小必要原则

- [ ] 不收集与 App 功能无关的数据（不申请相机/位置/通讯录等无关权限）
- [ ] 首发不提供手机号登录，不因登录收集手机号
- [ ] 后端用户数据仅存储训练相关内容

### 2.3 用户权利保障

- [ ] App 内有「账号注销」功能（T-P8-06）：注销后调用 `DELETE /user/account` 删除云端数据
- [ ] 隐私政策中说明用户可申请数据访问和删除
- [ ] 提供联系方式（邮箱）供用户行使数据权利

### 2.4 数据本地化

- [ ] 腾讯云服务器部署在国内节点（上海/北京，数据存储在中国大陆）
- [ ] Drill / 计划等公开内容由自建 API 提供时，服务器与数据存储地域符合产品合规要求（与上条腾讯云节点一致；已弃用 CloudKit，ADR-002）

---

## 三、App Store 审核合规（IAP 相关）

> 参考：App Store Review Guidelines § 3.1.1

### 3.1 IAP 强制要求

- [ ] 首发只展示永久会员非消耗型商品，通过 Apple IAP 完成一次性购买。
- [ ] 商品、实付价格与权益说明一致；购买、恢复及退款撤销按候选包验证。
- [ ] 已开放的免费能力符合首发权益表。

### 3.2 永久会员购买页

- [ ] 付费前可见一次性购买说明、本地化价格、服务条款及隐私政策链接。
- [ ] 提供恢复购买入口；检查页面和法律文本中已去除旧月／年套餐、自动续费及试用文案。

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
- [ ] 永久会员 IAP 文案与候选包一致
- [ ] 微信 SDK 配置完整
- [ ] 账号注销功能可用
- [ ] 隐私政策 URL 可访问（H-09）
- [ ] App Store Connect 年龄分级问卷已填写（H-12）
