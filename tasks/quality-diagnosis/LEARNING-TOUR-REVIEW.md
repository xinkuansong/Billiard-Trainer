# 学 / 理正常入口巡游准备

2026-09-06。**仅完成测试草稿与源码核对，未运行UI、构建或XcodeGen；没有通过结果。** 文件 `LearningTourDiagnosticUITests.swift` 包含21个独立方法，每方法全新启动；某页失败不会使其他页面在同方法内被跳过。主控注册至冻结工程后白名单逐方法运行，保留所有失败。

## 测试条件及副作用

- 只从正常练习Tab→学/理分类→实际卡片进入，沿真实MainTab route。无deepLink、无内存内容seed、无私有模型调用。
- launchClean使用现有帮助方法，另加 `-v50.inMemoryStore`、`-forcePremium`；这是UI数据隔离及门控固定条件，**不证明真实Pro权益、真实账号、磁盘持久化**。部分AppStorage偏好仍是当前专用设备本地状态，不能复用用户真实设备。
- 所有操作局限阅读、滑杆、Picker、图谱轨迹显示及“更多”菜单展开；不点外部链接、反馈、付费、制作入口，不改资产。结束终止App。
- `QD_SHOT_DIR` / `TEST_RUNNER_QD_SHOT_DIR` 必填，使用本轮独立目录；截图与AX为 `learning-方法名-stage-UUID.png/.txt`。每页至少entered、结果、returned、teardown；teardown也会尽力记录失败处，但若App或文件写入失败，必须保留对应error，不宣称有完整证据。
- 每个方法名称固定，UUID使跨执行不覆盖；stage固定，便于汇总。主控应记录注入到宿主的实际输出路径，不能借先前生成图凑数量。

## 逐页动作 / 断言 / 源码核对

源码均相对 `build/quality-diagnosis/snapshot-002/QiuJi/Features/AngleTraining`。

| 方法末缀 | 卡片 | 正式候选动作与结果断言 | 冻结来源 |
|---|---|---|---|
| Learn01AimingPrincipleLowerContent | 瞄准原理 | 滚到厚薄球概念，极薄球 `90° \| d/R 2` 内容可见，返回卡片 | Views/AimingPrincipleView 240–281；AngleSceneCalculator.thinBall overlap0 |
| Learn02AimingMethodsSlider | 瞄准方法 | thetaSlider由初始值调至82%，AX value确实变化 | Views/AimingMethodsView 23；LearnControlStrip.Theta |
| Learn03AimingCorrectionSliderAndAdvice | 瞄准修正 | velocitySlider实际值变化；滚到实战启示及“边界感知：中杆中速小切角时”正文 | Views/AimingCorrectionView 55–75、382–405 |
| Learn04SpinStateChangesReadout | 旋转与加塞 | Picker后旋→选中且正文“后旋后弯”；再滑动→选中且“切线 90°” | Views/SpinAndEnglishView 62–101；SpinAndEnglishGeometry.SpinState |
| Learn05AngleDynamicDisplayMenu | 角度与瞄准 | 等球库8控件，展开更多，台面网格4×8项可操作；关闭返回 | Views/AngleDynamicView 54–58/224–245；Core/Components/BTShotPageChrome.BTSolverMoreMenu |
| Learn06SeparationAtlasToggleTrack | 分离角图谱 | 第0轨已选→未选→已选，AX value和selected trait一致 | Views/SeparationAngleAtlasView 305–331；VM enabledTracks=allEnabled |
| Learn07CushionAtlasToggleTrack | 加塞吃库图谱 | 第0轨已选→未选→已选，AX value和selected trait一致 | Views/CushionEnglishAtlasView 373–399；VM enabledTracks=allEnabled |
| Learn08BallFeelLowerAdvice | 浅谈球感 | 滚到训练建议，第5项“将练习中建立的记忆带到球桌前。”可见 | Views/BallFeelView 132–147 |
| Learn09ContactPointSliderAndCurve | 瞄准点对照表 | thetaSlider变值，滚到末段d/R曲线并截图 | Views/ContactPointTableView 46–52/389–393 |
| Theory01ThirtyDegreeSliderAndScope | 30°法则 | theta变值→容易失效的几处→相关页面可见 | Theory/TheoryT01View 45、152、178 |
| Theory02NinetyDegreeSliderAndScope | 90°法则 | theta变值→不成立的几处→相关页面可见 | Theory/TheoryT02View 34、115、145 |
| Theory03TangentSliderAndScope | 切线法则 | theta变值→两个容易混的说法→相关页面可见 | Theory/TheoryT03View 47、161、189 |
| Theory04SpeedLowerScope | 母球速度分级 | 滚到“什么时候这样用”，核对极慢推杆低于最轻档正文可见 | Theory/TheoryT04View 135–140 |
| Theory05BackwardPlanningLowerScope | 反向规划 | 滚到降级条件，核对两颗及以下规划深度正文 | Theory/TheoryT05View 102–106 |
| Theory06KeyBallLowerScope | 关键球原理 | 滚到成立条件，核对失位后关键球重评正文 | Theory/TheoryT06View 107–113 |
| Theory07ClustersLowerScope | 球团管理 | 滚到什么时候别破，核对无清台路径可保留球团正文 | Theory/TheoryT07View 96–101 |
| Theory08RiskLowerScope | 风险报酬决策矩阵 | 滚到放宽条件，核对对手球数两倍条件正文 | Theory/TheoryT08View 118–122 |
| Theory09MinimumEnglishLowerScope | 最少加塞原则 | 滚到仍须加塞条件，核对输入端挤偏校正正文 | Theory/TheoryT09View 125–128 |
| Theory10SafetyLowerScope | 安全球三维度模型 | 滚到什么时候进这条线，核对对手水平及空旷盘面条件正文 | Theory/TheoryT10View 128–133 |
| Theory11FlowLowerConsequences | 清台5步决策流程 | 滚到跳步代价，核对跳过复盘后的表格结果正文 | Theory/TheoryFlowView 267–280 |
| Theory12QuickReferenceLowerLines | 清台速查手册 | 滚到八句口诀，核对太阳/障碍球阴影正文 | Theory/TheoryQuickRefView 223–234 |

所有方法最终断言返回正常分类按钮及原卡片可操作，不是仅调用返回后直接退出。截图留存供主控检验图、滑杆及下部阅读布局，AX存在不证明图形正确。

## 诚实边界

- Theory04–12、瞄准原理、浅谈球感属本次**静态阅读巡游**；检查实际滚动到正文后部、内容未缺失和返回，不虚构开关交互。这些页源码LearnDocFormulaNest默认不是DisclosureGroup，不应为了测“展开”去点不可展开标题。
- 三个theta理论页和瞄准方法/修正/对照表检查输入值变化，**不声称已独立验证数值与绘图物理一致**。T01把theta调到范围外产生何种法则说明，应结合截图后另补语义断言，当前没有硬编码物理真值。
- 角度与瞄准页只做**真实菜单展开/关闭**，不宣称已验证球拖动、袋口点击、球库增删、指标联动。这页球库button无选中/在桌AX值；不能靠点击成功假装验证球状态。留给主控随后补截图/真实操作诊断。
- 图谱检查显示选中状态，主控须目视相应彩色轨迹隐藏/恢复；即使AX切换通过，轨迹生成/物理正确性仍另测。
- 页面末段锚点保证经过主要长文滚动，不是每一个段落/交叉导流都已测试。相关页面链接没有点击，点击后的route要另列覆盖。
- 21页通过也只能将SC02正常入口局部、SC17阅读局部、SC20控件局部计入，不可把教学正确性或完整SC标为完成。

## 首跑风险与处理

1. SwiftUI在不同Runtime可能把Picker或菜单Toggle呈现不同AX类型；失败先保存AX核对实际层级，再只修独立诊断定位。不改产品ID/声明，也不吞断言。
2. reveal采用页面内部(0.75,0.78)→(0.75,0.32)滚动，上限32次；要求控件可点且中心位于去掉顶底栏的安全区域。其目的为避免“离屏exists”假通过。大字体/短窗口若锚点块高度超过安全区，先核对滚动证据，不能随意放宽到exists。
3. 后旋readout可能需要下滚，回切滑动时使用最多8次反向滚动重新露出Picker；若仍失败需依据AX定位，不算已证实产品缺陷。
4. AngleDynamic菜单关闭采用顶栏中部坐标，未假定可调网格已改变。若不同设备该坐标落在菜单内，依据截图改为实际安全区域，不能带着弹出菜单误判返回。
5. 两图谱初始allEnabled来自VM源码，第0轨应“已选”；若首次出现不同值，保留状态，查入场/加载/AX是否正确，不直接把初值断言删除。
6. 目前仅作了文件结构/21方法与源码标识核对，**没有Swift编译结果**。主控先单页或小组首跑，确认公共导航/输出路径，再扩大到21页，防止公共定位错误让整批无效。

推荐顺序：学01/学06/理01/理04四种页面壳先跑；共用帮助函数稳定后其余17页。主控记录每页输出与失败，后续工作不自动覆盖旧证据。

定位策略：有现成ID的分类、滑杆、图谱、Picker、球库均优先ID；正文/卡片在冻结代码没有逐段ID，因此用经源码核对的中文锚点。用户要求不改业务，故不为测试给生产补ID；语言由launchClean固定中文。
