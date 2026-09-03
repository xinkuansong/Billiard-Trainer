---
name: simulator-matrix-qa
description: >-
  在本项目用 iOS Simulator 系统执行多设备、多 Runtime、Light/Dark、状态与可访问性回归，
  并把发现的缺陷完成根因定位、修复和跨尺寸复验。用于用户要求测试不同 iPhone/iPad
  型号、屏幕尺寸、系统版本，或要求模拟器测试后直接修复；不用于真机性能或发布验收。
---

# iPhone / iPad 模拟器矩阵 QA 与修复

## 入口

1. 若存在声明为本轮真源的方案，先用 `plan-batch-execution` 锁定批次、依赖和完成标准。
2. 读取 `.cursor/rules/55-test-engineer.mdc`；需要截图审查时再读 UI Reviewer 规则，需要改 SwiftUI 时再读 SwiftUI 规则与设计系统技能。
3. 执行前保存工作区基线。工作区本来 dirty 时，以“原有变更 + 本轮预期变更”做集合差，禁止要求或制造全局 clean。

## 矩阵原则

- 按视口、安全区、size class、Runtime 和系统组件行为选等价类，不按营销型号盲目重复。
- 每次从 `xcrun simctl list -j` 动态解析设备和 Runtime；测试命令使用 `-destination id=<UDID>`，不使用 `name=...,OS=latest` 作为矩阵证据。
- XCUITest 默认串行。若确需并行，每个进程必须使用不同 UDID 和 DerivedData；同一设备上的并行安装视为禁止。并发上限默认 3，全新模拟器/全新 DerivedData 先串行跑一条聚焦用例预热，再进入并发波次。
- 三路长巡游除独立 UDID/DerivedData 外还要使用独立的临时 `.xcodeproj` 容器；多个 `xcodebuild` 同时协调同一工程包会触发 `NSFileCoordinator`/Xcode 工程锁假失败。临时工程由同一 `project.yml` 生成，收尾移出工作区，不作为新的工程真源。
- 每个矩阵单元的日志、xcresult、截图和摘要按 `runtime/device/appearance/state/suite` 隔离，禁止不同运行互相覆盖。
- 并发时截图路径必须用 `V50_SHOT_DIR` / `TEST_RUNNER_V50_SHOT_DIR` 直接注入每个 XCTest Runner；禁止多进程共享 `/tmp/.../shot_dir` 单文件，否则会串目录。

## 可信执行

1. 测试入口必须传播 `xcodebuild` 真实退出码；格式化器或报告器不能用 `|| true` 掩盖失败。
2. 全量运行前盘点默认 scheme 中会写盘的测试，分类 build/tmp 输出、Git 跟踪资源 runner、绝对旧路径和删除/覆盖操作。资源烘焙 runner 必须保持关闭，除非当前批明确授权生成资源。
3. 截图巡游从空的当前叶子目录开始，并用 manifest 检查缺图；不能让上轮残留补齐本轮静默跳页。
   - 跨设备视觉比较必须显式固定 App 数据基线。只读设计巡游优先使用专用内存 SwiftData 容器；需要验证持久化时则使用可重复的显式 seed，并单列状态测试。所有软重启必须保留同一数据 fixture。禁止继承各模拟器旧训练、统计、收藏后仍把同名截图放进同一“standard”分组。
   - 入口不在首屏时使用有界滚动查找；耗尽重试必须 `XCTFail`，禁止 `if exists { snap }` 后静默略过。
   - 多次软重启后的 AX 查询允许“激活 App → 重切 Tab”的少量有界重试；耗尽后仍失败，不能无限重试或补拍拼接。
   - 图像哈希重复默认失败；只有经路由/状态语义确认的等价画面可进入成对 allowlist。首次启动完成前后等持久化用例即使允许同图，也必须另有状态持久化断言，不能用 allowlist 代替功能验证。
4. 失败后先保留命令、退出码、xcresult、截图和相关系统日志。只有证据表明是环境瞬断时才有限重试；不得用加 sleep、删断言、`XCTSkip` 或忽略退出码换绿。
5. 并发冷启动下若 AX 查询耗时数十秒、用例退回 SpringBoard 或出现灰色 `UITests-Runner` 残留图标，先按测试基础设施故障取证：保留原失败、单 UDID 聚焦复现、重启该模拟器。同一实例单跑仍立即退回主屏时，保留旧实例并换一个同型号/同 Runtime 干净实例；不得因 Runner 故障修改产品代码。干净实例的聚焦用例 + 完整契约均通过，才可将原失败判为基础设施假阴性。
6. 高分辨率 iPad PNG 的原图门禁应保留 manifest、字节数、SHA-256、IHDR 尺寸与系统解码；近纯色采样先用 ImageIO 批量生成小缩略图，再在缩略图上逐像素检查。禁止用纯 Python 对每张原图逐字节解 PNG 滤镜，也禁止为提速删除坏图/纯色检测。
   - 66 页全部通过后，可用工作区依赖 Python 运行 `scripts/create_matrix_contact_sheets.py`，为每个通过单元生成带文件名的 `contact-sheet.jpg`；联系表还要横向比对不同设备的同名页面状态是否一致，但它只用于逐页目视，不能替代原图门禁。
7. 产品界面若以中文为唯一产品语言，检查 XcodeGen `developmentLanguage` 与打包后的 `CFBundleDevelopmentRegion`；系统返回按钮等由 bundle 本地化决定，不能用每页自定义按钮掩盖工程语言错误。
8. 系统权限先用 `simctl privacy <UDID> reset photos-add <bundle-id>` 回到未决定态。iOS 26 的卡片可能由 SpringBoard 承载，优先查询真实 SpringBoard Alert，按钮用“允许但不含不允许 / 好 / OK”和“不允许 / Don't Allow”语义谓词；普通 interruption monitor 只作兜底。App 必须回显最终授权状态。
9. 所有 `simctl ui` 可调状态都要立即读回并写证据。当前工具不能可靠设置/读回 Bold Text、Reduce Motion、Reduce Transparency，也不能稳定驱动 Split View/Stage Manager；这些应列边界，不得用 App 启动参数冒充系统状态。
10. 键盘可达性不要只看 SwiftUI `TextField` 的 AX frame：不同 Runtime 可能把字段暴露为容器或零尺寸节点。应同时证明字段可输入、键盘出现、提交按钮与窗口相交且可点击，并把导航栏/页内标题几何用于遮挡断言。
11. 超长单测宿主出现 `signal trap` 时，先读取 xcresult 判定断言与进程故障。若独立用例能复现，继续修生产/测试缺陷；若是宿主生命周期资源累积，可把同一 selector 清单切成无重叠分片，但必须机械验证并集、顺序和总数完全等于原清单，每片都要零退出。

## 缺陷修复循环

每个确认缺陷都执行：

```text
最小复现与证据
  → 一句话根因假设
  → 共享层或页面层定位
  → 回归断言
  → 最小生产修复
  → 失败设备复验
  → 相邻尺寸或相邻 Runtime 复验
  → 返回当前矩阵
```

- 布局修复基于可用尺寸、size class、safe area 或内容约束；禁止按设备名加 offset 或阈值特例。
- iPad 优先增量使用内容限宽、自适应列数和稳定的球桌比例；没有产品裁定时不擅自更换导航架构。
- 断言前提错误时，记录原断言、触发改动和失败机理后再修断言；禁止裸删。
- iOS 17 SwiftData 不应依赖“未托管父子对象先拼成关系树、只插入根”的隐式级联；生产保存、恢复和测试夹具都先把每个对象插入同一 `ModelContext`，再设置 inverse。版本迁移不得读取 `Bundle` 中会随版本变化的内容来解释旧数据；使用不可变历史快照、`@Attribute(originalName:)` 与持久 store 结构探测，并在正常打开后归一化。
- P0/P1 按项目规则写 FAILURE-LOG 并补回归；P2 进入 UI 审查报告并在本轮修复。

## 完成证据

只有同时具备以下材料才可标记矩阵单元通过：

- 命令和真实零退出码；
- 预期测试数/截图数与 manifest 一致；
- 截图无空白、异常尺寸或跨运行重复冒充，并已完成目视审查；
- 测试前后没有意外 Git 跟踪资产变化；
- 本单元发现的缺陷已在原设备和相邻等价类复验。

模拟器无法证明热、功耗、触感、真实音视频硬件、蜂窝、生产账号/StoreKit、推送和真机 Live Activity 行为；最终报告必须列为边界，不得外推为真机通过。
