# 台呢优化推广到 App

2026-11-13。用户明确要求“把他们应用到 app 里，相关的场景都用”“确保不要有遗漏”。本轮将已研究的 guard 组合与不可变 shader 文本缓存推广到共享生产入口，不恢复原持续研究目标。

## 实现与覆盖

- `configureReferenceTableRendering`、每日配置及 `liveReference` recipe 默认使用 guard；普通启动无需实验参数。所有原本使用该材质的正式 2D/3D 投影一同继承。
- 核心生成包装、实际安装状态、桌资源缓存键和反射缓存键均进入非 DEBUG 代码；Release 默认固定 guard，不读取诊断启动参数。
- 临时俯视沿用已经安装的共享材质；反射烘焙复制实际材质并清空球遮挡数据，保留场景的真实版本和回退状态。
- 原始 shader 生成器、guard 数学、采样、BRDF、声明顺序和文本缓存算法未变。旧配方、非 reference 采样、非 16 槽容量或源码漂移继续使用其原程序；16 槽是存储容量，不是可见球必须满 16 个。
- DEBUG 增加 `-rendering.referenceCloth` 显式原算法对照；研究测试的原 R 基线也改为显式选择，避免默认变化污染历史研究。

[覆盖清单](ROLLOUT-COVERAGE.md)列出 27 组直接/间接消费者及保留 legacy 配方的理由，包括教学与练习、每日/普通/编辑球桌、嵌入预览、瞄准特写底图、临时俯视和匹配 App 外观的导出。独立代码审核未发现必须修复的问题；源代码覆盖不冒充所有页面都经过 UI 验收。

本轮相对于实施前快照，生产改动是 **5 文件 +31/−42 行**，主要工作是贯通原先被 DEBUG 和每日开关隔开的接线。此前研究实现仍在，未将整个脏工作区计入本轮。快照、差异和 SHA 见 `output/cloth-rollout-20261113/`。

## 验证记录

- `verify-gate` 通过（退出 0）。
- 完整 Release 构建尝试未通过：现有本机配置使用开发 API 地址，被既有 `Prepare API transport configuration` 拦截；未伪造正式地址，未修改配置或校验脚本。原失败日志：`output/local-test-runs/83882a84ff4741ce8a5f552441612b7a/evidence/`。
- 清空 Swift DEBUG 条件的单测构建：App 源码未报错，但已有非本轮单测直接引用 DEBUG 专属接口（如 `didRenderFrame`、`workCounts`、`diagnostic`）导致整个测试 target 编译失败，未执行测试。保留原日志：`output/local-test-runs/3a892272f3d046569df792afd08df2f1/evidence/`。不扩大本轮改动去重构整个测试库。
- 非 DEBUG App 独立编译通过：使用既有 Debug 环境配置、清空 Swift 编译条件，编译命令核实未包含 Swift `-D DEBUG`，仍为 `-O`。`QiuJiUITour` App build 退出 0 / BUILD SUCCEEDED。日志 `output/cloth-rollout-20261113/nondebug-app-build.log`。这是正式代码分支的编译证明，不等同完整 Release 构建通过。
- 正常构建 **20/20 通过，0 失败、0 跳过**：19 项接入/黄金/缓存/克隆/扩容/回退合同（31.497s），1 项不带台呢实验开关的每日和普通自由击球页面检查（52.066s）。设备为受管 iPad Pro 13-inch M4、iOS Simulator 26.3.1。完整结果 `output/cloth-rollout-20261113/default-entry-tests.xcresult`、`test-summary.json`。
- 四个页面状态（每日/普通 × 2D/3D）均记录 `guard-combo`、`effective=true`、R/reference、capacity16、无回退；同页切换保持 rendererID，截图时均已休眠。见 `installed-state-summary.json` 与 `attachments/` 的4张原图、4份状态。主控已核看：台呢、库边、球与球杆正常显示，无黑面/缺失/明显材质断裂；iPad此次实际为竖向窗口，不冒称手机横屏或全尺寸验收。普通自由击球使用scratch空桌，只有母球；每日使用selection球形。
- 作用范围由27组源码调用核查＋3类共享默认安装入口黄金验证覆盖，UI仅代表上述两页。未为此次接线重复R23动态GPU或R32整页测量。
- `verify-doc-size` 与本轮跟踪文件 `git diff --check` 通过；新文件无新增尾空白。guard源码里既有的空白属于冻结shader字符串，保留原黄金。

## 证据边界

本轮是正式接入与正确性验证，未重复 GPU 排名或温升研究。既有 R23/R25/R32 的效果与限制继续有效，不能把代码覆盖推广解释为已证明所有页面 FPS 提升。完整 Release 打包、最低 iOS 17 运行及全页面人工验收未因源码检查而自动通过。未更新用户手机、提交或发布。

## 收尾

本轮两个受管临时构建目录均已由生命周期工具回收，原失败日志和最终20项通过的xcresult/原图保留；登记的可用空间增量分别281,382,912与2,475,745,280字节（不作为长期磁盘净变化保证）。所借iPad已恢复开始时的Shutdown/protected状态，未删设备、未影响其他评审机。最终生产与测试源码SHA记录于 `output/cloth-rollout-20261113/final-source-manifest.json`。代码接入与本轮限定验证完成；完整Release环境及未跑的设备/页面边界按上文保留。

## 手机安装续接（2026-11-13，待无线连接）

用户要求安装当前推广版本。当前源码与已验证manifest一致，真机Debug -O构建及codesign严格校验通过；bundle=com.xinkuan.qiuji，执行文件SHA=407ee9c96315de68dc3fc7fa7a207f23b59e583db9cb23602b8c40c8eabd0770。构建run `475e9ef8c0874e57843bfc3c99cefd32` 已hold，产品位于其work/DerivedData/Build/Products/Debug-iphoneos/球迹.app；安装完成后需complete回收。

iPhone16Pro（UDID尾号18A2201C）已解锁、同Wi-Fi、IP 192.168.2.25；ICMP及62078端口可达，但CoreDevice持续unavailable/4016。重启Mac设备发现服务、用户重连Wi-Fi、直接Lockdown连接均未恢复。Device Hub重启后可操作，现停在Pair Nearby Device等待窗口，提示手机进入隐私与安全性→开发者模式；已请求用户打开页面，尚待回复。**未执行成功安装，手机仍是旧版本**。后续连接恢复直接复用现成构建安装并无参数启动，不重做渲染测试。证据见output/cloth-rollout-20261113/phone-*.json及phone-build-console.log。

手机安装后续：用户已进入开发者模式页；重新打开Pair Nearby Device并等待后仍为Waiting to pair，CoreDevice仍unavailable，Mac蓝牙为On。已取消本轮未成功的配对等待，没有删除配对或修改网络设置。安装包继续hold，下一步临时USB连接后复用现成包安装；目前仍未更新手机。

### 手机安装完成（2026-11-13）

用户连接数据线后设备恢复connected/paired/wired；复用上述现成包覆盖安装成功，无卸载或数据重置。devicectl安装回执及无参数启动成功，PID45309随后在手机进程表读回。新默认guard已随包交付，图标重启仍默认启用，不依赖旧r7的临时启动参数。本次是安装与启动确认，不新增性能或温升结论；用户手感待反馈。证据：`output/cloth-rollout-20261113/phone-install.json`、`phone-launch.json`、`phone-process-after.json`、`phone-product.json`。此前无线失败保留为历史记录；当前手机已更新。
