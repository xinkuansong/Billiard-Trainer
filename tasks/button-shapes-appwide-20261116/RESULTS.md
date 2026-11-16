# 全 App 自定义按钮形状适配（DR-467 续，2026-11-16）

## 当前结论

用户要求从截图中的四类入口扩大到整个 App。已完成当前源码的全量控件排查，并在 37 个 Swift 文件中为 77 处遗漏的自定义控件声明补齐 `.buttonStyle(.plain)`；另把调试相机对照面板的 `.borderless` 改为 `.plain`。已有自定义 ButtonStyle、原生菜单内容、弹窗、系统列表行和工具栏分别核对，不统一覆盖 App 根环境。

原 label、action、role、disabled、布局和选中状态保留；此前依赖自动样式提供颜色的文字入口显式保留 tint，移除头像保留 destructive 色。`.plain` 仍负责系统按压、焦点及启用状态反馈，不新增绿色填充或替代边框。系统设置本身未关闭，也没有使用私有 API。

**全量源码排查完成不等于全页面实机验收。** 本轮完成 iPhone 18 Pro / iOS 27.2 的代表页面验证；完整页面状态矩阵、其他系统/设备、真机 VoiceOver 和用户妻子的手机尚未验收。

## 排查范围与清单

- 当前主 App 484 个 Swift 文件，加 Live Activity 3 个文件，共 487 个文件通过 SwiftParser 语法扫描。Live Activity 和本地微信包未发现另有按钮实现；归档、临时实验输出、第三方 SDK 和测试代码不属于本次生产页面范围。
- 最终 651 处声明：564 Button、28 NavigationLink、16 Menu、10 BTCompactMenu、25 BTCompactMenuAction、6 Link、2 PhotosPicker。包括 DEBUG/Preview 分支；这是声明数，不能解释为屏幕上的按钮实例数。
- 分类：437 处直接/父容器显式样式；31 处通过共享组件或调用点提供样式；183 处系统控件或非可视语义动作。未分类项为 0。逐项位置和依据见[控件清单](控件清单.tsv)。
- 起始扫描为 647 处 Button/Menu/NavigationLink/Link。期间共享菜单实现已有调整，最终重扫增加 BTCompactMenu 与 PhotosPicker，按**最终源码**重新核对，未用旧数量充当最终覆盖证明。当前 10 个 BTCompactMenu 调用点：9 处直接给样式，个人信息页从父容器继承 `.plain`；popover 中的 BTCompactMenuAction 内部按钮显式 `.plain`，并保留 role / isEnabled。共享菜单为另一并行任务修改，本任务只核对样式接线并纳入冻结快照编译，不将其实现计入本轮 77 处修改。
- 另审三处 UIKit UIButton 声明：`BTSetInputGrid` 自定义数字键盘已有 `.filled()` 配置，明确前景/背景/圆角；`BTNumberedNoteEditor` 为系统键盘工具栏中的系统图标按钮，保留系统行为。`PlanNameInputView` 的 `.custom` UIButton 是无内容的首次点击拦截层，未设置标题/图像/配置背景且不是额外 AX 元素，保留。未声称这三类 UIKit 控件已完成开关截图对照。
- Picker/Toggle/DatePicker 为原生选择器或开关，未发现 `.toggleStyle(.button)`；手势/球库操作不经系统自动 ButtonStyle，不按绿色填充缺陷批量改写。

共享球桌顶栏 `DailyTemplateHeader`、`DailyHUDPanel`、布局编辑器和已有 BTButtonStyle/BTHUDPressStyle 等已核对样式来源。既有 `.bordered` 微信登录与两个 `.borderedProminent` 调试入口是明确选择系统外观，保留。空状态大“＋”后的淡绿圆来自 `BTEmptyState.iconBadge` 原设计，ON/OFF 像素一致，未误删。

## 验证与证据

证据目录：`output/button-shapes-appwide-20261116/`。`before.json`、`frozen.json`、`frozen-classification.json`、`source-before/`、`source-hashes.json` 与 `frozen-source-hashes.json` 保存声明、改前源码和构建后源码身份；[inventory.swift](inventory.swift) 为只读 SwiftSyntax 扫描工具。它识别真实闭包上下文与 modifier 链，跨属性/组件继承仍由人工核对，不能单靠扫描器自动宣布全覆盖。

- **构建**：Xcode 27.1 / SDK 27.1，arm64 Debug Simulator，`build.log` 明确 `BUILD SUCCEEDED`。调用为 `make -f scripts/Makefile test TEST_ACTION=build`，不是执行 XCTest；本轮 XCTest 数为 0。复用已 protect 的 `fix-runs/c4538f466e694a539a47612718df92a2/work/DerivedData`，仅覆盖安装，没有重建/擦除应用数据。
- **设备**：受管 iPhone 18 Pro / iOS 27.2，UDID `BD400225-8BFB-42A1-8171-0C6CFB72AFA8`。App 进程 42233 完成新一轮开关对照。第一轮截图对应 `source-hashes.json`；随后新增角度范围行 contentShape，并行菜单修改也继续发生，因此不宣称第一轮截图对应最新所有源码。最终复验使用冻结副本及 `frozen-source-hashes.json`，与第一轮证据分开记录。
- **真实设置**：在系统“显示与文字大小”读取并点击 `BUTTON_SHAPES`，实测 1→0→1，另为订阅补做 1→0→1；最后保持 1。`system-on.png` 为开启截图，其余增强对比度、降低透明度等未更改。
- **训练计时**：改前 `before-timer-light-on.png` 有双层绿色胶囊；改后“继续/跳过计时”浅深色 ON/OFF 的目标区域全部 0 像素差。跳过→恢复实际通过；添加动作入口可打开选择器，未选择动作，结束空训练后周训练仍 0 天。没有生成训练记录。
- **练习搜索/筛选**：搜索词 `v` 空结果，清除和主题筛选区域浅深色 ON/OFF 全部 0 像素差；清除恢复列表，主题选“准度”后标签与结果更新，再恢复“全部”。`after-{timer,search}-{light,dark}-{on,off}.png` 共 8 张，区域结果在 `on-off-pixel-comparison.json`。
- **订阅**：实际观察加载中“恢复购买”与购买入口均 disabled，加载结束后恢复启用。关闭、恢复、重新加载 3 区域 ON/OFF 为 0 像素差，见 `subscription-pixel-comparison.json`。系统为浅色，但此页面自身固定深色。首次对照前后加载失败文案不同导致区域变化，原件保存为 `subscription-different-error-message-on.png`；在相同文案稳定态重新取样后通过，不把异态差异解释为样式差异。未购买/恢复交易或改权益。
- **球桌**：进球容错角实际进入，共享自定义顶栏、更多菜单选中态、关闭菜单与返回通过；开启设置下无额外自动绿底，原设计选中色保留，见 `table-menu-light-on.png`。未据此替所有球桌页面/3D 模式验收。
- **个人信息**：进入昵称编辑，完成按钮无额外填充；未保存修改，见 `profile-edit-light-on.png`。
- **最终现场**：回到浅色首页，`final-home-light-on.png`；每日清台仍显示进行中、训练天数仍 0。原保护和独占租约继续保留供用户看效果。构建、安装、代码审计、定向 UI 验证完成；未提交、未发布、未完成真机验收。

本轮像素比较针对已定位的控件区域，不包含动态时钟、系统玻璃工具栏、整屏渲染或完整无障碍审计。其他受影响页面（如分享、历史月切换、照片提取、少见错误态、表格菜单）完成源码接线与编译，未逐页逐状态原生操作，不记为 UI 通过。

## 球桌规范局部检查

| 项 | 判定与本轮证据 |
| --- | --- |
| TP08 样式/反馈 | 继承；自绘浮层明确使用 plain 或现有 HUD 样式，既有背景/选中色不变；共享顶栏及菜单实测。 |
| TP09 可访问性/禁用 | 继承；未移除 Button、role、disabled、AX label/value，未换为 onTapGesture；订阅 disabled→enabled 已观察，完整 VoiceOver/其他状态未验。 |
| TP35 验证 | 本次仅按钮样式局部变更；保留源码、构建、设置、截图及范围限制，无几何/物理/相机改动；角度范围行补 contentShape 保持整行命中范围。未重跑全部 TP01–TP36 或设备矩阵。 |
| TP36 维护 | 共用决定同步 TP08 与来源表，逐项清单和未验范围留在本卡；不以未测试为不适用。 |

## 构建与复验补充

- 角度范围行切换为 plain 后，为保持原整行空白区域可点，补显式 `contentShape(Rectangle())`。
- `build-final.log` 构建失败：读到并行任务菜单中间版本（BTCompactMenuAction 的 systemImage 初始化器尚未完整落盘），不是已通过截图的结果。保留日志，不抹去失败；后续冻结完整源码后编译，避免构建时继续混入共享工作区修改。
- 最终冻结副本位于受保护构建 run 的 `work/final-snapshot/`；首轮冻结构建 `build-frozen.log` 完成 Swift 编译，但打包校验因快照遗漏根目录 `project.yml` 失败；补齐此配置后重跑，保留失败日志，最终日志 `build-frozen-r2.log`。最终 `build-frozen-r2.log` 为 `BUILD SUCCEEDED`，打包模型/题库校验通过；覆盖安装后进程 56626。冻结源码与收尾时工作区 487 个 Swift 文件哈希一致。

- **最终补验**：23:15–23:17（北京时间），真实点击角度范围“近直球”行中间空白区域，未选→已选、综合已选→未选；恢复综合后返回，未开始训练/消耗题数。证据 `frozen-angle-row-light-on.png`。
- **最终菜单**：主题菜单展开、选“准度”、关闭后筛选按钮显示“已选 准度”通过；重新选全部并恢复全部分类。最后回到首页，`frozen-final-home-light-on.png`，每日清台仍进行中、周训练 0 天，按钮形状仍开启。新菜单只补验此代表入口，不把第一轮截图混作新菜单全部验收。
- **汇总**：`verification.json` 保存最终进程、构建、范围与哈希漂移检查（0）。先前与最终的失败/通过日志分别保留。

## 后续维护

新增自定义按钮应在控件或明确的共享容器指定 plain/自定义样式；不得依赖 automatic 来包裹已有背景。检查调用点继承，原生控件继续系统样式。复验时至少保留浅深色×按钮形状开关、真实选中/禁用状态与点击结果；新状态和新设备仍需独立证据。

依据：[Apple PlainButtonStyle](https://developer.apple.com/documentation/swiftui/plainbuttonstyle)、[系统显示辅助设置](https://support.apple.com/en-gb/111773)。
