# UI 审查报告 — 引导与列表式 Pro 第一版

日期：2026-09-07；决策 DR-119。用户授权由预览转为代码实现。本报告限定本次介绍、付费页与介绍入口，不代表整 App / Phase 发布验收。

## 实现范围

- `OnboardingView`：四张已选真实截图裁切，瞄准点、动作详情、自由走位、分组记录；自由走位标注 Pro，记录标注示例。我的 → 认识球迹可重复打开；跳过和开始使用仅 dismiss，启动仍直达首页。
- `SubscriptionView`：跟随 App 浅深色，五项权益列表、StoreKit 实际价格、月/年/终身选择、固定底部绿色 CTA；内容与方案滚动，辅助字号套餐纵排。取消登录保留套餐，恢复与购买调用既有服务。
- 截图不伪造 UI 或训练数据；源截图包含历史版本与 fixture，当前展示明确是功能示例。来源路径、裁切坐标和 SHA-256 见 `onboarding-pro-v1-assets.json`。白底来源截图在深色介绍中仍保留截图原貌。
- 不改既有 Pro 门控；自定义模板、分享、登录后可选云同步不列为付费独占。不改价格，不承诺试用。

## 改前与改后证据

目录 `output/onboarding-pro-v1/`。改前 `before.xcresult` / `before-screens`；首轮改后 `first-after.xcresult`；最终 `standard-final-screens` 与 `compact-final-screens` 提供两款设备四页浅深色与 Pro 首屏/方案图，`preview.html` 可浏览。

## 视觉发现与处理

### U-01 小屏竖图遮住 Pro 示例说明（P2，已修复并通过 SE 浅深色截图复验）

- 位置：认识球迹第三页。SE 首轮图 `compact-screens/A867A928-C1AF-4455-ADAA-45D8A1A214C9.png`：固定 400pt 的竖桌图占满内容区域，Pro 说明落到首屏下方。
- 调整：通过可用页面高度限制竖图高度，保留说明空间；不按机型写特例。新增 Pro 说明可点击区域断言，防止只检查图片存在而漏掉标注不可见。
- 路由与处理：SwiftUI Developer 已修改；下方验收记录最终结果。

### 自动化定位修正

根容器 accessibilityIdentifier 会覆盖页脚和顶部控件标识，已移除父级标识，保留具体控件标识。首轮小屏测试把“部分可点”误作完整可见，卡片中点实际位于底栏下；滚动助手已检查卡片完整落在 CTA 之上，并在付款前断言月套餐选中且按钮周期为每月。本地月交易与恢复随后通过；不是放宽购买结果断言。

## 验证记录

- 标准屏：iPhone 17 Pro / iOS 26.2 / content_size large，隔离 UDID `B0235C6B-A455-4888-9E05-21DD1005FA0B`。
- 小屏：iPhone SE 3 / iOS 26.2 / content_size large，隔离 UDID `E55EC224-6DC5-432C-814E-E30B50F8D01C`。
- SE：`compact-r2.xcresult` 3 tests / 0 failures，介绍返回不改账号、月度购买并恢复、浅深色介绍/选套餐/取消登录均通过。
- 最后竖图修复后：`compact-final.xcresult` 1 test / 0 failures（55.280s），浅深色各四页介绍与 Pro 首屏/方案共 12 图均已目视；Pro 标注首屏可见断言通过。
- 标准屏：`standard-final.xcresult` 1 test / 0 failures（54.280s）。同一最终页面代码重新检查四页、Pro 标注、页码、三套餐、登录取消保留，浅深色共 12 图已目视。账号返回沿用 `standard-r3` 的对应通过用例；购买恢复由 `purchase-r4` 独立 1/0 证据支持。
- 24 张最终截图全部已目视，PNG 尺寸与 24 个唯一 SHA 校验通过；见 `screenshot-check.json`。截图范围无未解决的遮挡、截断或错误页面；U-01 关闭。外观确认仅指截图实测范围。
- 最终独立 Debug 构建：`make -f scripts/Makefile build SIM_DEVICE=QiuJi-Onboarding-Pro DERIVED_DATA=build/onboarding-pro-derived`，退出码 0、BUILD SUCCEEDED；`final-build.log`。`git diff --check` 通过。
- 基线及首轮改后截图测试各 1 项通过。中间失败日志保留：`standard` 编译失败（测试使用不支持的 StoreKit 属性，已纠正）；`standard-r2` 控件标识失败；`standard-r3` 购买后旧文案断言失败，实际已回到会员资料；`purchase-r4` 1/0 验证购买和恢复通过；`compact` 小屏自动化点击定位失败。

## 边界

未执行真机、App Store 沙盒/生产真实付款、iPad、全 Dynamic Type 矩阵或手动 VoiceOver。未量测完整 WCAG 对比度；此轮外观沿用现有 Token，Token 字号自身仍是项目现有固定字号。未检查整 App 回归与发布门禁；未提交/推送并行工作。条款链接继续使用现有配置；此轮未验证网站发布状态。
