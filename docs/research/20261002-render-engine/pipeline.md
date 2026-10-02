# 渲染管线与 GPU 算法独立研究

日期：2026-10-02。首轮独立研究；未读其他角色报告。只读源码与历史文档、联网核验官方资料；未改生产代码，未构建、渲染或启动真机负载。

## 结论

**当前优先推荐保留 SceneKit 场景宿主，把剩余成本按「动态球影、材料着色尾部、页面调度、资源准备」分开验证；定制 Metal 是控制上限最高的后续候选，还不能称为当前最低能耗引擎。** 当前最值得验证的是：在保持台呢原采样与遮挡公式的前提下减少不随片元变化的工作；用只覆盖台呢的 SCNProgram 检查 SceneKit 自动 PBR 尾部是否昂贵；把静态房间探针和 GGX 预积分移出同步进页路径。不要先把原有采样算法原样搬到 Metal，再预设它会省电。

最强的反对意见是：SceneKit 限制了管线、资源绑定和呈现控制，继续局部优化可能错过定制引擎的整体收益。因此后续应有同公式、同资产、同像素、同输入的最小 Metal 对照，而不是无限重写 Swift setter。停止迁移的条件也应明确：如果收益只来自换近似算法或降低质量，或者整页净收益低于噪声，保留现有宿主。

## 基线及证据标记

- **事实 F**：直接读到的源码、文档或原作者资料。
- **推断 I**：依据上述事实得出的机制判断；没有当前设备性能测量。
- **假设 H**：必须通过实验验证的优化机会。

冻结基线为 `baseline.json` 中 2026-10-02 08:10:51 +08:00 快照，HEAD `b69aa749b12a4e322da1bbca1a78536349531c47`，包含脏工作区房间/相机改动。下文 `S/` 表示本研究目录的 `baseline-source/QiuJi/Core/Scene/`，行号属于快照；不是仅指 HEAD。媒体用 `baseline-source/QiuJi/Core/Media/`。只有页面消费者清单使用 2026-10-02 本轮后续工作区只读检索，明确单列，避免伪装为冻结源码。

## 1. 当前生产管线

### 1.1 场景准备及两种默认

**F1**：`S/AngleTrainingScene.swift:14–36`：共享场景默认 `MobileReferenceLighting.specializedProfile`；release 为 A/reference。每日清台在 setup 前显式 `.reflection`（R）、曝光 -0.1、daily camera，并开启相机相同输入/输出跳写。merge support、factor BRDF 只在 DEBUG 参数明确打开，普通默认均关闭。

**F2**：`S/AngleTrainingScene.swift:208–258`：setupTable → 相机/基础灯光 → mobile lighting → 台呢对齐 → 袋内静态 AO → `MobileContactOcclusion` → reference shading → 装房间和探针 → 台框/台呢偏好。mobile 默认开启，enhanced 显式路径和离线 opt-out 是另外的契约。`S/MobileTableRendering.swift:12–18` release 开启；DEBUG 可 legacy opt-out。

**F3**：`S/MobileReferenceLighting.swift:286–329`：把已有光源 intensity 归零，再添加两矩形面光；球面用 `.constant` 自定义 shader；台呢用 `.physicallyBased` 的 surface modifier 计算后写 emission，同时将 diffuse 归零、metalness 置 1。`S/MobileReferenceLighting.swift:900–906` 是台呢输出映射。所以台呢不能等同「纯自写 Metal shader」：原生后续光照/相机链仍存在，实际被编译消除多少需要捕获 shader/encoder。

**I1**：球迹已经使用领域定制着色算法，SceneKit 主要还承担节点、动画、投影/拾取、材质绑定、生成程序、绘制和相机后处理。选择另一个 PBR 框架，不会自动复现现有台呢、灯板轮廓、绿色反射、落袋下方变暗和皮革材质。

### 1.2 每帧调度及相机

**F4**：`S/AngleSceneView.swift:86–100` 建 SCNView，4×MSAA，请求用户帧率，初始 isPlaying=true。`:514–519` 另有主线程 CADisplayLink；`:539–589` 更新活动状态、dt、camera、labels 和诊断。SceneKit 自己的渲染循环不是这个回调；这段未直接 `render()`。

**F5**：`:383–435` 判定活动包含显式内容状态、手势、过渡、阻尼、0.5s唤醒窗口及节点 SCNAction/animation。idle 暂停主 CADisplayLink，isPlaying=false，rendersContinuously=false；SceneKit 内容变化产生的 didRender 通过 `FrameDelegate` 回主线程重新核对状态（`:1152–1165`）。用户帧率、热状态和低电量会改变调度上限；公平比较必须记录实际值。

**F6**：`:74–75` `contentIsAnimating=nil`；`:387` `(contentIsAnimating ?? true)`；旧消费者不知道活动状态时持续运行。`:570–572` 静止早退也要求该参数非 nil。**不能把共享组件已有停绘机制写成全 App 已停绘。**

后续只读工作区检索 `rg 'AngleSceneView\(' QiuJi --glob '*.swift'` 共 **16 个入口**，只有下列两个显式传入 activity：

| 消费者 | 证据 | 行为范围 |
|---|---|---|
| FreePlayView（含每日清台） | `QiuJi/Features/PositionPlay/Views/FreePlayView.swift:596–597` | isPlaying、breakRunner.isBusy、每日瞄准轮拖动 |
| ShotSimulationView | `QiuJi/Features/AngleTraining/Views/ShotSimulationView.swift:215` | isPlaying |

其余 14 个省略：BatchAuthoringView、BatchBallExtractionView、SnookerTacticsView、DrillSceneView、PlanThreeView、SiluTrainerView、PositionPlayComposerView、BallExtractionView、AimPointSceneTrainingView、CushionEnglishAtlasView、SolverStageChrome、SeparationAngleAtlasView、AngleDynamicView、SceneAimingView。入口示例：`S/DrillSceneView.swift:701–708`（此条也在冻结快照），工作区 `PlanThreeView.swift:250–280`、`SolverStageChrome.swift:469–485`。静态阅读确定 nil/活动逻辑，但不证明其整个页面实际 present 数量，需消费者页面逐一采样。

**F7**：每日相机跳写仍核对完整输入以及实际 camera transform/FOV/projection/身份，`S/CameraRig.swift:1509–1542`；并未停止阻尼数学或盲缓存 presentation。场景旗标见 `S/AngleTrainingScene.swift:20–36`。

**I2**：非每日页面补齐正确 activity 契约有明确节能机制，但必须覆盖播放、运杆、选球 pulse、袋高亮、尺寸变化与外部节点变化；不能简单给所有调用者传 false。已有每日 idle 不可重新计作新收益。

### 1.3 球影参数提交

**F8**：`S/MobileTableRendering.swift:152–228`：球列表按 key 排序，固定索引；每四球作为一个 float4x4，所有组作为一个具名 struct argument。每个球传 `(x,z,max(R,h),opacityWeight)`，接触 AO 在台呢 surface 中逐球乘积，另采样一张床面 rail AO 图。台呢纤维利用已有 roughness 信号。

**F9**：`:238–265` 在 SceneKit didApplyAnimations 后读取 presentation.worldPosition / opacity；相同 SIMD 不提交，任意变化构造不可变 Data，对每个台呢材质做一次 KVC setValue。FrameDelegate 通过锁保护指向 `MobileContactOcclusion` 的引用（`S/AngleSceneView.swift:1124–1150`）；真正的球参数更新在渲染回调，不在主 DisplayLink。不能异步挪到下一帧或嵌套 transaction：源码明确记录一帧滞后的失败约束（`:243–244`）。

**I3**：动态读取成本与可见球/材质数相关，但只有最多一组小 struct 数据。KVC 减少不等于已证明全帧收益；旧四 setter → 一 setter 已实施，不能重复统计。`var values=previous` 是否真的堆复制需分配工具核实。

### 1.4 台呢直接球影

**F10**：`S/MobileReferenceLighting.swift:375–459` 生成保守 support 与 uint 候选掩码，1…32 球用 ctz 遍历候选，而不是所有球每 sample 无条件测试。supportPossible 和 mask 的支持域检查目前有重复；merge 只 DEBUG。每个候选用射线到球距离及 sample footprint smoothstep，球 opacity 衰减参与可见度累乘（`:385–396`）。低于床面的接收面保留更宽候选域，不能只按平面球影圆筛选。

**F11**：`:869–906` 近影每面光 **8×4** 点，远影 **2×2**；两面光来自 rig（`:29–40`），因此近影总计 **64 光照点**，每点包含候选球遮挡和 GGX D/G/F。最终采样直接漫反射按解析矩形 irradiance 校准。台呢 roughness/normal 来自材质输入；高频纤维和视角相关项仍保留。

**I4**：动态算法的规模项近似为 `可见台呢片元 × 两面光采样点 × 各片元候选球数`，加所有球 support/AO。实际成本还受分支、寄存器、编译器、纹理、片元覆盖影响，不能用乘法估计毫秒。但这是应用自定算法，搬到 Metal/RealityKit/Filament 后同公式仍须执行。

**F12**：S/RS 并非精确同公式加速。`:462–528` 每球八条 Gauss–Legendre strip 积分；`:532–561` 分离可见度与 BRDF，用每面光2×2 specular点。多球遮挡仍按各球遮挡因子乘积；阴影可见度与 BRDF 相乘不等于参考的逐样本积分。它是另一近似，应以画质与性能双验收，不能因名字 analytic 或采样减少就宣布成功。

### 1.5 球面 A 与 R

| 项目 | A/reference | R（当前每日清台） |
|---|---|---|
| 漫反射 | 两面光解析积分 + 房间 SH9 + 台呢 bounce | 保留 |
| glossy | 每片元64次GGX重要性采样；每次含房间/台呢/面光求值 | 1次BRDF LUT + 1次预滤房间采样；台呢边界CDF、两面光CDF等解析项 |
| 动态位置和法线 | 随球/相机实际变化 | 保留，含clothWeight、局部台呢反射mask |
| 资源准备 | 房间原探针、mips、SH | 加预滤环境与BRDF LUT |

代码：`S/MobileReferenceLighting.swift:817–866`（A），`:182–247`（R），`S/RoomReflectionProbe.swift:234–259`（安装/失败恢复）。编号球 roughness 0.05、其他球0.34（`:256–269`），不能按一个球材质概括所有角度/球型。

**F13**：R预滤不是完美参考等价：环境 split-sum 假设 n=v，台呢和灯板用可分离 GGX slope CDF。源码明确说不是 exact LTC 或 ray tracing（`:212–214`）。Karis原讲义同样说明预滤 n=v 会损失拉伸高光，见来源 E4。低机位光斑、球边缘、不同粗糙度都必须进入画质比较。

**I5**：当前每日已消除64次球面反射循环，不能再拿旧消融2.088ms当预期额外收益。共享其他交互页面仍 A，是否推广 R 是单独画质决策，而非全局默认已升级。

**F14**：R并未移除所有材质采样。球杆/皮革 satin 仍每面光4×2 GGX点，两灯总16点；木面coat每灯2×2，两灯总8点（`S/MobileReferenceLighting.swift:696–741`）。台呢依旧 F11 的64近影点。不要把「R预积分」等同「全景只有两次纹理查表」。

### 1.6 Metal compute 和资产生命周期

**F15**：`S/PrefilteredReflection.swift:19–47` 静态 Programs 以 device registryID 缓存 compute pipelines、queue 和 LUT；首次 `makeLibrary(source:)`、两PSO、128² rg16Float LUT，每texel256样本，同步 waitUntilCompleted。`:52–82` 每probe生成512×256 rgba16Float完整mips，每层256样本（0粗糙度直接拷贝），再同步 wait。`:105–140` 是compute代码。这不是每帧 compute。

**F16**：`S/RoomReflectionProbe.swift:35–52` 每probe锁保护、尝试一次、失败输出一次日志并回退reference；`:286–303` 按RoomStyle缓存、显式reset；`:340–374` 首次房间用SCNRenderer六方向快照，另拍隐藏桌体的向下floor快照，再CPU转equirect与SH；`:182–204` 上传半精度图并同步生成mips。缓存键目前只有风格，未来房间尺寸/灯光/资产动态变化必须扩键或显式失效。

**I6**：场景setup先安装neutral（球材质初建），装房间后换实际probe。R可能在冷进页为neutral和room各做一次预滤；cache后不会每帧重做。现状明确同步，但尚未量化其主线程占用或首次page峰值，不能说「冷启动热源已实证」。房间缓存miss可有并发重复bake：锁只包查/写，bake在锁外；neutral无同级锁。研究列为生命周期风险，不推定已发生崩溃。

**F17**：`S/TableModelLoader.swift:31–49,86–107` 已有进程级USDZ解析cache/后台预热、clone及geometry/material副本，访问串行化；`:118–119` 去物理/相机/灯，呈现模型本身不承担引擎物理。不能再建议「加一次USDZ cache」作为尚未实施优化，也不能以引擎迁移名义改训练物理。

**F18**：`baseline-source/QiuJi/Core/Media/SequenceVideoExporter.swift:1077–1094` 使用SCNRenderer及contactOcclusion delegate按clock snapshot；因此同帧球影参数、离屏时间推进、色彩与抗锯齿必须在替换后保持。离屏路径按options可显式mobile，不可一概当 A 或每日 R。

## 2. 已有性能证据能说明什么

历史文档均在本轮实际读取；这里没有用memory作当前实现证据。

- **2026-09-21，iPhone16Pro/A18Pro，固定15球、原生1206×2622、MSAA4、独立渲染宿主**：报告3D前后基准漂移0.015%–0.346%，直接球影移除少3.710ms，球面64循环移除少2.088ms。`tasks/DAILY-CLEARANCE-BOTTLENECK-RANKING-20260921.md:67–85`。仅说明旧A热点；台呢整体6.706ms包含原生光照，嵌套消融不可相加；不是当前R完整页GPU/功耗或长期热表现。
- **2026-09-21后续**：`tasks/DAILY-CLEARANCE-RENDER-FOLLOWUP-20260921.md:7,30`：合并uniform已采用；去重材质无收益（实际一个引用）；旧阴影关闭有通道差无稳定收益；support合并iOS17一姿态不等价，已撤回。不能重新包装为已证路线。
- **2026-09-27完整页trace**：`tasks/DAILY-CLEARANCE-3D-20260927.md:108–127`：712个精确encoder/CB/present request，错误swap关联有GPU结束晚于display的反例，698帧/比例已撤回；A1/B/A2对照无合格B窗口且热停止未跑A2。真实present、25%收益、10分钟改善仍未通过。现有R+camera候选已在源码，不代表验收闭合。
- **10-01方案**：冻结 `baseline-source/tasks/RENDER-CODE-OPTIMIZATION-PLAN-20261001.md` 只允许保持公式/采样/画质/物理的代码优化，尚未实施。这一独立研究可以提出更广候选，但不能把算法更换混作该方案的等价实施。

## 3. 保画质的算法路线与淘汰机制

「位等价」与「用户认可同画质」分两条验收。查表/重采样、half、LTC、S替代都不能预设位等价。

| 优先级 | 候选及机制 | 画质边界、最强反例 | 需要宿主控制 |
|---|---|---|---|
| P0 | 完整消费者activity契约：静止时无需持续DisplayLink/SceneKit动画时钟 | false错误会冻结pulse/运杆、漏唤醒；不能减少真正活动期帧数 | SceneKit可做；无需新引擎 |
| P1 | 原球影公式不变：球support参数、固定面光采样点/相关不变量移出片元重复工作；少重复世界变换、缩短临时变量活跃期 | CPU与GPU浮点顺序可能不同；support域必须保守；编译器可能已经折叠，额外uniform反而慢 | shaderModifiers可试；profile先量化 |
| P1 | 单台呢SCNProgram保持原公式，显式输出线性颜色，检查自动PBR尾部/无效灯光处理成本 | tone/exposure/MSAA/透明度/其他接收面可能不匹配；旧去PBR消融是删效果不能替代 | SCNProgram已有完整vertex/fragment控制与buffer绑定；iOS17可用 |
| P1 | 静态房间radiance、mips、SH及GGX LUT/预滤离线生成或后台预热；版本化资源cache | 缓存仅RoomStyle不足；房间动态尺寸/桌框/灯/色彩改变会失效；离线图必须同算法校验 | 现有Metal compute/资产流水线即可，不必迁移 |
| P2 | 分区候选表/ tile mask，以保守域只列真实可能挡光的球，保留原64点与遮挡累计顺序 | 最多16球、现有mask已做；候选表建立/读取可能比球测试更贵，床面下/抬球支持域最危险 | shaderModifiers可采纹理候选；定制Metal便于compute/tile资源调度 |
| P2 | 球位置相关的shadow/irradiance场只在球动时更新；camera变化复用漫反射遮挡，再求view-dependent specular | 重采样/分辨率是近似；台呢法线、库顶非平面、袋内和落袋不能用同平面贴图；需动态近景验收 | SceneKit外部compute纹理可试；纯Metal便于pass和同步 |
| P3 | LTC替代未遮挡面积光BRDF；球遮挡另处理。避免把光照积分与每球逐sample相乘 | LTC原论文解决无任意动态遮挡的BRDF面积积分；没有自动解决多球遮挡；低roughness、擦边、半影仍可能改变 | 任意MSL/LUT能力即可；不要求特定引擎 |
| 不直接采用 | S/RS、降光照采样、half改全管线、SSR、实时ray tracing | S已有模型变化/条带风险；低样本运动闪烁；half几何差可影响影边；SSR漏屏外球/袋；ray tracing没有本场景节能证据 | 独立质量预算原型，不能默认成为生产 |

P1「移出片元」仅指真不变量。粗糙度纹理、材质法线、球height/opacity、相机等不得当常量；不可缓存跨帧presentation。不能仅凭源码出现sqrt/pow就重复重写，必须检查实际编译shader与限速项。

## 4. 换引擎会消失、保留或新增的成本

| 类型 | 同公式迁移后的判断 |
|---|---|
| 台呢8×4/2×2、候选球可见度、AO、材质纹理与R解析项 | **保留**；这是核心算术与读纹理，任何引擎都须计算 |
| 像素覆盖、4×MSAA、透明袋网、房间/球/球杆几何 | **保留**；需要同画质同像素预算，降低它们是质量路线 |
| Swift KVC、SCNNode presentation、SceneKit材质分类/生成程序/动画调度 | **可替换**；Metal可自己用帧快照、显式buffer和实例绘制，但净收益未测 |
| 原生PBR不必要尾部、隐藏阴影pass | **可能移除**；需frame capture确认确实存在且非画质必需，SCNProgram也可能解决 |
| USDZ解析、材质翻译、roomprobe/LUT准备 | **不会自动消失**；可离线/预热/缓存，更换引擎可能需要新导入和缓存 |
| SwiftUI、业务预测、输入响应、音频、系统合成 | **不会自动消失**；渲染引擎不是全App能耗的所有者 |
| 拾取、动画曲线/取消、相机、色彩映射、离屏导出、GPU在途资源安全 | Metal方案需要**自己新增并维护**，迁移完整性比一个漂亮球demo严格 |

**I7**：Metal的优势是能明确选择render passes、资源生命周期、buffer/instancing/管线特化和present；不是对数学积分的豁免。最窄可判别路径：SceneKit modifier → SceneKit单台呢SCNProgram → 同公式Metal，并将算法改动作为独立轴。若Metal与优化SceneKit同公式接近、只有新算法显著受益，则结论是算法选择有效，不能归因引擎更换。

## 5. 官方/原作者事实核验

以下均于 **2026-10-02**联网读取正文，未只依赖搜索摘要。Apple JS页面正文通过官方 `.md`读取；文档availability显示经典SceneKit API iOS8起、iOS26 deprecated，并非iOS26后不可运行。本轮不依赖Metal4、iOS18/26新增功能。

| ID | 一手来源及范围 | 直接支持的事实 |
|---|---|---|
| E1 | [Apple SCNShadable](https://developer.apple.com/documentation/scenekit/scnshadable)；[官方Markdown](https://developer.apple.com/documentation/scenekit/scnshadable.md)，iOS8起 | modifier保留SceneKit原管线；SCNProgram完整替换对象shader；KVC/KVO自定义uniform及材质texture绑定。与F3/F9对应 |
| E2 | [Apple SCNProgram buffer binding](https://developer.apple.com/documentation/scenekit/scnprogram/handlebinding(ofbuffernamed:frequency:handler:))；[官方Markdown](https://developer.apple.com/documentation/scenekit/scnprogram/handlebinding(ofbuffernamed:frequency:handler:).md)，**精确方法 iOS9 起，按本机SDK核验修正，见交叉回应** | 自定义Metal buffer可按frame/对象等频率由handler写入；它不是现有modifier KVC原样的零改动替换 |
| E3 | [Apple rendersContinuously](https://developer.apple.com/documentation/scenekit/scnview/renderscontinuously)，[官方Markdown](https://developer.apple.com/documentation/scenekit/scnview/renderscontinuously.md)，iOS8起 | false时内容变化/动画触发重绘；支持idle节能机制，不证明所有调用方达成idle |
| E4 | [Brian Karis，Real Shading in Unreal Engine 4，SIGGRAPH 2013原讲义](https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_slides.pdf)，PDF第10–12页 | split-sum两部分预计算，environment mip与BRDF LUT；n=v近似会损失stretched highlights。算法不绑定UE引擎，也不等于项目R的所有局部项精确 |
| E5 | [Heitz/Dupuy/Hill/Neubelt，LTC原作者研究页，SIGGRAPH 2016](https://eheitzresearch.wordpress.com/415-2/) | LTC拟合BRDF、将polygon积分变换为解析cosine积分；作者明确近似非完美。**不能由此推定球遮挡已解决** |
| E6 | [Apple Metal Pipelines best practices](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/Pipelines.html)，2017归档 | 尽早异步准备已知compute/render pipelines，避免首次关键路径同步编译；这是经典Metal路线 |
| E7 | [Apple Triple Buffering](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/TripleBuffering.html)，2017归档 | 避免每帧分配和CPU/GPU同资源冲突；使用有限在途buffer。用于Metal候选设计，不能把现有不可变Data随意换成同址可覆写数据 |

Karis全文notes源本轮web工具无法解析大PDF、系统无pdftotext；实际核验采用可读的原讲义slides。没有安装软件或假装已阅读失败文件。

## 6. 可证伪的最小实验和停止条件

本轮只设计，**以下均未运行**。先保证输入是固定已记录回放，不重新随机开球或反复求解；冻结设备/OS/构建优化、素材/光位/曝光、像素、MSAA、请求和实际活动fps。低机位、满桌、球抬升/落袋、重叠阴影、平面/库面和相机动但球静止分别取样。

1. **建立当前R原景计费账单**：短完整页trace，精确关联CPU阶段、SceneKit编码、GPU执行、present；shader/attachment/pass capture核对台呢原生尾部及shadowpass、drawcount/overdraw。输出每阶段分布/噪声、受限项。若当期热点已不是台呢，停止按旧消融优先级实施。
2. **静止契约对照**：一个nil消费者改成正确activity候选，保持所有动画；数十秒稳定区计主回调、SCNRender、CPU、GPU、真正present，测首次唤醒响应。若仍连续重绘定位写入来源；若丢动画/唤醒立即淘汰。零回调不能单独当零present证据。
3. **单台呢SCNProgram对照**：保留其全部公式/采样/纹理/输出空间，其他节点仍SceneKit，A→B→A；先同帧像素/运动，再原生GPU/CPU。若只因为漏了tone、PBR输出或阴影效果而更快，淘汰；如果确有净收益，说明不用整引擎迁移也能获得该部分控制收益。
4. **只改算法的不变量路线**：先一处support预计算或BRDF复用，不同时更换可见度/查表。提交参数保持同帧、不漏低表面/抬球；iOS17图像失败历史要作为专门反例。若编译器已消去且GPU无稳定净收益，撤回，禁止无限扩大重构。
5. **资源准备路线**：冷启动/首次进台/首次切风格、重复进页分别记CPU、GPU、峰值内存、耗时。验证neutral重复预滤是否真实出现；预生成资源与原算法做数值/图像核对和失效测试。只改善冷启动时，不宣称持续GPU/温升同幅改善。
6. **同公式Metal原型**：保持原台呢与R球shader，复用数值帧快照，至少桌体/球/袋网、相机、4×MSAA及实际present。与R基线、优化SceneKit候选三方比较；逐项核对哪些pass/绑定消失。若优势不超过配对噪声、响应退化、欠缺袋内/透明/低机位功能，停止扩大迁移。算法变化另开方案单独比较。
7. **最后才连续热/能耗对照**：短配对确认有效后，固定10分钟正常节奏/亮度/联网/未充电条件，随机候选顺序、冷却复位。报瓦/焦耳若有可验证工具；没有则只报能耗代理与系统热状态、用户温感。任何明显发热或热降频按协议停止，保留失败。

建议在协议预先固定实用阈值，而不是试完后挑有利窗口：收益必须超过重复基线波动且置信区间不跨零；迁移需要足以偿还功能维护成本的整页收益。具体百分比由主控与评审在当前R噪声测完后冻结，**不要拿旧25%目标或旧A 15.44ms直接当现期测量结论**。画质是否接受由明确画质参照与动态审看决定，自动像素指标不是唯一标准。

## 7. 尚缺证据及首轮立场

尚缺：当前R完整页present闭合、CPU函数栈/分配、编译后shader限速项、实际pass/纹理/带宽计数、冷资源时序、iOS17真机覆盖、持续温升/瓦数，以及候选引擎同质量实装对照。因此不能选出实测能耗最低者。

首轮排序是**SceneKit保留宿主并改进领域算法/生命周期 → 若控制不足，最小SCNProgram/Metal验证 → 用证据决定是否全面Metal**。其他框架的版本/导出/迁移完整性由引擎角色独立评估；本报告不替它宣判。SceneKit长期维护状态是迁移的理由之一，能耗结论仍需本项目真机证据。

## 8. 交叉回应（2026-10-02）

已阅读 `engines.md` 和 `assets.md`，并收到主控与独立评审的具体异议；不修改同伴报告。本节收紧首轮优先级和迁移触发条件，所有候选仍未实测。

### 8.1 API 最低版本纠错

首轮 E2 把 buffer binding 精确方法标成 iOS8，这是不正确的。官方方法 Markdown 的 metadata 显示 8.0，但本轮进一步核实本机SDK `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNShadable.h:290`：`handleBindingOfBufferNamed:frequency:usingBlock:` 明确 `API_AVAILABLE(macos(10.11), ios(9.0))`；`:273,280` Metal vertex/fragmentFunctionName 也为 iOS9。因此 E2 已修正为 **iOS9**，不能用类/协议 metadata 替代方法可用性。它仍覆盖本项目 iOS17，并不改变中间方案可研究的结论。核验日期2026-10-02；未构建验证。

### 8.2 P0 activity 的正确优先级：全 App 与每日不同

**接受主控/评审异议**：14个nil消费者不能解释每日清台在动态瞄准、播放或镜头操作时的发热；FreePlay已显式activity，而且真正活动期本来就需要绘制。它最多解释其他页面静止时仍保持工作，不能当作每日核心优化的首要根因。

| 目标 | 调整后的顺序 | 何种证据会推翻 |
|---|---|---|
| **每日清台动态3D** | 当前R完整页计费账单/真实present → 台呢64近影点与原生尾部 → 同帧提交/相机/回放热点 → 有计数器支持的资产路线。每个候选单独验证 | 若当前R shader不是主要受限项，而tiler/纹理/CPU提交占主，立即改变顺序；不用旧A热点坚持原计划 |
| **每日静止与唤醒** | 确认已接入activity是否实际停止所有绘制、是否有相同camera/material写入复唤醒 → 首帧响应 | 若静止已经零持续提交、唤醒无异常，则停止此分支，不再把已有成果当新优化 |
| **全App其他页面** | activity契约与页面生命周期作为独立高优先级节能覆盖任务，逐页覆盖动画/取消/唤醒 | 若某页面系统已有变化才绘制且无持续负载，收益可能仅CPU回调；不能泛化为相同瓦数下降 |
| **冷进页/切房间** | 资产准备、探针/预积分同步与峰值内存独立测量 | 若峰值来自USDZ/纹理解码而非probe，则先资产；冷改善不算每日活动期持续收益 |

最强反例：每日热是持续片元积分/高像素负载，修完14个非每日入口也不会改善每日播放。另一个反例：低功耗候选只是减少真实播放帧数，使CPU/GPU看似更低；这必须被同帧率/present对照拒绝。

### 8.3 SCNProgram 及 SCNRenderer+MTKView 后，还剩什么值得纯 Metal

**同公式 SCNProgram 未被验证**，只是在现有框架中缩小假设范围的对照。引擎同伴提供的 `SCNRenderer + MTKView` 还可研究显式提交/宿主调度。若这两条路线有效，不能跳过它们径直宣称整引擎重写必要。

纯Metal有条件进入下一阶段的具体残余机制是：

1. **动态提交/场景遍历仍是显著CPU瓶颈**：SCNProgram去尾部、统一宿主后，trace仍显示SCNNode/SCNAction/presentation/渲染遍历开销影响输入响应或供GPU及时取帧；自有值快照+实例化绘制明确减少实际调用和编码。仅一次setter数减少不算证据。
2. **仍有无法关闭的冗余绘制/pass或资源生命周期**：capture确认同一效果存在不必要shadow/lighting/attachment处理或多次准备，现有公开入口不能移除；Metal原型删掉的是重复工作且保持输出。若SCNProgram/technique就能移除，则不属于纯Metal独占理由。
3. **保画质算法需要公开宿主无法实现的资源/阶段配合**：例如帧内compute构建保守tile候选、可控在途buffer、特定动态遮挡纹理与几何pass复用。先证明不能在SceneKit外部compute+输入纹理中合理实现，并用原型量出build/read/sync之后的整帧净收益。不是看到compute一词就认定必须纯Metal。
4. **呈现与离屏功能受到不可接受的框架约束**：精确时间采样、可归属present/无多余submit、格式和销毁必须是已定位问题；SceneKit已有指定时间离屏与Metal宿主能力，不能假定它们完全缺失。纯Metal以自身接管后实测改善为依据，不把更好测量误当更省电。

以上须同时满足：原SceneKit候选已做合理优化但仍未达目标；残余热点归属明确；Metal把该项工作净减少；同质量/同帧率完整页面重复配对收益超过噪声；输入、GPU尾部、资源、离屏和iOS17功能无退化。若只是台呢公式仍昂贵，且新算法在SceneKit也能实现，则只证明算法需要改，不触发全面迁移。

最强推翻当前「SceneKit优先」立场的证据：完整同公式Metal原型在动态满台/低机位/落袋和全页操作中，重复表现出SceneKit中间方案无法消除的可观净减少成本，并满足长期目标；同budget提高画质也可构成产品理由，但须另列评分和用户接受条件。最强推翻「Metal值得全面迁移」的证据：改同公式宿主没有稳定整页收益，收益只在孤立渲染或少效果版本出现。

### 8.4 约50万面扇等价几何与大冷资源，会否撤销自研动机

**会，若资产侧优化足以达到目标，就撤销「为了当前能耗必须自研」的动机和实施优先级。** 保留SceneKit弃用后的退出设计/低耦合帧数据契约即可，不把维护风险变成今天必做迁移的理由。

接受资产同伴的事实：源模型499,298面扇等价三角形、两个桌体合474,148，以及源纹理RGBA容量模型；它们都不是SceneKit实际draw/驻留/带宽测量。最值得补的是当前R下tiler/vertex vs fragment ALU/texture的实际限制和冷峰值。若LOD、只消费需要的材质资源、离线probe在SceneKit中通过全场景目标，完整自研的新增工具链、色彩/阴影/动画/导出维护不划算。

最强反例：几何占源面95%，但GPU主要耗在可见台呢片元的64采样遮挡，桌腿/网袋减面不降低这些片元运算；清理过时PNG可能降包体/解析，却没改实际GPU驻留。所以不依资产大小直接承诺持续发热改善。另一个反例：删掉共面壳体或袋网使加载包围盒/校准、袋内遮挡、回球画面改变，这不是合法同画质收益。

最小可证伪对照是分别测试：①只移动冷资源准备；②只改可见资产LOD/格式且不动shader；③只改shader/宿主而不动资产。每条先验证其声称减少的实际工作，再放进完整每日R页面。A/reference只用于其他默认消费者或算法参考，**每日生产比较从R开始**。如果资产路线单独已达标，停止引擎原型扩张；如果资源准备改善但动态目标仍失败，再按实际动态热点继续。
