# iOS Architecture Skill

## DR-290 — 空间所有权的域

LocalPocketOwnership.Domain显式区分pocket(id)与airborne，后者的pocketID为nil。接触晋升保留域，不得给腾空球指定最近袋ID。混合入口恢复初始腾空所有权后，球球与静态接触共用原调度和时钟；有pending时不可重建owner。落台交回需真实有限台面支撑并与空间接触组分离。空中捕获按实际六袋边界逐一验证，completeCapture只移除已确认的所有权，不自行证明捕获。LocalHandoff的pocketID现为可选，消费方须区分空中与袋口交接。

Changelog：2026-09-14 / DR-290 / 腾空主入口、越球/碰球及落台交回。

## DR-289 — 接续引擎的时钟边界

EventDrivenEngine.init(tableGeometry:startingAt:)只用于新实例的非负有限绝对时钟，保留Double空间时钟及Float兼容镜像；原零时刻入口不变。调用方须先证明球状态受台面支撑并设置球；该接口不恢复此前轨迹、事件、所有权或碰撞缓存，不是完整仿真存档恢复。maxTime仍为绝对截止时间，不能当作新增时长。跨段呈现还需合并原空间记录，不能从首帧已有时间推断完整回放已支持。

Changelog：2026-09-13 / DR-289 / 起始时钟与六组落台后停稳验证。

## 触发场景

在以下情况读取并遵循本技能：
- 设计新 Feature 模块结构
- 讨论 ViewModel 与 Repository 的边界
- 评估是否引入新 SPM 依赖
- 重构现有代码分层

## 标准项目结构

```
QiuJi/
├── App/
│   ├── QiuJiApp.swift    # @main
│   └── AppRouter.swift             # 跨 Tab 路由
├── Features/
│   ├── Training/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/                 # Feature 专属 DTO（非 SwiftData）
│   ├── DrillLibrary/
│   ├── AngleTraining/
│   ├── History/
│   └── Profile/
├── Core/
│   ├── DesignSystem/
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   └── Spacing.swift
│   ├── Components/                 # BTDrillCard, BTEmptyState, BTLoadingView...
│   └── Extensions/
├── Data/
│   ├── Models/                     # @Model SwiftData 实体
│   ├── Repositories/
│   │   ├── Protocols/              # DrillRepositoryProtocol 等
│   │   ├── Local/                  # LocalDrillRepository
│   │   └── Remote/                 # DrillContentRemoteRepository (optional), BackendUserRepository
│   └── Services/
│       ├── DrillContentService.swift
│       ├── BackendSyncService.swift
│       └── AuthService.swift
└── Resources/
    └── Drills/                     # Bundle 内 fallback JSON
```

## MVVM 分层规则

```
View
  └── 读取 @Observable ViewModel 状态
  └── 调用 ViewModel 方法（用户意图）

ViewModel
  └── 调用 Repository Protocol（不直接访问网络/SwiftData）
  └── 暴露 @Published 状态给 View

Repository Protocol
  ├── LocalRepository（SwiftData，离线主存储）
  └── RemoteRepository（自建 REST API：用户同步 + 内容 OTA，后台执行）
```

## 错误处理模式

```swift
enum AppError: LocalizedError {
    case networkUnavailable
    case syncFailed(String)
    case contentNotFound
    case authRequired
    // ...
    var errorDescription: String? { /* 用户可读中文描述 */ }
}
```

ViewModel 中：
```swift
func loadDrills() async {
    do {
        drills = try await repository.fetchDrills()
    } catch {
        errorState = AppError.from(error)  // 转译为 AppError
    }
}
```

## SPM 依赖评估清单

引入新依赖前必须回答：
1. 是否有系统 API 可以替代？（优先系统 API）
2. 该库是否维护活跃（近 6 个月有 commit）？
3. License 是否兼容商业使用（MIT / Apache）？
4. 会否显著增加二进制大小（>1MB 需在 ADR 中记录原因）？

## 性能要求

- 启动时间目标：冷启动 < 2 秒（iPhone 12 级别设备）
- 主线程规则：SwiftData 查询可在主线程小批量执行；批量操作（>100条）使用 `ModelActor`
- 内存：长列表使用 `LazyVStack` / `List`，避免一次性渲染全部数据

## 共享观看状态（DR-141，2026-09-12）

CameraRig.PerspectiveState只包含相机current/target/smooth及投影状态。2D/3D往返通过AngleTrainingScene保存/恢复，业务参数与播放时间由原VM持有。显式focus清理旧观察缓存，新球形/新杆通过invalidatePerspectiveView使旧上下文失效。setCameraMode同模式为无操作；异步事务完成必须校验转换代次。复用此接口不能将球位/评分/杆序复制进相机层。

Changelog：2026-09-12 DR-141，共享观看状态与异步转换代次契约。


## DR-142 — 观察相机控制权（2026-09-12）
CameraRig的手动Orbit独立维护距离/俯仰/光轴偏移/FOV，观察焦点不修改业务目标。手动输入从当前可见姿态接管；PerspectiveState包含当前/目标Orbit。observeWholeTable必须获得真实viewportSize，不猜屏幕比例；加载模型安全距离与SceneKit投影须有验证。allowsCueScreenAnchor将自动HUD锚定与手动观察隔离，不得在每帧把手动焦点拖回母球。开球构图只在业务阶段边界触发一次，不在settled或刷新中重复触发。

Changelog：2026-09-12，DR-142新增独立Orbit和自动锚定的控制权约束。


## DR-144 — 空间段与捕获记录（2026-09-12）
PocketEntrySnapshot属于运行时记录，保留捕获清零前p/v/omega、稳定袋ID、绝对时间、值类型几何和模型版本；不能由上一显示帧反推。旧planar-capture-v1只是旧捕获边界，不可称为失去支撑。SpatialMotionSegment只演进无接触区间，碰撞必须分段并交接真实速度/自旋；不得跨接触外推。推进内记录必须接收推进后时间，主时钟与末帧一致。旧BoardSnapshot保持二维，动态高度不扩散到普通内容。

Changelog：2026-09-12，DR-144运行时入口/无接触段与时钟契约。


## DR-145 — 袋口有限表面检测（2026-09-12）
PocketContactTriangle用于局部空间接触，使用世界米/Double。firstContact只检测接近的冲击，不处理持续支撑；静止台面球必须由约束/支撑求解器处理。面/边延长线求根后须用有限三角形最近点过滤，碰撞分段时间不依赖显示FPS。实际几何适配需单独核对MobileClothAlignment条件，不能整体抬升模型，也不能将原始袋网细丝全部当刚性壁。

Changelog：2026-09-12，DR-145局部连续接触接口与支持边界。


## DR-146 — 局部响应和网格（2026-09-12）
PocketContactResponse.impact采用单位质量冲量、均匀球惯量和库仑限幅，不能只改平移速度不更新自旋。planarSupport不是完整接触求解器：调用方须处理有限边界、曲率与停滑时间。PocketContactMesh只生成实测TaiNi/Leather候选面，保留手机台呢顶点抬升条件；袋网不逐丝碰撞。旧袋心并不保证整颗球与原模型无接触，须测量具体命中面再决定物理代理，禁止改几何来满足未经验证的“无碰撞”断言。

Changelog：2026-09-12，DR-146局部响应和实测网格边界。


## DR-147 — 局部求解的接触激活与收敛
LocalPocketSimulation当前为W05原型，未接主引擎。邻近候选窗口/漂移容差不能直接激活支撑或摩擦；真正接触须按机器舍入误差区分正间隙。多面速度投影后再次释放分离约束，按新速度重算曲率。小反弹收敛仅在冲击时按重力与空间误差预算处理，不对正在离面的球强加支撑。迭代耗尽须抛诊断错误，不能拿最终下落或能量未增代替收敛验收。

Changelog：2026-09-12，DR-147局部支撑集与失败诊断契约。

DR-147补充：局部拒步必须回滚位置、速度、自旋、绝对时间、事件及误差统计后重算；不能只撤回位置。Result.rejectedSteps记录预算开销。拒步能消除单步超限不等于机械能与全程步长收敛已验收，须分别检查。

DR-147补充：持续支撑段末状态须保持球心偏置面的几何约束与切向速度；压力不能为负，其他冲击后不能再吸回旧面。有限面离开必须精确分段，子步末才释放会使重力启动时间随步长漂移。


## DR-148 — 同时多面冲击
同TOI面必须共享冲击前状态联合求冲量，不允许用排序选一个面决定反弹。simultaneousImpact提供同步松弛Jacobi与显式迭代失败；必须验证面序反转/镜像对称/能量。冲击对称通过不代表持续支撑和位置修正也无顺序依赖，需分别验证。

Changelog：2026-09-12，DR-148同时多面冲击接口。

DR-148补充：持续支撑速度/受力与约束末态需分别审查顺序依赖；同步迭代仍需失败守卫。内部接缝完全同法线/同摩擦约束仅保留最严格加速度下界（最小曲率），避免冗余负载交换；不得近似合并真正不同法线。该改动的慢中袋最终收敛尚未通过。


## DR-149 — 曲面接触导数
曲面接触点速度v+omega×arm的导数必须包含omega×armRate，其中arm=-R*n、armRate=-R*nDot；不能把局部平面静摩擦公式直接用于转动法线。曲率=v·nDot，力与停滑时间共用。末位置约束须按新位置实际最近面重建，内部面缝不可只沿旧支撑三角形修正。

Changelog：2026-09-12，DR-149曲面支撑与有限特征导数。

DR-149续验说明：受力残差按实际线/角加速度负载归一化；摩擦试验使用速度级库仑圆盘约束取代近零滑速开关。该试验仍有受力迭代尾差失败，未认定正式方案通过；须验证广义加速度与互补残差，不能只靠最终下落或迭代次数判断。


## DR-150 — 非唯一接触力的收敛
内部力可相互抵消，不能仅以各接触力分量增量判定刚体求解失败。检查广义线/角加速度变化及法向互补、库仑圆盘可行性；加速度残差转换到全段空间误差预算，仍保留迭代失败与独立能量/穿透/步长回归。该判据不代表所有场景已验收，按实际矩阵证据标范围。

Changelog：2026-09-12，DR-150广义运动和约束可行性收敛。


## DR-151 — 候选索引
PocketContactIndex只加速候选查询，保留原始面编号与确定顺序。LocalPocketSimulation支持useSpatialIndex=false严格对拍位置/速度/自旋/时钟/事件/拒步次数；不可用“看起来相同”代替对拍。模拟器计时不替代手机帧预算与发热验收。

Changelog：2026-09-12，DR-151局部空间索引。


## DR-152 — 有限碰撞根
无限面/边解析根只是候选，必须用有限几何距离抛光并验证后选择最早事件。宽松距离筛选会制造提前同TOI接触，不能依赖冲量求解器消化不存在的接触。配有短horizon应无碰撞、延长horizon应命中真实边缘的闭式回归。

Changelog：2026-09-12，DR-152有限特征根校正。


## DR-153 — 实际运动候选范围
局部支撑/摩擦可改变水平加速度；初始重力范围只用于获取当前支撑，CCD和末状态投影须使用实际求解加速度重新查询候选。候选加速仍需与穷举严格对拍。

Changelog：2026-09-12，DR-153实际加速度查询。


## DR-154 — 局部迭代与误差控制
LocalPocketSimulation的Anderson接触力候选仅在实际残差降低时接受，原收敛守卫继续有效；不使用跨步热启动。run以一步/两半步估计局部位移误差，只写接受的细分轨迹。内部integrate保留外层整段convergenceHorizon；不能因分段而放宽接触可行性。局部误差、全轨迹收敛、机械能、穿透分别验证。
单球静态自主平衡可直接续到末时刻；未来多球调度必须按外部最早事件唤醒，不能沿用无外部事件假设。切向滑速的零判定基于16*Double.ulpOfOne*(|v|+R|omega|)算术舍入界，不是固定静/动摩擦速度阈值。小时间段会放大抵消噪声，摩擦请求与残差校验必须使用同一滑速计算。

Changelog：2026-09-12，DR-154迭代加速/局部误差控制，W05已按W05-acceptance原型验收；主引擎与手机性能未验。


## DR-155 — 空间球球冲量接口
SpatialBallContact.firstContact接收B-A相对运动，Hit法线A→B；Constraint法线B/固定面→A。resolveCoupled只响应初始接近或静止接触，初始分离约束不供支撑；调用调度器须同时间重建新接近接触，禁止直接推进时间漏碰撞。等质量/等半径，保留三维速度与自旋。此基础尚未接入主引擎，不能视为W06完成。
Changelog：2026-09-12，DR-155空间接触基础，六项测试通过，主调度待接入。

DR-155补充：resolveInstant接收全部几何接触候选（含初始分离者），固定时间重建激活直到法向接近残差满足联合求解标准；预算不足明确抛错。返回每轮Motion诊断，不推进时间，不替代几何检测。Changelog：2026-09-12同时间闭环七测通过，主调度待接入。


## DR-156 — 静态袋口几何输入
PocketContactMesh新增table/worldRoot/pocketID/center/surfaceY/bedY/alignCloth入口。调用方独占节点树并提供实测高度，输出纯数值网格可独立于场景生命周期。scene包装入口保持原有坐标/台呢对齐行为。缓存与无场景高度测量仍待接入，不可据此宣称主物理已独立运行。
Changelog：2026-09-12，DR-156静态几何解码，角中袋逐顶点一致及接触回归八测通过。

DR-156补充：PocketGeometryAsset.load通过独占TableModelLoader节点和静态树bedY测量初始化六袋，无需训练场景。固定使用校准台面契约，与观看模式独立；锁保护初始化，缓存只含纯数值，失败抛出且不缓存。Changelog：2026-09-12六袋逐顶点/高度一致及缓存复用九测通过，主引擎待消费。


## DR-157 — 局部区间与球球CCD
LocalPocketSimulation.Result.intervals只保存接受段，含起态、实际线/角加速度与右端碰后状态；sample(beforeEndpoint:true)在右端返回碰前左极限。firstPairContact按绝对时间合并不同分段并连续检测，返回A→B法线与两球碰前状态。检测后未来预测须失效，段端静态碰撞需统一接触集处理，禁止将单球独立碰后状态叠加。
Changelog：2026-09-12，DR-157十四项测试通过；主事件接入未完成。


## DR-158 — 多球推进尚缺持续球球支撑
advanceTogether已处理最早事件截断、联合冲量及未来重算，但初始静止接触对缺少持续支撑力，pair-support-red-r1红。不得接入正式App或以动态碰撞测试替代支撑验收；先补力级接触、分离/滑动与能量/步长验证。Changelog：2026-09-12开发中，十五项瞬时/基础回归通过，新静止支撑一项两断言失败。


## DR-159 — 持续接触力接口
resolveSupport使用SupportConstraint.normalRate构建曲率法向条件，输出每约束对A单位质量力及各球线/角加速度；静/动摩擦按实际接触滑速选择，分离不承力。先解瞬时冲量，持续力与积分仍须联动验证。
Changelog：2026-09-12力级与冲量九测通过；尚未接入advanceTogether，原静止双球演进反例仍红。

DR-159演进补充：每个共享步刷新力，仅转交球间力/力矩，台面反力不重复计入。外力矩通过externalAngularAcceleration参与局部支撑和运动；力级残差收紧为64ulp，零时刻CCD仅舍弃整区间速度变化也处于舍入界的根。Changelog：2026-09-12 pair-force-integration-r2十八测通过，原静止反例修复；移动接触漂移/共同误差/性能仍未验证。


## DR-160 — 压力接触投影
持续力的正法向压力集合用于单个有界试算的距离/法向速度联合修正。位置修正超过4*tolerance时整试算拒绝减步，不得扩大接触激活距离。压力球对该试算内不重复发冲量事件；后续仍须验证步中失压释放和共同误差，不能当成无条件保持接触。
Changelog：2026-09-12十九项测试通过；共同误差/能量/真实脱离未验，主引擎未接入。


## DR-161 — 共同积分误差
advanceTogether默认一步/两半步验证全部球及事件时间，只提交接受半步，rejectedTrials记录拒步。useSharedErrorControl:false仅供固定组步长收敛对照；不可用固定步长的相邻误差单调假设衡量自适应运行，需按误差预算独立验收。
Changelog：2026-09-12 shared-error-r3二十测通过，能量误差随预算收紧下降；失压释放/实际网格/主引擎未验。


## DR-162 — 临时力求解器复用几何
private init(base:)共享不可变局部网格/index并保留穷举开关，只叠加球间外力/力矩。脱离验证使用独立守恒约化参考，不能以引擎自身轨迹作期望。
Changelog：2026-09-12二十一项回归及真实角/中袋近台面联合碰撞一测通过；完整多球入袋与主引擎尚未验收。


## DR-163 — 空间球球短时返回根
空间球球CCD在有界时间区间按导数临界点隔离多项式根，不使用绝对时间阈值合并不同根；初始分离与极短时间返回可同时存在。接近方向和有限几何验证仍必需，不修改普通平面求根器。
Changelog：2026-09-12，2ns反例由红转绿，18项基础回归通过；真实多球近袋与主调度仍未验收。


## DR-164 — 单球位置修正与多球几何
单球静态修正可能跨过邻球；多球事件需联合校正单边位置约束，不能逐球投影后直接启动下一次CCD。位置修正不等于冲量，保留入射速度。无事件末态穿透不能当成正常接受步；拒步守卫不替代连续间隙验收。
Changelog：2026-09-12，基础18测通过，真实案例仍有密集接触未解决，开发中。静态联合事件的小反弹策略须与单球入口一致。


## DR-165 — 互补残差与精度衔接
法向互补检查使用速度单位的投影残差，不以lambda严格大于零决定接触是否必须零法向误差；松弛可停在最小subnormal。冲量/同时间闭环与持续力激活共用64ulp精度，防止数值残速产生再接触。小反弹转换使用恢复方向相对加速度及曲率与空间误差预算，不能硬设静止速度。该局部估计仍须在实际袋口和步长收敛中验证。
Changelog：2026-09-12，contact-transition-r2二十项通过；真实案例与主引擎未完成。


## DR-166 — 压力投影残差单位
位置与速度残差分别按自身尺度归一化，不可把世界位置模长用于速度误差。投影允许的法向残速须满足持续力激活精度，否则共享半步会重新产生冲击。
Changelog：2026-09-12，真实状态单平面反例由红转绿，21项通过；完整实际袋口及主引擎尚未验收。


## DR-167 — 联合接受几何
压力集合不包含所有可能被位置修正进入的静态面。组合校正后必须同时满足完整静态和球间单边几何，且总修正相对原始试算受同一预算约束，不能每个阶段各用一份预算。
Changelog：2026-09-12，22项基础/捕获状态测试通过；总预算守卫与真实案例r2验证中，主引擎未接入。


## DR-168 — 世界位置与相对检测精度
firstContact(positionUncertainty:0)允许调用方传入坐标相减前的世界位置舍入界；firstPairContact按该球对计算。联合投影按每个接触自身的位置尺度归一化，不能让其他远处球放宽该接触。位置舍入界与积分tolerance严格分开。
Changelog：2026-09-12，world-roundoff-r1二十三项通过，真实r14重验中；主引擎未接入。


## DR-169 — 联合反力加载支撑
不能仅凭外加重力对单面投影排除接触：其他面反力/摩擦可加载它。支撑候选与末态几何保持一致，承力由联合求解决定；未承力面继续参与碰撞检测，不当成持续约束跳过。
Changelog：2026-09-12，floor+overhang静态平衡反例及28项回归通过；实际双球与W05网格回归待验。


## DR-170 — 最终几何与压力速度
完整单边位置修正会改变接触法线；接受步的速度必须对最终几何满足持续接触精度。最终速度投影不再移动位置，仅处理仍在舍入接触界内的旧承力集合，不能拉回已经释放的有限面。
Changelog：2026-09-12，实际半步衔接反例由红转绿；基础及W05网格回归共33项通过，完整双球r16及W06未验收。


## DR-171 — 球心接管域与覆盖余量
PocketLocalRegion仅表达局部所有权的横向区域，不是进袋或失支撑判据。网格候选窗必须覆盖球心区域加一个球半径。firstCrossing保留全部二次边界根，以相邻开区间成员关系区分进入/离开/相切，不用绝对时间epsilon合并短事件。PocketGeometryAsset.regionsByPocketID与数值网格共用真实袋ID。返回平面仍须验证支撑与竖向状态，不仅检查跨出区域。
Changelog：2026-09-12，DR-171局部域与扩展网格两批6次测试执行通过；支撑变化提前量/返回/主调度未完成。


## DR-172 — 局部所有权与返回证明
LocalPocketOwnership保存Double世界状态，组更新先核对revision与统一非倒退时钟，再原子提交；重复进入和重入前的旧更新抛错。returnToPlanar需匹配袋ID/版本并通过solver.planarReturn后才释放。返回判据包含向外边界/域外、真实有限台面支撑和实际切向速度，不能仅看XZ或把离台球压回。加载台呢可有一Float ULP顶点高度差；只允许整面处于标准台面该表示精度层内，确认脚点在有限面，按现有空间预算转换到标准Y并归零微斜率vy。水平p/v、自旋和Double时间不变。
Changelog：2026-09-12，DR-172三项通过含真实六袋代表边界；全方向/主引擎未接入。


## DR-173 — 主引擎局部接入验证入口
simulateWithLocalPockets是当前W06显式验证入口：Double时钟/局部权威状态、旧平面事件与区域进入竞争、局部区间/交接记录、真实支撑返回。当前单球限制显式抛错，正式simulate未切换；共享调度与规则capture必须完成后才能启用App。局部状态不得从publish给旧消费者的Float镜像反构造。evolvePlanarBall与旧simulate共用原平面方程，局部不走bounds/旧吸袋。
Changelog：2026-09-12，DR-173单球主路径开发中，未完成W06。

## DR-174 — 数值物理代理的台面精度
PocketContactMesh仅将TaiNi中距标准Y不超过surfaceY一Float ULP的顶点对齐，避免实际平面被导入舍入制造微折面；maximumBedAdjustment保存最大变动。更低曲面、非台呢材质及显示模型均不变。几何代理变动须回验真实进入路径，不能只沿用从接缝内侧起步的局部fixture。
Changelog：2026-09-12，DR-174解决主入口暴露的台面接缝；实际矩阵与多球回归按新几何验证。


## DR-175 — 局部结果续算
同一局部运动在任意请求时间截取时保留未消费的完整积分步，绑定当前owner revision；续算先消费缓存，不能把请求时间变成新的积分网格起点。只记录已接受前缀，后续外部事件必须作废旧预测。当前仅验证无输入变更的单球续算，不能外推为混合事件缓存已完成。maxTime验证使用Double spatialTime，同一时刻无操作。
Changelog：2026-09-12，r4三项通过；r5精确p/v/omega续算一致性及同时间无操作通过。

## DR-176 — 跨所有权接触预测
findNextEvent(excluding:)只过滤候选，不删除球；firstLocalPlanarContact在同一绝对时间上用局部空间段与平面方程做球球CCD，止于下一平面事件，返回接触状态但不提交。调用方必须先处理更早事件并重算，接触响应后作废未来区间。预测加速度必须与实际AnalyticalMotion演化域一致，不能借用较大的运动分类阈值而在低速区改成匀速。当前混合主循环仍未完成。
Changelog：2026-09-12，DR-176；低速独立解析反例由红转绿，39项回归通过。

## DR-177 — 碰前共同状态入口
LocalPocketSimulation.resolveContactGroup接收同一时刻的完整接触组及各球加速度，复用局部推进中的静态/球球联合响应，返回瞬时碰后状态，无运动区间。调用方负责包含所有接触邻球及其静态几何覆盖、推进时间、原子提交与预测失效；不得将只有两球且漏台面支撑的交换速度作为跨owner响应。当前主混合循环尚未接入。
Changelog：2026-09-12，DR-177共用响应入口；原局部推进同源调用。

## DR-178 — 全桌接触候选快照
PocketGeometryAsset.tablePatches是与六袋局部网格相同材质/变换/精度契约的未裁窗候选，可供跨owner邻球支撑查询；PocketContactMesh.load的coverage缺省pocket，fullTable只关闭候选窗，不扩大所有权域。主循环接入时复用空间索引及只推进活动局部组，禁止把全桌候选等同于全桌空间积分。当前全桌候选未覆盖声明之外的材质/隐藏回球系统。
Changelog：2026-09-12，DR-178全桌候选和域外支撑证据。

## DR-179 — 混合主循环验证
simulateMixedWithLocalPockets使用全桌几何支撑活动空间组及接触晋升的域外邻球；普通台面球维持平面演化。共同Double时钟选最早事件，响应后共同提交所有权账本并清平面缓存。球球系数显式输入；此验证入口未替代生产simulate。不得宣称混合任意截段精确续算已支持：当前只保留单球pendingLocalResult机制，混合完整步缓存与外部变更失效仍须完成。实际返回、同时事件与事件记录必须另验。
Changelog：2026-09-12，DR-179混合事件主路径首次接入验证。

## DR-180 — 混合步骤的时间查询边界
PendingMixedStep使请求时间只裁消费前缀，不裁原始积分网格。缓存保留局部区间、平面步骤初态/终态及事件动作；晋升/碰撞/进入只在事件时间提交，不能在计算未来时发布。每次部分提交更新owner revision，缓存绑定参数及setBall输入revision，失配明确拒绝；尚不代表运行中外部编辑后的自动重接管已实现。单球/混合入口不得交叉消费对方缓存。原始区间和完整终态不从Float镜像反建。
Changelog：2026-09-13，DR-180混合精确续算原红例修复；完整批次仍待验。

## DR-181 — 共面接缝投影与碰撞时间
支撑投影nearest距离舍入并列时，若垂足位于一个有限面的内部，则同平面但离垂足有可分辨距离的边缘不能同时成为接触。只在明确有限面覆盖+共面条件下排除，不放宽收敛误差，不移除真实孔洞边缘或非共面接触。首次碰撞元数据与resolvedEventTimes必须使用同一绝对currentTime；event.time是本次预测相对时间，不可直接上报。
Changelog：2026-09-13，DR-181真实连续再入暴露并修正共面投影、首次碰撞绝对时钟。

## DR-182 — 静态接触的接受前缀
CoupledAdvance.staticContacts与intervals采用同一接受路径；被拒绝整步或球球事件之后的猜测不保留，同刻按联合响应重建。混合缓存独立保存包括晋升邻球在内的逐球静态事件列表，逐条消费而非靠显示帧推算，截止前不发布未来事件。TrajectoryRecorder.localStaticContacts的surface索引只在对应geometryID/tablePatches快照内解释，不能凭最近袋口猜测，更不能直接计为一次业务吃库。持久化需增加明确几何版本契约。
Changelog：2026-09-13，DR-182局部静态接触传播至主记录。

## DR-183 — 同刻事件与所有权变更
区域进入或跨区响应不应自动排除同刻独立平面事件。用事件涉及球集和最终owner集区分：无关事件保留并在同一绝对时刻提交，有关事件交新的局部/联合响应，避免旧平面双算。相对事件时间先与预测起点相加后比较。t=0进入与不相关球对接触应得到与独立平面参考相同的响应。
Changelog：2026-09-13，DR-183同刻独立事件直接提交，4项回归通过。

## DR-184 — 确认捕获与运动分离
ConfirmedCapture保留完整Double捕获状态和几何版本，recordConfirmedCapture只负责原子记录/幂等，不自行证明物理不可返回，不写.pocketed帧或清运动。isBallPocketed(_:at:)在有新记录时以其绝对时间为权威，无新记录保留旧帧兼容。生产调用者必须先验证捕获几何/规则，禁止把局部进入、任意下降深度或动画结束直接灌成确认记录。
Changelog：2026-09-13，DR-184捕获记录契约及旧记录兼容三测通过，物理判据未接入。

## DR-185 — 亚分辨率反弹与持续支撑
局部integrate不能只按正vn立即释放多面接触中的支撑，也不能不加条件清零。几何已接触且法向恢复加速度为正时，以vn²/(2a)≤空间tolerance识别不可分辨反弹；共同切空间投影还须满足总改变量能量预算和其他单侧约束。近乎平行法向可能使投影消除正常切向运动，必须拒绝超预算调整；自旋不因接触收尾清零。超过预算的离地保留解析飞行。
Changelog：2026-09-13，DR-185内部支撑分辨率契约；完整回归状态见W07-working，尚未正式App接入。

## DR-186 — 有效面覆盖的边与末步精度
支撑去重依据最近点是否被另一有效有限面覆盖，不限于两三角形共面；公共边的距离在面垂足刚越过接缝时可舍入相同，不能据此强加第二法向。真正独立棱角必须保留。最终仅在末步投影的当前几何支撑中去重；提前过滤持续支撑候选与未过滤CCD不一致，会产生同刻重复接触，须保留该回归边界。外层步长控制与内层共同处理末步8ULP尾差，二分中点必须严格处于端点之间。
Changelog：2026-09-13，DR-186三项短时回归通过，完整长测状态见W07-working。

## DR-187 — 可行接触力边界加速
当固定点迭代在近中性接触力分配方向停滞，可沿当前力增量解析求下一法向非负/Coulomb边界，作为加速候选。候选须保持原系数及原方程，在可行投影后同时优于当前残差与已有候选；否则拒绝。极小二次系数用尺度归一化和稳定q根式，不能用固定绝对阈值抹掉真正的二次项。不得通过增加迭代上限或放宽接触力精度替代验证。
Changelog：2026-09-13，DR-187数值小样收敛改善；Swift回归状态见W07-working。

## DR-188 — 局部滚动阻力参数（原型）
LocalPocketSimulation.Surface新增rollingFriction:Double=0，保持旧构造调用。非零值以无滑动平面减速度mu_r*N定义，加入forceMap与实际角加速度两处，不能只改其中一个。袋内候选0.01仅参考SpinPhysics现有值，未实标；单球解析与袋内平移停稳已验证。自旋耗散、球球持续支撑预求解、多接触参数边界与正式捕获未验，不可由单面解析测试推定全面有效。
Changelog：2026-09-13，DR-188单球滚动耗散原型和Surface兼容参数；正式App未接入。

## DR-189 — 共享表面阻力矩与法向自旋
Surface.spinFriction默认0，法向自旋系数遵循AnalyticalMotion的5*mu_sp*N/(2R)。局部力迭代、实际加速度及多球支撑预求解共用PocketContactResponse.surfaceResistance。SupportConstraint表面系数不能用于球球接触，非零系数必须提供正有限duration。预求解只传递球球力与力矩，表面反力由局部积分重新求解。解析双球支撑与单面自旋验证见W07-working；不可推定多球长时承接或生产捕获已验。
Changelog：2026-09-13，DR-189自旋与共享表面阻力接口，正式App未接入。

## DR-190 — 有限步持续摩擦一致性
resolveSupport在提供正有限duration时，与局部表面forceMap同样求解slip/dt+接触切向加速度，并将请求力投影到Coulomb圆盘；不能在多球侧对任意微小滑动无条件给满额摩擦，否则近静止出现高成本抖动。无duration的连续力调用保持既有语义。法向、自旋/滚动参数及迭代上限不变。验证应同时覆盖双向滑动停止、尚未停止、连续推进、步长/能量和既有联合支撑。
Changelog：2026-09-13，DR-190单球/多球有限步持续摩擦一致；证据见W07-working。

## DR-191 — 袋网承接数值构建
PocketContactMesh.load材料集合默认TaiNi/Leather保持既有调用，White仅为显式请求。PocketBagEnvelope用值三角面水平截面构建凸包轮廓，中心采用面积重心，交线采用半开端点规则；顶点平均会随三角化改变，不能用它确定采样中心。底部封口及顶部/分辨率参数必须显式标为承接近似，不能复用作不可逆捕获判据。内置模型构建替代本地output候选依赖，但旧多边形脚本与新三角面截面差异尚须量化，不可只按环数/底高相同宣称等价。
Changelog：2026-09-13，DR-191内置袋网数值轮廓；正式物理缓存/入口未接入。

## DR-192 — 袋网连通分量筛选
White包含独立浅层部件，不能只按材质构建袋腔凸包。PocketBagEnvelope在当前模型下保留触及测量底部以上一球半径深部带的完整连通分量；按原始精确顶点连通，不焊接近邻、不裁掉保留分量上段、不移动代理顶部。build的radius默认现有BallPhysics.radius并验证正有限，sourceTriangleCount/selectedTriangleCount用于审计。资产更新时重新检查此模型消费契约及深部带；几何分辨率比较、动态承接、不可逆捕获仍需分别验证。
Changelog：2026-09-13，DR-192排除同材质浅部组件对袋腔的污染。

## DR-193 — 袋网原始值缓存
PocketGeometryAsset.bagSourceTrianglesByPocketID从独立校准球桌一次性提取White数值三角面，与可见场景逐点坐标契约一致；不保留SceneKit/房间/相机。原始White还包含浅层部件，调用者须经过PocketBagEnvelope连通筛选，不能直接把所有源面作为袋腔。长时物理测试使用此缓存，避免引入完整渲染场景资源；减少依赖与证明SIGKILL原因、手机性能是不同证据。
Changelog：2026-09-13，DR-193纯数值袋网缓存与可见坐标对照。

## DR-197 — 完全相同静态冲量约束
球体静态接触arm=-R*n，完全相同body/normal/restitution/friction的多份三角面接触具有相同雅可比与材料律。resolveCoupled求解前精确去重，防止网格三角扇密度改变Jacobi松弛和收敛。禁止用角度容差合并真实不同法线，禁止合并不同材料；不修改原几何候选/接触记录和迭代误差契约。
Changelog：2026-09-13，DR-197；原真实袋底双球反例失败留证，独立解析/重复数量/顺序及真实回归验收状态见W07-working。

## DR-198 — 袋网默认精度
PocketBagEnvelope.Configuration默认radialSamples=128、layerHeight=.00125米。依据为同输入完整.7s与256/.625mm的运动对照，而非仅比较网格轮廓；2mm原位差标准保留。历史诊断若需要64基准必须显式设置，不随默认值漂移。默认几何精度不代表全部入袋/手机性能/不可逆捕获通过。
Changelog：2026-09-13，DR-198；六袋/正常入口回归状态见W07-working。

## DR-199 — 双球接触滑速舍入
resolveSupport的接触滑速舍入尺度包含A/B各自线速度与R乘角速度幅值，避免近抵消时依赖球编号。Swift跨行二元运算符留在上一行，禁止将后续项写成未使用的一元表达式。交换物体编号及法线的纯滚动接触回归必须保留；不以修改摩擦或放宽残差代替修复。
Changelog：2026-09-13，DR-199；原样源码macOS Swift反例红转绿，iOS回归待长测终态。

## DR-201 — 求根前位移界
PocketContactTriangle.firstContact内部顶点/边线roots可按全段位移上界排除不可能接触。使用|v|dt+|a|dt²/2及世界坐标算术余量，禁止用端点净位移替代（转向会漏中途接触）；正交投影不增位移。未排除分支保持原求根与有限几何验证。随机与真实候选对拍不代替完整轨迹/接触变化/手机性能验收。
Changelog：2026-09-13，DR-201；独立Swift对拍通过，iOS及完整轨迹待验。

## DR-202 — 联合冲量外推
resolveCoupled在原Jacobi映射上使用深度一Anderson候选；投影后实际固定点残差优于原下一步才采用。保留独立自然互补/摩擦残差及运动变化的64ulp收敛检查、4096预算，不能仅以外推步变小宣布收敛。候选不缓存到下一事件，真实不同法线全部保留。现场反例/顺序/高速同刻/能量回归与完整入口需分别验证。
Changelog：2026-09-13，DR-202，四项快速回归通过；完整双球见W07-working。

## DR-203 — 有限时间步的法向支撑
单球与多球持续接触有dt时须共同满足vn/dt+a·n+v·dn/dt的法向条件，与切向步末滑速条件一致；无duration的连续力接口保持原定义。多球持续力外推只有投影后原自然残差更小时接受，保留64ulp/4096。极小dt回归应区分归一化系数舍入与真实约束误差：同系数加速度残差检查之外独立验证步末法向速度，禁止单纯放宽求解器阈值。快速状态回归不替代完整接触历程。
Changelog：2026-09-13，DR-203；normal-support-step-r3六测通过，完整双球见W07-working。

## DR-204 — 压力投影的有限特征有效性
projectPressure在每个位置迭代重评估exposedSupportCandidates：面内垂足使其覆盖的边接触失效，但不可按近似法线合并真实折面。只用于压力投影，不提前从CCD或持续力候选中删除接触。内部测试入口须保留现场独立几何间隙/法向速度断言。
Changelog：2026-09-13，DR-204；四项回归通过，完整双球另验。

## DR-205 — 最近点热路径
PocketContactTriangle.closestPoint使用三边直接计算，避免edges/map数组；保持原退化/面内阈值和相等距离首边优先。算法微优化先原样对拍，再验实际接触历程；macOS方法耗时不得当手机性能验收。
Changelog：2026-09-13，DR-205；随机/真实候选逐值一致，生产iOS回归待r4。

## DR-206 — 默认袋代理缓存
PocketGeometryAsset.bagEnvelopes() throws返回按稳定pocketID组织的默认PocketBagEnvelope数值快照。实例锁与资产加载静态锁分开；全套构建成功后才缓存，失败不返回部分袋型。自定义精度走显式build，不污染默认值。模型更换须重新建立资产生命周期；缓存只代表几何复用，不代表捕获或材料参数已验收。
Changelog：2026-09-13，DR-206；六袋独立场景对照在middle-split-red-r2通过，中袋物理反例仍待修。

## DR-207 — 受压球组的静态碰撞截断
advanceCoupledTrial对受球球压力连接的物体，将首次静态碰撞和球球碰撞共同选最早事件；使用碰撞前状态联合冲量并截断所有预测，之后重新计算持续力。禁止让单球内部新壁碰撞后仍沿用整组旧压力到整步末尾。接触约束集合不自动等于业务事件集合，正式调度接入须核实实际冲量/事件语义。
Changelog：2026-09-13，DR-207；短步三测通过，连续推进与完整入口另验。无新接触的持续压力仍须不产生伪冲击。

## DR-208 — 接触组微反弹
preparedGroupSupport先检查真实入射接触，再按现有空间预算识别可消除微反弹；整组线速度法向正交投影必须不增加动能、不引入其他接触穿入，并由重新求得的持续力证明微接触仍承压。不能逐球把速度清零、用固定低速阈值代替高度预算，或将无支撑的真实离地投影回去。位置、自旋、时钟不变；无候选时回原受力流程。
Changelog：2026-09-13，DR-208；现场1ms/入射/能量及两项回归通过，完整入口/跨域另验。

## DR-210 — 事件前缀承压几何
advanceCoupledTrial在静态/球球事件时刻也须校正预测中已承压接触的几何漂移，复用projectPressure边界与有限特征释放；只取位置，入射速度/自旋由共享冲量处理。保持原接触阈值；两次半步与固定步必须分别验证，固定步绿不能替代运行时自适应路径。
Changelog：2026-09-13，DR-210；三项现场/跨域回归通过，完整双球与生产接入另验。

## DR-211 — 可行受力重分配
resolveSupport可在同a/b且仍活动的约束间尝试载荷重分配；每次仍投影非负压力/摩擦锥，仅原完整互补残差严格改善时接受。不能据近似法向删除接触，也不能给inactive约束分配力。原4096迭代/64ulp判据保持，静态/球球几何与材料未改。
Changelog：2026-09-13，DR-211；五约束及8项回归通过，完整入口另验。

## DR-212 — 碰撞见证与停止边界
advanceCoupledTrial保留最早TOI球对作为事件几何校正见证，不依赖根采样位置重新猜接触；保持原空间误差界与入射动量。完整产品优先验证袋口结果/返回/遮挡/统一回放，并落实v63§5.7停止边界；袋底隐藏长期堆积不得自动升级为上线前置。
Changelog：2026-09-13，DR-212；返回球对/既有现场4测通过，r7完整失败仍保留；用户要求复核投入优先级，未启r8。

## DR-213 — 软袋收集候选
PocketCaptureBoundary(bag:hardSurfaces:radius:)基于实际硬质区域下沿及袋网截面；firstCandidate(in:)仅返回时间一致的向下收集候选。提交前isClearOfActiveBalls验证活动邻球同钟/间隙，不能把候选直接当全调度捕获。收集采用吸收式软袋近似，硬质袋角返回仍真实求解；统一可见收尾/回放另接入，长期袋底堆积不自动作为产品前置。
Changelog：2026-09-13，DR-213/ADR-P10-10；边界及普通入口4测通过，正式调度/临界与视觉尚未验收。

## DR-214 — 混合调度捕获提交
simulateMixedWithLocalPockets(...collectsPocketedBalls:false)为显式验证配置；启用时与物理事件共选最早收集候选，所有活动邻球必须在候选同钟取样。PendingMixedStep保存捕获并校验配置，只在完整前缀实际提交时从ownership移除、写ConfirmedCapture及唯一pocket事件；任意请求边界不能提前提交或重复事件。几何版本是收集边界的稳定位模式摘要。运行时停止速度与入口记录保存速度分开，可见收尾及正式默认入口尚待接入。
Changelog：2026-09-13，DR-214；5测通过（普通/连续双球/分段与既有回归），未宣称整个W07通过。

## DR-216 — 规则碰球上报
EventDrivenEngine.spatialImpactEvents统一局部及跨owner原有的碰前closing<0口径，Constraint法线为B→A。局部事件须取接受区间beforeEndpoint左极限，不能以碰后已分离速度判断而漏报；无推进的零时刻事件使用共同起态。求解约束仍完整保留，持续支撑/分离不直接变成新的ballBall业务事件。此接口不负责将静态网格接触映射成吃库。
Changelog：2026-09-13，DR-216；上报红例与四项回归通过，正式消费者切换另验。

## DR-217 — 球球材料来源
SpatialBallContact.MaterialSource.supplied保留显式测试系数；ballPhysics使用BallPhysics.restitution及contactFriction。Constraint法线B→A，接触臂为-R*n/+R*n，摩擦取包含双方omega的相对切向速度。标准材料必须同时用于冲量和持续力，并在临时solver及PendingMixedStep中保留；缓存中途改材料不得无声接续。共用材料不等同于平面约束解与空间响应完全相同；不强制清除空间Y速度。
Changelog：2026-09-13，DR-217；1001点旧公式逐位/解析斜碰/自旋与交换/续算及固定配置四测通过，静态材料与正式入口尚未完成。

## DR-218 — 台面和库边的物理角色
PocketGeometryAsset.surfaceRoles按tablePatches索引返回clothBed/cushion/leather。TaiNi的角色按精确连通部件判定：当前资产须有唯一接触中央台面点的部件和六段达到库高的独立部件；床沿折面仍属clothBed。不能按材质名、最大部件或任意法向阈值代替该分类；未知结构抛错，缓存只在整套成功后发布。角色尚不等于业务吃库事件/主库索引，需另做接触上报映射。
Changelog：2026-09-13，DR-218；当前模型及顺序/绕向/缺失边界测试和分类图通过，响应及业务接入另验。

## DR-219 — 局部库边业务事件
只在实际cushion角色静态接触后调用nearestCushionIndex映射原有限CAD段/弧索引，不把它当检测器或吸附器。clothBed与Leather不直接作为吃库；Double接触时刻/球/库索引去重状态跨pending保留，只消费已接受前缀。业务法线XZ单位投影兼容旧预测，原三维法线留在LocalStaticContact。统一材料数值不等于不同响应模型的实际回弹率一致，尤其旧Han库边.94须实测对照。
Changelog：2026-09-13，DR-219；四项库索引/真实吃库/台呢落地/续算测试通过，正式入口与静态响应衔接另验。

## DR-220 — 静态材料配置与验收边界
PocketGeometryAsset.contactSurfaces(material:)缓存索引不变的纯值Surface；prototype保持旧值，tablePhysics(clothRestitution:)显式区分台呢阻力、皮革和CAD段/弧系数，台呢竖向恢复不得假称已标定。配置须绑定PendingMixedStep。对比平面与空间台呢阻力时先验证实际支撑时刻，Float中心的纳米间隙仍有解析落地时间；不能把其自由落体时间计为台呢摩擦或为此重写求解器。真实库边响应须独立比较，不能凭常量复用认定一致。
Changelog：2026-09-13，DR-220；材料/默认吃库/响应取证三项与修正物理前提后的台呢一项通过，r2原失败保留；静态响应差异尚未裁定为正式配置。

## DR-221 — 接触见证与远端计算预算
projectedInteriorPoint是面内见证，不能把离面内垂足很近的边缘自动当作面支撑。球距共享半径时，以差平方的因式形式比较近邻，避免相加后舍入吞掉实际距离差；位置修正改变接触特征时须重建投影集合，不能继续把已分离见证作为等式。保留真实折角多面支撑。混合入口无局部owner时沿用平面adaptiveEvolveCap，接管靠区域穿越截断；不得让整桌平面运动无条件支付2.5ms局部步长预算。
Changelog：2026-09-13，DR-221；8项实际配置/预算/续算/再入/折角回归通过。仅显式入口，正式预测规则与页面接入另验。

## DR-222 — 混合模拟的搜索早停
simulateMixedWithLocalPockets的earlyStopBallNames/stopAfterContactBetween缺省nil。指定碰撞早停只检查本次接受的新事件，完整提交同刻组和记帧后停止；未接受预测/历史事件不能触发，之后可精确续算。复用canEarlyStop的平面行程证明前须排除空间owner、pending、空中球和还未接管的袋口球；stationary标签不能证明袋口仍有支撑。保守不早停不改变物理结果。
Changelog：2026-09-13，DR-222；4个不同测试覆盖整程碰后对照/续算、空间与袋口失撑、同刻独立事件和完整三球组。正式调用切换及反解端到端预算另验。

## DR-223 — 模拟终止原因
simulate与simulateMixedWithLocalPockets返回Termination：settled仅停稳；timeLimit/eventLimit表示截断；contactResolved/interestResolved只证明请求的搜索目标已满足，不代表全桌静止。混合迭代预算/数值失败保持throws。ShotPrediction.termination默认nil（尚未模拟），经过simulateFree和runShot/buildPrediction传播，不得用feasible几何字段冒充执行失败状态。消费者切换必须显式决定截断或失败如何处理，记录字段本身不等于页面处理完成。
Changelog：2026-09-13，DR-223；新增停止原因与预测传递；真实simulateFree/引擎状态和续算测试通过，正式混合入口切换另验。

## DR-224 — 完整桌面与搜索结果的消费边界
ShotPrediction.hasFinalTableState只接受settled，hasResolvedSearchState还接受interestResolved；contactResolved仅碰撞评分满足，不能当停点或全桌终态。PositionPlayViewModel通过applySolvedShot写入并验证，拒绝时清掉原solvedShot、辅助节点和出杆资格；恢复测试须先安装非空有效解。PositionPlaySolver落点判据同时保留末速和完成状态。SequenceVideoExporter.validateCompletedSimulation在共同运动帧入口拒绝未完成可行预测，不能静默跳after伪装正常播放。
Changelog：2026-09-13，DR-224；消费者/真实落区测试通过，页面截图、完整导出和其他消费者另验。

## DR-225 — 模式随请求与失败传播
SimulationModel必须随ShotInput或simulateFree参数传入simulatePrediction，不能用可变全局开关让搜索和展示采用不同模式。局部模式显式选择静态材料、使用标准球球材料和软袋捕获；maxResolvedEvents是业务事件数量，maxLocalSteps是内部推进保护，不能把旧500事件直接当2.5ms步数。完整同刻组后检查预算。错误返回.failed诊断，禁止隐式回退旧落袋判据。缺省planarReference只是尚未完成全面切换的当前状态，不是v63最终交付；全调用验收后再切。
Changelog：2026-09-13，DR-225；真实自由/袋口预测局部记录与预算失败传播3测通过，默认切换和全场景预算另验。

## DR-226 — 固定几何准备缓存
PocketGeometryAsset.localSimulation按静态材料与球球材料键共享只读Surface/BVH/物理常量；captureBoundaries按当前不可变资产共享六袋边界。球状态/运动段/待提交事件不得进入该缓存。材料校验先于缓存键使用，缓存只在完整构建成功后发布，独立锁避免同一准备并发重建。若以后加入动态物理尺寸/配置，必须使缓存失效或纳入键；不能复用错误资产。SimulationModel也不是2D/3D显示开关，同一杆的物理不应随显示模式改变。
Changelog：2026-09-13，DR-226；简单短预测模拟器热耗时553.059→.16175ms，实际角/中捕获与续算回归通过。冷加载/复杂全杆/真机成本另验。

## DR-227 — 支撑证明与整杆结束
planarSupport复用原planarReturn的实际台面支撑证明，但不要求离开局部区域；planarReturn仍要求区域退出。所有local owner严格v=0/omega=0且有台面支撑、其他球已静止且没有待接管球、无pending时，允许整杆settled并记stationary帧，owner不释放。不能把owner非空当作必然还在运动，也不能只按stationary标签忽略袋口失撑或空中重力。
Changelog：2026-09-13，DR-227；两项实际失败红例、完整停稳/静止支撑/失撑保护/再入四测验证，默认切换与全面消费者验收仍待完成。

## DR-228 — Bank/Kick结果检查位置
BankShotViewModel/DiamondSystemViewModel.acceptFreePrediction须在runCueStroke前调用，回放入口再次检查；失败不能调用settleFreeShot把partial终位写回。失败恢复before并提示，成功清提示。解目录、微调展示、运杆与播放都要约束完整桌面结果，保留目录/草稿分层。图谱等只消费事件前缀的功能须验证自己的终点，不应机械要求整桌停稳。
Changelog：2026-09-13，DR-228；两页拒绝/恢复及真实Bank/Kick微调目录3测通过；视觉提示与其余消费者另验。


## DR-229 — 开球结果与模型
BreakSimulator.breakShot通过simulationModel参数进入simulatePrediction；BreakResult.termination为权威停止原因，settled只接受真正停稳，不能用低XZ末速代替。BreakFlowRunner在运杆前验证；失败保留用户开球意图、恢复racked并禁止交付，不重新随机摆架。成功完成后才做原静止重叠整理。
Changelog：2026-09-13，DR-229；4项拒绝/回归与1项实际9球局部开球通过；该局无进袋，不能代替捕获验收，默认切换与手机预算待验。


## DR-230 — 图谱事件片段完整性
SeparationAngleAtlasGeometry.hasCompleteSlice接受全桌settled或已记录碰后首库；CushionEnglishAtlasGeometry还须到二库或0.40m库后弧。无终止原因不能证明前缀完整。未完成时不得把路径末端当停点；VM逐档保留完整结果并提示，不因后续整桌截断丢掉已完成前缀。
Changelog：2026-09-13，DR-230；14项图谱切片/真实截断/原教学规则测试通过，页面视觉及默认局部模式切换待验。


## DR-231 — 验证击球与答案分离
AimPointSceneQuizViewModel.acceptVerificationPrediction在改变striking状态前拒绝未完成结果，取消自动击球任务并保留showingResult/答案。retryVerification只重复strike，不能重复submit以免重复计分或保存；nextQuestion清验证错误。验证失败不能直接自动跳题。
Changelog：2026-09-13，DR-231；保留答案/恢复与原理想线规则2测通过，系统错误弹窗实际UI待验。


## DR-232 — 规划页展示和出杆检查
Silu/PlanThree/Snooker的canStrike要求完整桌面预测；presentDisplayedSolution和replayLastShot在场景变化前调用acceptCompletePrediction。未知或部分结果清轨迹/杆与瞄准方向并提示，不用feasible表示模拟完成。保留解目录与微调草稿分层，回归实际求解与循环恢复。
Changelog：2026-09-13，DR-232；三页拒绝与真实微调5测通过，提示UI及局部默认切换待验。


## DR-233 — 反射追迹前缀
EngineCushionTracer.launch返回termination，模式从shoot传到每次搜索和重建；仅settled记录自然末点，截断保留已接受的库间片段，不能把partial末帧补成停点。pocket/jaw事件仍按原库序规则结束，追迹折线是求解辅助而非空间回放。
Changelog：2026-09-13，DR-233；11项旧真实模式/力度/截断与显式局部基础测试通过，局部多库反解和默认切换待验。


## DR-234 — 当前默认模式（覆盖早期默认未切换说明）
SimulationModel.appDefault为不可变局部模式tablePhysics(clothRestitution:0.3)，ShotInput/自由预测/开球/反射追迹共用；显示模式不能改变物理。planarReference仅显式旧基准。该默认已进入当前源码与页面测试，尚未通过全页面/真实手机预算；不能将e=.3称作实物标定或将单页流程称作完整验收。
Changelog：2026-09-13，DR-234；局部完整反解2测、默认捕获1测及实际3D页面1测通过，全面验收继续。


## DR-235 — 局部阻力矩平衡候选
局部静态接触的滚动/旋转力矩由当前接触压力约束，与切向力产生的角加速度共同求解；不能只根据起始omega确定阻力，否则静止斜面会产生步长相关爬行。组内所有表面共用最终角运动，各自保持滚动/旋转容量；嵌套投影不收敛须抛出surface-moment失败。当前候选仅4项单平面测试通过，真实袋口/多球/性能待验；原型临界投影失败不能被这4项替代。
Changelog：2026-09-13，DR-235；局部静止舍入及阻力矩平衡候选，验收未完成。

DR-235候选补充（2026-09-13）：平衡袋沿结束需已接受区间的静止起止运动及零加速度证据；瞬间零速不足。投影/力严格迭代停滞后，须重核最终空间约束预算，力的相对变化先乘加速度标度和时间平方再比较，禁止直接比较不同单位残差。该补充正在contact-budget-r2验收，非完成声明。


### DR-236 — 序列导出结束时刻（2026-09-13）
SequenceVideoExporter.motionEndTime以预测全桌duration、空间collectionPresentationEnd及确实存在的旧捕获动画预算计算运动结束；跟杆时长另取max。禁止给已有空间尾段的球重复追加旧pocketSettleDuration。混合轨迹仍保留旧捕获预算。此条为DR-236增量更新；视频验收状态见任务记录。


### DR-237 — 序列杆末收尾（2026-09-13）
DrillSceneController与PositionPlayViewModel的序列回放应等全桌最大action.duration，再兑现杆边界暂停或下一杆；空间捕获action已含完整尾段，不再追加旧固定sleep。旧帧捕获兼容预算仍保留。等待挂入母球action组，硬停节点动作同时停止等待；完成回调仍需检查播放状态。此条为DR-237增量更新。


### DR-238 — 手机竖版3D教学取景（2026-09-13）
Options.teachingVideo3D使用60°俯角，提高窄屏中的台面与路线可读性；通用Perspective3DConfig默认30°不变。完整桌体仍由solvePerspectiveCamera按外框与实测桌腿底自动入框，不能以直接缩短距离绕过入框约束。此条为DR-238增量更新，静帧对拍/几何/编码证据须区分。


### DR-239 — 观看模式不得覆盖业务失败（2026-09-13）
BreakFlowRunner.simulationFailure保留最近未完成开球的Termination，成功或重摆清空。FreePlayView的3D操作说明只覆盖无失败的racked初始提示，模拟失败仍显示runner.statusText。相机模式只影响观看，不得隐藏业务失败原因。此条为DR-239增量更新。

### DR-241 — 逐球动作完成与实时结算（2026-09-13）
实时击球、上一杆回放与序列播放均聚合实际逐球动作时长；空间捕获action已包含下落/停留/淡出，不再追加旧尾段等待。旧记录兼容须按捕获记录类型判断。等待绑定SceneKit动作以随场景停止取消；UI退出/快速重启仍须独立验证，不以isPlaying检查代替代际取消证明。
Changelog：2026-09-13 / DR-241 / 实时及上一杆回放收尾契约。

### DR-244 — 导出消费端证据（2026-09-13）
DEBUG导出可通过Options.motionFrameObserver观测编码前实际worldPosition/opacity值快照。诊断入口默认nil，不传活节点、不改变输出。测试以独立预测时间查询比对实际消费者，帧数量和捕获最终不可见必须实际观测；时长/编码成功本身不足以证明坐标一致。
Changelog：2026-09-13 / DR-244 / 导出实际节点值观测。

DR-244观测补充：motionFrameObserver值快照还含step UUID与实际可见boardKey集合，用于多杆身份及离场检查；预测别名object会跨杆复用，不能用它判断同一实体是否复活。

### DR-245 — 已播放预测的杆末球形（2026-09-13）
SequenceVideoExporter运动后静帧使用本杆预测进袋集合和停点，匹配实时序列消费者；保存after不能覆盖已播放的不同结果。settledFrameObserver仅DEBUG，按boardKey提供实际可见节点世界位置。此修复不解决下一杆按保存before恢复的兼容问题，不应将局部杆末一致称完整多杆一致。
Changelog：2026-09-13 / DR-245 / 视频杆末预测消费，定向验收中。

### DR-268 — 每日清台自由球恢复（2026-09-13，API增量v1）
DailyClearancePlayingHost新增restoreDailyClearanceCueBall；实际host仅在母球不在桌时复用placeFromPalette安全空位。controller使用本杆事实与规则决定是否补回，并在补回之后读取并保存board。不得由下一杆预测cuePocketed触发补球，终局不补球。
