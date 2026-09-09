# 半遮挡独立数值补验预飞

2026-09-08。仅新增独立诊断草稿与本文；没有注册、构建、运行 App 测试或操作设备。已完整阅读 geometry-spatial-reasoning/SKILL.md 与 table-geometry.md；独立 Python 数学计算已验证以下 golden，不能将此算作生产函数测试通过。

## 原缺口与实际接口

原 SC22“全/半遮挡”的历史 `SnookerSolverTests/test_defenseCoverage_multiBallSample` 是一个全挡目标和另一个全见目标，不能证明部分可见。详见 SOLVER-BOUNDARY-CLOSURE-004-AUDIT.md。本次只补同一目标的三个对照，不重跑求解或 UI。

冻结源前缀 `build/quality-diagnosis/snapshot-004/QiuJi/`：

- `Core/Scene/AngleSceneCalculator.swift:801–848`：判定母球球心直线接触目标的角区间，扩张半径 **2R**，不是照片或屏幕中球体轮廓的 R。`SnookerCoverage` 有 marginDegrees、blockerCloser、visibleHalfAngleDegrees；isFullSnooker 为 closer 且 margin≥0。**不存在 fraction 字段**。
- 同文件 `855–881`：multi 选最佳单个障碍，并不计算多个障碍角区间的并集。本次只放一个障碍，不引入并集要求。
- 同文件 `884–926`：DefenseBallCoverage 有 blocked、coverageMarginDeg、pottingDifficulty。blocked 表示全挡；半挡和全见均可为 false。测试只核身份、全挡值与角度余量，不以难度值代替可见比例。
- `Core/Physics/BTPhysicsConstants.swift:22–26` 中 BallPhysics.radius 为直径 0.05715m 的一半；AngleSceneCalculator.ballRadius 同为 0.028575m。草稿要求两者与独立字面值一致，漂移即停止，不偷偷重算 golden。

源码注释将负 margin 简称半斯诺克，但完全可见时也可为负。负数本身不足以证明部分遮挡，也不能将其绝对值当成精确可见角宽。该表述限制不等于本次已发现数值错误。

## 独立数学与三个同目标对照

SceneKit 世界坐标 XZ 为水平面、Y 向上、单位米，角方向 atan2(z,x)。共同母球 `(0, surfaceY+R, 0)`、目标 `_9=(1, surfaceY+R, 0)`；唯一障碍 `_2` 与两者同高。以下只列 XZ。所有距离均大于 2R，障碍比目标近，无贴球、角度跨 ±π 或球重叠。

令 D=2R=0.05715，独立切线三角形半角为 `atan2(D, sqrt(d²−D²))`，不用生产 asin 或 coverage 函数求预期。角区间 I=[方向−半角,方向+半角]。交集长度为 `max(0,min(T上,B上)−max(T下,B下))`；测试专用遮挡比例为交集长度/T长度；独立有符号包含余量为 `min(T下−B下,B上−T上)`。本组无环绕，普通区间运算适用。

目标角区间始终为 **[-3.2762388852634463°, +3.2762388852634463°]**。

| 对照 | 障碍 XZ（米） | 障碍角区间（度） | 独立遮挡比例 | 独立余量（度） | 期望全挡 |
|---|---|---|---|---|---|
| 全挡 | (.5,0) | [-6.563251778769833,6.563251778769833] | 1 | 3.2870128935063865 | true |
| 半挡 | (sqrt(.25−D²),D)，即 (.49672313968648574,.05715) | [0,13.126503557539666] | .5 | -3.2762388852634463 | false |
| 全见 | (.5,.2) | [15.709429582581446,27.89338939012218] | 0 | -18.985668467844892 | false |

半挡须同时满足交集>0、交集<目标区间宽、障碍下边界=目标中心射线、上边界超出目标上界；不会仅断言 false。对生产 Single、单障碍 Multi 和 Defense 映射检查全挡真假及各自数值余量；目标半张角须固定不变。独立 Double fraction 容差 1e-12、golden余量1e-10°；生产 Float 余量/半张角容差1e-4°，用于浮点转换误差，远小于本组分类间隔。

## 待主控注册的一个方法

`QiuJiTests/HalfOcclusionDiagnosticTests/testSameTargetFullHalfAndClearAngularCoverageMatchesIndependentIntervals`

草稿：`tasks/quality-diagnosis/HalfOcclusionDiagnosticTests.swift`。预期方法数 **1**、数值场景 **3**，目前实际执行数 **0**。需主控审阅后选现有隔离内存测试宿主，不可误用普通用户宿主。

前置：专用新无凭据模拟器，`QD_HALF_OCCLUSION_AUTH=NEW_EMPTY_MEMORY_HOST`；`QD_EXPECTED_DEVICE_UDID` 必须匹配实际 SIMULATOR_UDID；绝对 `QD_SHOT_DIR`。设置支持直接与 TEST_RUNNER_ 前缀。宿主进程启动参数必须已有 `-v50.inMemoryStore`，以保证 App 初始化前隔离；不得有 authenticatedProfileFixture/forcePremium/forceNonPremium。单测本身不会启动 App、修改用户偏好、创建身份或清库；前置检查不代替主控核实新设备及宿主启动配置。

每次在证据根下创建唯一 UUID 叶目录，保留 `three-interval-comparison.json` 和同内容 XCTest attachment。记录输入、独立区间/比例、实际 single/multi/defense 数值和失败列表。所有三组数值失败先积累并写证据再 throw，避免首组不匹配丢失其余对照；危险前置直接 throw。没有清理用户沙盒或覆盖旧证据。

## 证据边界

数学 golden 已独立计算；`xcrun swiftc -frontend -parse tasks/quality-diagnosis/HalfOcclusionDiagnosticTests.swift` 已退出 0，无输出，只证明语法解析，不代表类型检查、链接或测试通过。正式执行以后才可将此补记为 U 层半遮挡对照。即使通过，也不证明真实桌面精度、画面遮挡比例、球袋难度、所有角度环绕/贴球、多个障碍联合遮挡、求解器找到全挡方案或规则裁定。此处的 50% 只属于接触射线角区间，不是球面面积或像素比例。
