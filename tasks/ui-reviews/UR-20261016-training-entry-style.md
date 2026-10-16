# r5 留白微调（2026-10-16）

用户要求按钮短一点、图文更紧凑。水平内边距16→12pt，图文间距8→4pt，目标宽86→74pt；字体15pt、图标16pt、高44pt及默认选中玻璃保持。原工具compact默认内边距仍为12pt；regular目前仅首页消费。

修改前参考r4三态原图。修改后iPhone 16 Pro浅色、SE3深色各3态显示/点击通过，共6张原图已审，均74×44pt、右距12pt，字/图标完整、导航无交叠。证据目录r5-light / r5-dark-se。构建、diff与文档体积门禁通过，借用测试设备已按本轮收尾归还；未装真机/提交发布。

[训练实屏](../../output/training-entry-standard-20261016/r5-light/hud-home-single.png) · [自由实屏](../../output/training-entry-standard-20261016/r5-light/hud-home-empty.png)。

---

# 首页训练入口默认选中 · DR-094 r4 / FL-167

用户最新决定：参照训练Tab的选中效果，默认就是选中；继续沿用确认稿的比例、靶心和横向路径。r3默认工具样式未保留稿件15pt字号/16pt内边距，图标也换成斜路径，因此返工。

## r4 实现

- 原工具胶囊新增 `isSelected`（默认false）、`size`（默认compact），首页显式选中并使用regular。普通工具页现有调用保持原尺寸/中性外观；内容命中区明确为完整胶囊。
- 44pt主体，15pt semibold文字、16pt图标、8pt间距、16pt水平内边距，对应确认稿的约86×44pt比例。
- 采用现有 `btPrimaryMuted` tint 的原生玻璃，`btPrimary` 图文；默认有选中外观，按压只增加反馈。透明材质会随背后卡片内容变化。
- `BTTrainingEntryIcon` 使用统一24单位路径与圆头笔画；靶心三圆、自由横向折返路径。不是位图或SF近似。
- iOS26使用原生玻璃；iOS17–25编译包含ultraThinMaterial降级，本轮未做旧Runtime实屏验证。

## r4 验证

构建、定向diff检查和文档体积门禁通过。测试设备按本轮收尾关机归还；未装真机、未提交发布，旧Runtime/iPad/动态大字完整矩阵未验。

[浅色训练](../../output/training-entry-standard-20261016/r4-light-final/hud-home-single.png) · [浅色自由](../../output/training-entry-standard-20261016/r4-light-final/hud-home-empty.png) · [小屏深色](../../output/training-entry-standard-20261016/r4-dark-se-final/hud-home-empty.png)。

已完成原生验证：iPhone 16 Pro浅色/深色、iPhone SE3深色，各1个UI方法覆盖训练/继续/自由三态，共9态显示和点击通过；9张整页原图已目视。最终目录 `output/training-entry-standard-20261016/r4-light-final`、`r4-dark-phone`、`r4-dark-se-final`，实测三态均86×44pt、右距12pt、导航不相交。确认稿比例与横向路径已恢复，选中材质按最新参考调整；最终审美接受仍由用户复阅。首轮r4-light中玻璃透明背景的AX高仅18pt，补contentShape(Capsule())定义完整44pt命中面，保留原高度断言并复测；该失败日志保留。

---

# r3 历史技术验证（视觉结论已被用户反馈重开）

用户确认：采用普通工具页胶囊按钮，保留靶心/路径图标，直接接入代码。

## 实现

- `TrainingHomeView.startTrainingCircle` 复用默认 `BTAdaptiveToolActionStyle()`；训练/继续使用 `BTIcon.target`，自由使用已有页面采用的路径 SF Symbol。
- 中性底色、描边、13pt semibold、12pt水平内边距、44pt最小高度与按压反馈全部来自共享样式，无新增颜色。
- 固定位置、无障碍标识/文案、课程选择/继续/自由入口动作保持。最小化训练和休息不修改。

## 验证证据

目录：`output/training-entry-standard-20261016/`。通过共享生命周期管理器借用已有设备，测试后关闭并释放租约。

- 修改前：`before-valid`，iPhone 16 Pro 浅色，三个状态尺寸/点击通过，原生截图留存。
- 修改后浅色：`after-light-final`，iPhone 16 Pro，三个状态尺寸/点击通过，三张整页原图已目视。靶心/路径完整，文字单行，导航无遮挡。
- 修改后小屏深色：`after-dark-se`，iPhone SE 3，三个状态尺寸/点击通过，三张整页原图已目视。浅深色均沿用动态 token，图标清晰，文字单行，导航无遮挡。
- 标准胶囊主体高44pt，1pt居中描边计入AX后高45pt；浅色实测宽约74pt，主体右距12pt（含描边AX右距11.5pt）。

复用 `V51ResponsiveLayoutUITests.testHomeTrainingPillsShareCompactHeightAndInsets`，每轮核训练/继续/自由三态，训练和继续点击进入计时，自由点击打开动作选择。未新增实现镜像测试。

## 测试修订与边界

- 首轮 `before` 因旧测试将 suggestion 当作已安排课程而失败；当前该数据仅有推荐计划，正确显示自由。测试改用 single / oneRemaining / empty，与实际业务状态对应；App业务逻辑未更改。
- 首轮 `after-light` 因旧44pt AX断言忽略标准组件描边而失败；修正为44–45pt，保留最小点击高度及上限，未改共享样式迎合旧断言。
- UI用例增加 followSystemAppearance 启动参数，确保深色轮实际随模拟器外观。
- 未安装真机、提交或发布；本轮未跑全仓测试及iPad/动态大字完整矩阵。

最终：两台设备各1个UI方法（每个覆盖3态）通过，构建通过；定向diff空白检查及文档体积门禁通过。两台借用设备已关闭归还。

代表截图：[浅色训练](../../output/training-entry-standard-20261016/after-light-final/hud-home-single.png) · [浅色自由](../../output/training-entry-standard-20261016/after-light-final/hud-home-empty.png) · [深色训练](../../output/training-entry-standard-20261016/after-dark-se/hud-home-single.png) · [深色自由](../../output/training-entry-standard-20261016/after-dark-se/hud-home-empty.png)。
