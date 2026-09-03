# UR-20260902 — v50 设备矩阵 UI 审查

> 状态：✅ 已完成（W0–W8 全部闭环）
> 真源：`问题集合_v50.md` v50.10
> 证据根：`build/v50/matrix/`

## 口径

- 66 页巡游由 `ScreenshotTourUITests.testDesignerPageDump` 自动生成，不以人工逐页截图充数。
- XCTest 通过、PNG 数量/命名/解码门禁、联系表目视是三层独立证据。
- 本报告只记录已执行的设备/状态；未跑批次不预支结论。

## 已发现并修复

### V50-UI-001 — iOS 26 紧凑屏登录页标题与导航栏重叠

- 级别：P2（已修复）
- 发现设备：B2，iPhone SE 第 3 代，iOS 26.2，Light，标准字号，数字键盘展开。
- 现象：页内大标题“输入手机号”被整体上移，与固定导航栏“手机号登录”重叠。
- 根因：长表单使用不可滚动的满屏 `VStack`；iOS 26 紧凑高度的键盘避让会平移整个容器，而不是只保证焦点字段可见。
- 修复：`PhoneLoginView` 改为 `GeometryReader + ScrollView + minHeight`，保留无键盘时的满屏布局，由滚动容器承接键盘避让。
- 回归断言：发送按钮与窗口相交；页内标题若可见，不得与导航栏 frame 相交；截图 JSON 保存两者几何。
- 实证：B2 Light/Dark、A1 Light/Dark、A3 Light/Dark 标准字号及 A1 AX5，受影响页面 7/7 通过。B2 Light 修复后导航栏 y=56…110，页内标题 y=142…180.5，无相交。

### V50-UI-002 — 中文 App 的系统返回按钮显示英文 Back

- 级别：P2（已修复）
- 发现设备：A5/A6，iOS 17.0，Light/Dark；全量截图中的 SwiftUI 系统返回按钮均显示 `Back`。
- 根因：工程由 XcodeGen 生成，但 `project.yml` 未声明产品开发语言；生成工程为 `developmentRegion = en` 且只登记 Base/en。产品内容虽为中文，系统生成控件仍选择英文资源。
- 修复：在 `project.yml` 设置 `options.developmentLanguage: zh-Hans`，执行 `make -f scripts/Makefile xcodegen`，生成工程改为 `developmentRegion = "zh-Hans"`。
- 回归：宿主 App Bundle 单测断言 `CFBundleDevelopmentRegion == zh-Hans`；T07 UI 回归断言导航栏存在“返回”且不存在 `Back`。
- 实证：A5/iOS 17 Light UI、B6/iOS 26 Dark UI 与 A6/iOS 17 Bundle 单测均通过；修复后原图明确显示“返回”。

## W2 审查结论

- A1 iOS 17.0 Light/Dark：自动巡游各 66/66，图像门禁通过，五张联系表已目视，未发现其他紧凑屏硬裁切。
- B2 iOS 26.2 Light/Dark：扩展契约 3/3；修复后键盘定向回归通过。
- A1 AX5：根页、键盘表单、球桌场景 3/3；修复后登录页定向再验 1/1。
- W2 遗留：0 个已知可修复紧凑手机缺陷。

## W3 审查结论

- A2 iPhone 15 Pro / iOS 17.0、A3 iPhone 17 Pro / iOS 26.2、A4 iPhone 17 Pro Max / iOS 26.2：Light/Dark 各 66/66，共 396 张；xcodebuild、manifest、PNG 解码/尺寸/重复门禁均通过。
- Light/Dark 六张全量联系表已对比：Dynamic Island/刘海安全区、单/双列卡片、长文、记录、登录/订阅表单、2D/3D 球桌在三种手机宽度上未见硬裁切、安全区覆盖或非等比拉伸。
- B1 iPhone 15 Pro Max / iOS 17.0、B3 iPhone Air / iOS 26.2、B4 iPhone 16e / iOS 26.2：Light/Dark 契约各 3/3，根页滚底、登录键盘、2D 球桌主流程全过。
- A1 收尾：Light 契约 3/3，标准/大屏收敛未牺牲最短手机。
- 产品缺陷：0 个新增。基础设施插曲：B3 三路冷启动并发时 AX 超时，单跑聚焦+完整契约均通过；原 B4 模拟器实例重启后仍退回 SpringBoard，已保留改名，新建同型号/同 Runtime 实例聚焦+完整契约通过，因此未修改产品代码。

## W4 审查结论

- A5 iPad mini 第 6 代 / iOS 17.0、A6 iPad 第 10 代 / iOS 17.0：Light/Dark 各 66/66，共 264 张；XCTest、manifest、PNG 解码/尺寸/重复门禁全部通过。
- 四张全量联系表及关键原图已审查：训练双列网格、长理论图示、2D/3D 球桌比例、个人页、电话登录弹层与 Onboarding 在 mini/10.9 英寸均无硬裁切、异常缩放、错误锚点或不可达 CTA。
- B6 iPad mini A17 Pro / iOS 26.2：Light/Dark 扩展契约各 3/3；中文返回按钮 Dark 定向回归通过，补齐 mini 跨 Runtime 交叉点。
- 产品缺陷：V50-UI-002 已修复。测试基础设施：iPad 角度卡不在首屏时旧巡游会静默跳过，现改为有界滚动并显式失败；双 iPad 长巡游偶发一次 AX 空快照，公共理论入口改为三次有界激活/切换重试；原图审计从纯 Python 全图解滤镜改为 ImageIO 批量 48px 缩略采样，A5 66 图实测 2.57 秒且门禁结果一致。

## W5 审查结论

- A7 iPad Pro 11 英寸 M5、A8 iPad Pro 13 英寸 M5（iOS 26.2）：Light/Dark 各 66/66；四个单元的 XCTest、manifest、PNG 解码/尺寸与重复门禁全部通过。
- B5 iPad Pro 12.9 英寸第 6 代（iOS 17.0）：Light/Dark 扩展契约各 3/3，通过大屏 iPad 的最低 Runtime 交叉点。
- 11/13 英寸联系表与关键原图检查覆盖训练网格、计划 Hero、长理论页、统计、登录表单和球桌工作区；内容保持居中限宽/自适应列与等比球桌，没有无限拉伸、左上角挤团、硬裁切或 CTA 不可达。
- A8 Portrait-only 边界测试通过；当前模拟器工具不能稳定驱动 Split View/Stage Manager，因此半宽多窗口没有记为通过，也没有据此扩展产品方向契约。

## W6 审查结论

- A1/A3/A5/A8 的 AX5 五根页/长内容、首次启动完成与重启持久化、Guest/Free/强制 Pro、个人信息与计划表单键盘均有真实 XCTest 证据；A1/A8 Dark + High Contrast 也完成系统设置回读与根页断言。
- A3/iOS 26.2 从未决定态触发真实相册系统弹框并拒绝，A5/iOS 17.0 触发真实弹框并允许；App 均回显最终权限状态，Info.plist 文案与 Bundle development region 定向单测通过。
- A1/A3 离线失败保留重试项、恢复后清错的仓储测试通过。免费/Pro 仅验证本地门控 fixture，不冒充生产 StoreKit、Apple ID 或微信账号链路。
- `simctl ui` 已对 Light/Dark、AX5、High Contrast 执行设置后回读。当前工具不能可靠设置/回读 Bold Text、Reduce Motion、Reduce Transparency，也不能稳定驱动 Split View/Stage Manager；这些均列为模拟器自动化边界而非通过项。
- W6 未发现新的可复现布局 P2；状态测试暴露的 AX 定位与系统弹框承载差异均在测试层用真实 SpringBoard/语义谓词和有界重试修复，没有用 App 私有启动参数冒充系统状态。

## W7 最终回归结论

- 最终源码指纹 `58881e93ff31c40c63cbbee26ae2e9e64c9d5efe76a940b2660a14e5beb97a8f` 下，A1–A8 × Light/Dark 共 16/16 个完整巡游通过，每个单元 66/66 张，合计 1,056/1,056，缺失 0、图像失败 0。
- B1–B6 × Light/Dark 共 12/12 个扩展合约通过，合计 36/36 张根页滚底、登录键盘和球桌主流程截图。
- iOS 17.0 与 iOS 26.2 的 152 个安全测试类各分 4 片串行运行：每个 Runtime 分别执行 238、368、298、229 项，共 1,133 项；双 Runtime 合计 2,266 项，最终失败 0、跳过 4。
- A3 安全分片首轮发生一次 Metal 测试宿主崩溃，隔离同一分片后 368 项通过；A6 Dark 的旧模拟器实例发生 AX 空树/类型错乱，新建同型号同 Runtime 实例后聚焦回归和完整 66 页通过。B2/B5 首轮受系统进程上限拦截，关闭已完成模拟器后重跑全过。这些原失败均保留在 `build/v50/diagnostics/`，没有删除断言或用无限重试换绿。

## W8 最终视觉与工作区结论

- 16/16 张最终联系表已逐页横向审查，覆盖训练网格、计划、动作详情/精讲、长理论页、统计、登录/个人表单、Onboarding、2D/3D 球桌和暗场工具；未发现新的可复现布局、Dark Mode、缩放、数据状态或 CTA 可达性缺陷。
- FL-034 修复后，同名页面统一使用专用内存 SwiftData 基线；跨设备的启动、训练和历史/统计页面不再混入模拟器旧数据，持久化行为由独立状态测试承担。
- 最终开放产品缺陷 P0/P1/P2 均为 0。本轮共发现并修复产品 P1 3 项、P2 2 项；另修复 P1 测试可信性问题 1 项。
- `make build`、Makefile 定向测试 5/5、教程门禁、文案门禁和总门禁均通过；总门禁记录 screenshots=66、routes=69、write-surfaces=122。
- W0 已存在的 6 张 Git 跟踪 UI PNG 哈希保持不变；没有测试生成的跟踪资源污染。4 个临时矩阵 Xcode 工程已移至 `/tmp/qiuji-v50-projects-IQATIC81/`，未提交、未推送。

## 最终裁定

v50 模拟器矩阵 UI 审查通过。本结论只覆盖指定 iOS Simulator Runtime、设备视口、状态和自动化路径；不外推为真机性能、热/功耗、触感、真实硬件、真实账号、生产支付、推送或 Live Activity 真机生命周期通过。
