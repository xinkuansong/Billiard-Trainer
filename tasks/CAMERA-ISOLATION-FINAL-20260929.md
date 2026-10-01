# 三视角隔离 W0/W3/W4/W5 实施与验收

> 2026-09-29：用户否决整体视角重构并要求恢复旧版。本文件保留历史方案／验证记录，已停止作为当前实现或体验验收依据。当前恢复范围见 [回退记录](CAMERA-ROLLBACK-20260929.md)。

日期：2026-09-29。**状态更正：FL-094交互返工重开，不能作为最终通过结论。** 后续真实手势复验发现输入分派、拖动语义及沿杆观察问题，见[交互复验](CAMERA-INTERACTION-AUDIT-20260929.md)。以下保留当时实现、自动测试与截图证据事实；用户手感与真机未验，未提交、未发布。

## 职责与实现

| 模式 | 眼位 | 视线与输入 | 独立记忆 |
|---|---|---|---|
| 瞄准 | 实际击球点沿真实倾斜杆轴后退0.90m，再竖直上偏0.13m；打点/仰角更新时重新计算 | 方向尺改真实杆向；相机拖动不生效；捏合仅光学放大 | 1～1.25倍镜头偏好；杆姿取最新有效业务上下文 |
| 观察 | 首次从母球向杆向反方向找到桌外框再退0.38m；眼高为台呢上0.84m。之后固定 | 双轴原地转头；新对象已在可读区域则不转头，否则只转至可读区边界；不会强制对象居中 | 站位、朝向、倍率、带board epoch的对象ID及有效性 |
| 全局 | 始终环绕桌面中心；C默认 | 水平旋转、30～55°俯角、距离0.90～1.08C；不读手指命中位置、不支持局部放大 | 方位、俯角、相对距离；切换/2D保持，视口变化重算C基准 |

人视角放大按tan(FOV/2)换算，1.25表示实际投影放大倍率；水平FOV上限56°、垂直40°。观察高度/退距沿用改动前的较低基线，不将其写成用户确认数值。拖动 pitch 边界−80～30°仅约束转头，不改变身高。每日可读区域取实际中间球桌区并内缩16pt；其他页面在场景可见区域内缩16pt。

架构：InteractiveCameraController持有唯一活动模式、三份独立状态及转换代次；三个策略输出eye/orientation/verticalFOV；CameraPoseRenderer独占新3D路径写入。CameraRig只做迁移适配、手势分派和2D交接，旧playerView/keepsWholeTableFramed等为兼容读值。过渡中输入保留目标模式的合法站位，不把途中眼位保存为永久站位。

## 播放与生命周期

实际出杆只在瞄准状态且有明确本杆目标ID时登记自动站起。触球只启动球体动画。目标球的pocket事件作为同一个SCNAction时间轴的并行动作，到达事件时间后检查球ID、board epoch、播放代次与手动操作版本，消费一次后进入正常观察。球停后不回瞄准；普通新杆也不抢走观察/全局。无明确目标的自由击球不猜首碰球。

2D保存完整session，返回时保留各模式偏好；瞄准采用2D期间更新的杆姿。撤销恢复出杆前完整session及当时杆姿。历史回放不登记自动站起，退出恢复回放前相机会话。新球形清空人视角上下文/对象epoch，同一桌的全局记忆保留。对象进袋只标失效，不改成母球。

## 消费者及写入点盘点（W0/W4）

| 消费者 | 最终策略 / 边界 |
|---|---|
| FreePlayView每日清台 + PositionPlayViewModel | 完整三模式；真实球点击传ID；无解全局仍可用；实际目标进袋后站起；每日撤销、编排撤销、回放快照 |
| 自由击球、ShotSimulationView、PositionPlayComposerView | 同VM通过显式enable启用；相机关注ID独立于业务selectedTargetKey；不把自由瞄准变成袋口选球 |
| SceneAimingView / AimingQuizViewModel | 显式启用，新题更新epoch；保留题目/答题业务；观察记忆不因再次按按钮改成母球 |
| ShotSceneCameraButtons / SolverStageChrome | 显式启用三模式策略；沿用宿主现有按钮/菜单能力，不额外扩充业务入口 |
| PlanThree、SiluTrainer、SnookerTactics | setup启用；明确目标实打接pocket事件；既有撤销快照扩为完整session，历史回放恢复进入前session；杆末loadBoard不当作新场景 |
| BankShot、DiamondSystem | setup启用；求解模式实打有目标才登记进袋事件；演示/回放不登记。求解撤销、自由击球撤销、回放均保存完整session |
| BreakFlowRunner | 沿用宿主camera rig，开球没有单一目标，不登记自动站起；不重写其物理/选球/杆末状态 |
| AngleDynamic、CushionEnglishAtlas、SeparationAngleAtlas | 保留原图册只读/全局策略，不自动新增人视角；共享仪表输入仍走原业务 |
| AimPointSceneTrainingView | 固定教学瞄准入口保留legacy；没有三模式切换业务，答题控制不迁移成自由观察 |
| DrillSceneView / DrillStaticPreview | 静态/只读契约保留；不启用交互session，不改变缩略图/精讲输出 |
| SequenceVideoExporter | 独立RenderContext使用旧静态/教学镜头；showAimingCamera/snapToAimPose及固定导出camera写入归导出所有权 |
| AppearanceCombinationPreview | 设置中的静态资产预览，自有固定camera，无交互session |
| RoomReflectionProbe | 反射探针的六方向采样camera，自有渲染目标，与用户视角无关 |
| AngleTrainingScene初始化/2D/snapToAimPose | 初始化和2D交接写入明确隔离；snapToAimPose仅旧教学/导出调用。新交互最终输出只由CameraPoseRenderer写入 |

检索留档：build/camera-isolation-20260929/consumer-calls.txt、camera-writers.txt、final-consumers.txt。除命名camera外，已按setup、renderer、导出上下文及模式入口追踪实际写入归属；保留旧API用于这些明确消费者，不宣称全仓删除legacy。

## 基线与失败修复记录

- W1基础23项、W2全局36项+1UI为分批证据，见对应报告；不能加总冒充最终独立用例数。
- W3首轮发现目标边界转头超出约3.7px；改为首次进入可读区域的最小旋转（二分），29项最终通过。四球形（普通、远台、近库抬杆、斜向）×瞄准/固定站位观察/被否决目标pivot共12张原生图，参数JSON记录eye/quaternion/FOV/投影和实际台呢高度。
- W4曾因新增Swift文件未刷新工程、SCNAction异步重载选择导致编译失败，已修工程登记和同步调用；失败日志保留。
- 旧“观察目标强制居中”断言按用户批准模型改为固定眼位+对象身份；全局居中断言保留。2D往返诊断字符串曾因1e-7m浮点尾差失败，改为1e-5m数值判据；没有放宽产品几何约束。
- W4最终55单元/场景+2UI通过，真实桌上目标点击、目标进袋后站起、手动全局优先及重打恢复都有实际UI证据。
- W5初轮57核心通过；追加自由瞄准点击的独立关注ID、共享页回放/撤销session与导出隔离后，以最终76项重跑为准。初轮UI在已知源码更新后由执行者中断，保留旧日志，不计作最终验收。
- 新截图测试写盘面已登记，仅写本任务build目录；门禁首次缺登记失败、补齐后通过，不绕过门禁。最终SE测试零退出后，外层清理对已关闭模拟器再shutdown报405，续跑尚未执行的iPad单元；三单元各自的真实测试退出码和源码稳定性独立记录，未将清理报错算产品失败或吞掉测试失败。

## T01～T16 证据映射

| 合同 | 自动证据 |
|---|---|
| T01/T03/T08 | InteractiveCameraControllerTests的三份状态隔离；HumanCameraIsolationTests跨模式/2D往返；真实UI目标→全局→瞄准→观察与2D链 |
| T02/T06 | 多个对象、横竖拖动、镜头缩放逐帧eye不变；已可见对象不转头；出界对象只转至可读边缘；真实桌上点球 |
| T04/T05 | 64个实际CueStick轴向/抬杆组合；修改strike/elevation后回瞄准；拖动不改瞄准；2D更新杆姿与撤销历史杆姿分别验证 |
| T07/T10/T12/T14 | 三种viewport的1800帧全局中心/距离/FOV；零输入与0尺寸保留状态；缺少杆姿仍可用全局；实际三设备缩放与旋转链 |
| T09 | 同坐标不同ID/同ID新epoch、进袋失效无母球回退、新球形清空人视角；业务自由瞄准点击不改业务目标但更新观察ID |
| T11 | A→B→C中断、owner/代次、剩余动画快照、过渡输入不保存插值eye；零时长分支 |
| T13 | ShotCameraTransitionTests的目标/其他球/母球/旧代次/手动取消；SCNRenderer实际动作时钟0.4s保持瞄准、0.7s进观察；真实出杆UI与重打；12项共享撤销回归 |
| T15 | 所有三模式宿主明确enable和共用策略；共享10页2D/3D与打点UI；翻袋/反射求解与自由模式相机切换业务不变；角度训练另列实际入口验证 |
| T16 | 旧rail及X1教学相机回归、15种旧pose转换矩阵对拍；独立导出前/无操作重复/交互后实测矩阵和FOV相同，9图对照 |

这里区分同一测试的多项断言和测试方法数；64杆姿/1800帧不是64/1800个独立测试。

## 最终验收结果

最终核心集76项0失败（final-r2/standard/test.log）：7交互合同、6旧写入性能、6每日杆姿、1C基准、11人视角/实际模型/导出、13控制器、7全局、12撤销快照、3旧rail、4进袋事件、6旧教学/全局相机。UI最终共13次执行0失败（7个不同测试方法，跨设备重复不算新用例）。

离线像素对照初次逐字节断言失败；新增无操作重复对照和实际节点诊断，镜头矩阵/FOV相同、交互开关始终false。固定输入9图中，无操作重复的RGB平均绝对差为0.0019～0.0093/255，交互前后为0.0008～0.0103/255（最终运行）；画面逐图构图一致。这证明交互会话未串入该固定导出输入，不宣称SceneKit逐像素确定性或所有视频模板都重验。最终矩阵已重跑该用例，数值与9张原图SHA保存于export-isolation/comparison.json。

| 最终单元 | 环境 | 核心 / UI执行 | 实际页面截图 |
|---|---|---|---|
| standard | iPhone 17 Pro / iOS 26.3 | 76 / 6，0失败 | 75张，5张联系表已审 |
| compact | iPhone SE 3 / iOS 17.0 | 0 / 3，0失败 | 33张，2张联系表已审 |
| ipad | iPad Air 11 M3 / iOS 26.3 | 0 / 3，0失败 | 33张，窗口态与全屏分别核对，2张联系表已审 |
| angle | iPhone 17 Pro / iOS 26.3，角度训练 | 0 / 1，0失败 | 9张，1张联系表已审 |

合计150张实际UI原图，另有12张原生几何场景与9张导出对照。标准、小屏、iPad全局桌心投影最大误差分别为0.000095 / 0.000050 / 0.000260pt，按实际SCNView视口计算；小屏视口667×378pt与整屏667×375pt的差异单列，不能表述为整屏零误差。

最终证据根目录：`build/camera-isolation-20260929/final-r2/`。各单元保留command.json、test.log、unit-summary.json、源码前后指纹与图像清单。681份Swift/工程输入/测试脚本指纹在四单元前后相同；资源4349文件自最终矩阵快照至收口未变化，不冒充任务起点的资产对照。SE外层清理报错的续跑说明保存在matrix-resume.txt。最终测试采用Makefile的test-without-building，复用本轮最新已成功构建产物；最终期间生产/测试源码没有修改。

`verify-gate`、`verify-doc-size`、`git diff --check`均通过。原有无关dirty改动保留，未提交、未推送、未发布。[逐设备视觉审查](ui-reviews/UR-20260929-camera-isolation.md)；静态图册`output/camera-isolation-20260929/index.html`，本地预览`http://127.0.0.1:8940/`（非App交互镜像）。

## 验证边界

自动化通过不等于用户已经确认手感。用户尚未复看新的站位/镜头倍率；未做真机触感、持续帧率、温升或发布。系统“减少动态效果”分支采用零时长；数值测试覆盖零时长转换，但不能将注入参数或普通模拟器截图当作系统设置已验证。iPad窗口态与全屏证据分别记录，不声称Split View/Stage Manager所有尺寸已测。
