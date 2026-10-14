# 全 App 通用自适应布局

修订：2026-10-12，v1.0。用于功能页、阅读页、列表、表单和组件的设计、实现与复核。以下为项目工作约定；文末链接为 Apple API 行为与设计依据，不将项目取舍称为平台强制规范。

## 先确定页面契约

沿实际入口确认导航容器、内容宿主、底栏及浮层，再确定哪些区域应扩宽、限宽、换行或滚动。正常入口与自动化入口须呈现相同导航语义，不能把直接挂载子 View 当完整页面。

在当前任务卡简记：窗口和内容区域、各区域宽度用途、受限时的排列、必须可达的操作、需保留的状态及验证范围。已有页面卡直接补充，不另建一套进度台账。局部修改只补受影响部分；本技能不要求每次重做全 App 矩阵。

## 窗口、容量与宽度

- 读取所属窗口或布局容器的实际 bounds 和 safe area，区分逻辑 pt、显示像素、窗口、页面、渲染 viewport。不可用机型名或 `UIScreen.main.bounds` 推定当前窗口容量；安全区只扣一次。
- size class 可用于结构选择，但不能替代实际宽高和内容测量。iPad 分屏、缩窗、旋转与恢复可能改变容量而不改变预期的粗分类。
- 按区域选择宽度：长文保持合理阅读行宽；网格按内容容量增减列；功能展示/媒体可利用剩余宽度；表单与操作区按任务对齐。限宽需要用途和作用范围，不把历史 640/720pt 或本次详情全宽推广为全局默认。
- 普通布局优先弹性 Stack/Grid。容量不足时按内容优先级换行、重排或滚动；不要整页等比缩小、缩正文或删掉必要操作来凑一屏。固定尺寸适用于有明确语义的图标/触点等，不一概禁止固定 frame。
- `ViewThatFits` 按候选的理想尺寸选择，候选自身的无限扩展、截断策略或 ScrollView 会影响结果；必须核对实际选中了什么。断点来自内容容量，验证临界两侧及缩小后恢复。

## 测量、放置与状态

- 自定义 `Layout` 的测量与放置消费同一套约束和排列；处理未指定、零和非有限提议，不把探测用的无限宽直接返回为实际尺寸。超宽单项应有明确的换行/滚动等策略。
- 避免子测量修改父 frame、再触发子测量的循环。几何观察只写入真正变化且必需的派生值；`containerRelativeFrame` 的参照是受支持的祖先容器，未必是最近的普通 Stack。
- 切换布局保留输入、选择和业务状态；滚动位置在可行范围内保留，失效时明确回退。避免因旋转/缩窗重新创建业务模型、SceneKit 场景或重置播放；`AnyLayout` 可用于保留同一组子视图身份的布局切换，但不能代替状态持有设计。
- 采用 API 前查工程部署下限和所用重载的 availability，不能因当前模拟器较新就无条件使用新 API。

## 字体、长内容与方向

- 系统字体名称、完整 accessibility label、按 `dynamicTypeSize` 切分支，都不证明文字真实变大。普通文本使用支持 Dynamic Type 的语义样式或相对字号方案；`ScaledMetric` 可辅助缩放关联尺寸，不机械放大所有间距。
- 用实际大字号核字形、换行、基线、标签、按钮和滚动。不要为保持原布局给主要内容强行设字号上限；存在合理的固定尺寸例外时明确用途与替代访问方式。
- 选择能触发容量变化的真实样本：长标题、多标签、大数值、日期或计时。单页样本通过不能代表共享字体迁移完成。
- 面向支持的语言检查文本方向与长度，优先 leading/trailing。RTL 界面语义与物理图解、坐标、公式的方向分开处理，不能把球桌和方向箭头自动全部镜像。

## 底栏、键盘与覆盖层

- 普通滚动页面的固定操作区优先用 `safeAreaInset` 等让滚动区获得实际占位。使用 overlay 时明确动态高度与遮挡补偿，固定 `padding(.bottom, 100)` 不能证明各种字号和键盘状态下足够。
- 检查最后一项、最后输入框、提交动作均可达，键盘出现/收起后布局能恢复；只让需要的背景延伸到安全区，不把正文和交互整体忽略安全区。
- 全屏球桌 HUD 的覆盖规则由专项页面契约决定，不机械换成占据空间的底栏而缩小舞台。浮层还需核可见边界、实际命中、关闭与相邻操作，AX frame/hittable 不能单独证明无重叠。

## 媒体与球桌

保留图像/视频的预定比例与内容裁切语义，区分容器宽高和图内有效内容。球桌布局不能修改物理几何来填满留白；viewport 改变后核投影、叠加标注与触点映射是否同源。全桌视图核必要桌框/袋口可见，局部 3D 视角按其任务验收，不强制所有机位全桌。

涉及球桌模板时再加载仓库 `table-page-adaptation` 技能；涉及坐标计算时加载 `geometry-spatial-reasoning`。普通阅读/表单不因此继承每日清台的侧栏、球径、仪表尺寸或横屏政策。

## 验证与交付

按本次影响选代表条件，在当前任务记录已验/未验与理由：

| 变化 | 重点证据 |
|---|---|
| 宽度或排列 | 窄/宽及宽高瓶颈，适用横竖屏、缩窗与恢复；内容、对齐、必要操作没有丢失 |
| 字体或标签 | 正常与大字号、长内容、多标签；真实字形增长和完整操作，不只查源码/AX |
| 固定操作区或表单 | 页尾、键盘展开/收起、滚动与提交可达 |
| 颜色或共享组件 | 浅/深模式及受影响调用方；共享改动列出回归范围 |
| 球桌或交互层 | 投影、触点、播放/选择状态及覆盖层；静态图不能替代交互验证 |

构建/自动检查、原生视觉与交互、用户复验分别记录。交付时告诉用户修改了什么、需要验证哪些页面/设备/状态；不能把“继续”或测试全绿当视觉认可。实时设备控制遵循 `app-live-review` 当前控制权。

遇到卡死、红条或系统黑边，先区分窗口/系统环境与 App 布局；保留设备身份、版本、入口及现场。相同恢复步骤失败或复发后停止循环，记录未解决边界，再按现有授权选择进一步诊断；不靠页面 padding 掩盖，也不把异常设备算通过。

## 更新方式与官方依据

从实际失败提炼可复用的决策规则；机型尺寸、单页特殊布局留在页面卡。更新时标明日期、适用范围和取代的旧规则，并用不同类型页面检查是否误推广。写完技能不等于存量 App 已修复。

- [Apple HIG Layout](https://developer.apple.com/design/human-interface-guidelines/layout)、[safeAreaInsets](https://developer.apple.com/documentation/uikit/uiview/safeareainsets)、[readableContentGuide](https://developer.apple.com/documentation/uikit/uiview/readablecontentguide)：空间与阅读区域。
- [ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits)、[WWDC22 custom layouts](https://developer.apple.com/videos/play/wwdc2022/10056/)、[WWDC25 iPad design](https://developer.apple.com/videos/play/wwdc2025/208/)：测量、布局身份与窗口变化。
- [Larger Text criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria)、[ScaledMetric](https://developer.apple.com/documentation/swiftui/scaledmetric)、[LayoutDirection](https://developer.apple.com/documentation/swiftui/layoutdirection)：文字与方向。
- [safeAreaInset](https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)-4s51l)、[keyboard safe area](https://developer.apple.com/documentation/swiftui/safearearegions/keyboard)、[containerRelativeFrame](https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:))：布局参照与占位。
