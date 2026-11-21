# v69 起始第三人称与视角三键实施记录

2026-11-20。需求见[确认方案](../../问题集合_v69.md)。对照截图分别是动作库详情第 3 杆和试打第 1 杆；视觉对比须用同一杆、同一入口的改前改后画面。倾斜的球库自身不能证明镜头偏航。

[打开同杆改前／改后的四组画面](../../output/camera-v69/review/index.html)。详情第 3 杆的两版截图均在自动播放中，母球位置与架杆阶段用下表的生产控制器读数核对。

## 修改及复核方法

- 每日清台、试打与教学宿主共用一列控件。顶部小眼睛单击进入临时 2D，再点返回；中键进第三人称或复位；底键在有合法杆向时进第一人称。旧布局按当前按钮实际大小校验顺序、移除全局键与旧目标键，保留其他自定义控件。
- 内嵌演示与全屏序列分别在各自的真实控制器中配置相机。先就位本杆母球、杆向和视口，再进入默认第三人称。首次布局尚未完成时保留本次请求的杆姿。换杆、暂停、自由返回序列仍由原序列控制器管理。
- 八个题目练习在安装新题或恢复题目时清除旧相机书签的影响；本页正式 2D/3D 往返沿用内存中的机位。无合法杆向的公开目标通过第三人称键观察对象。
- 详情、训练记录保留卡片的正式维度开关。照片校准、模板摆球等阶段沿用原业务机位。在首屏验收时记录内容视口，比较同杆实际眼点、杆向、高度和投影；点击测试与视觉测试分别登记。

## 测试证据

在 Mac 上以 iOS App 兼容模式运行 126 项，全部通过。覆盖真实序列控制器、八杆独立序列、四杆连续序列、动作详情、布局存储与共享机位；这是控制器证据。iPhone 16 Pro 首轮 122 项通过。原始结果见[本机测试摘要](../../output/camera-v69/mac-summary.json)及[真机首轮摘要](../../output/camera-v69/device-core-summary.json)。用户原图保留在[详情第 3 杆](../../output/camera-v69/user-detail-step3.png)与[试打第 1 杆](../../output/camera-v69/user-tryout-step1.png)。

### 同杆几何复验

在 iPhone 16 Pro 上以生产控制器加载「中袋直线出杆」。竖屏卡片按 386 × 220 pt，横屏试打按 874 × 402 pt 输入 3D 视口。第 1、3 杆部位均为中心球。除独立核对母球、录制杆向和标准眼点，还核对实际击点和母球归一化投影。以下为当次快照，Y 从视口顶部向下计。相机坐标以米计，Y 向上。[四份原始读数](../../output/camera-v69/measure-iphone/manifest.json)。

| 杆次 | 录制杆向的 X、Z | 详情卡母球 X、Y | 横屏母球 X、Y | 详情／试打眼点高度 |
|---|---|---|---|---|
| 第 1 杆 | 0.7134，−0.7007 | 50.0%，67.0% | 50.0%，67.0% | 均为 1.45 m |
| 第 3 杆 | 0.3888，−0.9213 | 50.0%，67.0% | 50.0%，67.0% | 均为 1.45 m |

首轮实现中，横屏第 3 杆的母球一度出现在画面宽度 61.0% 处，详情卡仍为 50.0%。序列重摆后，试打已换到正确杆向，但架杆尚未更新，相机取到了先前球杆的击点。改为两条演示链都传本杆的母球、杆向和由本杆打点计算出的击点。偏塞依实际杆轴构图，表内的 50% 只用于这两杆中心球。

## 逐入口核对

下表记录实现路径与该入口的专项检查；界面实测以文末按用例记录的设备结果为准。未取得本版 UI 结果的入口只能标记为实现已核对。逐页手检可结合[v68 清单](../camera-v68/真机逐页验证清单.md)（容错角条目已同步）。

| 页面或入口 | 阶段 | 本次实现／继承 | 该入口的验收点 | 本轮证据 |
|---|---|---|---|---|
| 每日清台 | 普通杆与开球 | 共享自由球桌 | 开球退镜、停稳时换球及已亮第三人称复位 | [iPhone 模拟器通过](../../output/camera-v69/final/evidence/test-details.json) |
| 分离角与走位 | 选球、选袋及重选 | 正式编排入口传共享策略 | 手选目标／袋分两步对正；滚动可接管 | [iPhone 模拟器通过](../../output/camera-v69/final/evidence/test-details.json) |
| 自定义球形练习 | 从模板开始练习 | 练习启用共享策略 | 保存草稿和返回模板 | [iPhone 模拟器通过](../../output/camera-v69/final/evidence/test-details.json)，模板进入练习 |
| 多球走位 | 自主／规划／追分 | 共享自由球桌 | 换阶段保持球序与球权 | [iPhone 模拟器通过](../../output/camera-v69/final/evidence/test-details.json) |
| 蛇彩练习 | 选择球形并开打 | 共享自由球桌 | 重试后原目标及球序 | [iPhone 模拟器通过](../../output/camera-v69/final/evidence/test-details.json) |
| 走位求解 | 规划、选解与试打 | 共享教学控件 | 切镜保留约束、解集和落位 | [iPad 专项通过](../../output/camera-v69/pad-camera-last-test-details.json)，规划与开球 |
| 扎杆与跳球 | 抬杆、侧看、回放 | 共享击球相机 | 按实际抬杆方向检查杆尾净空 | [iPad 专项通过](../../output/camera-v69/pad-camera-last-test-details.json)，抬杆和临时 2D 移球；窗口结果见下文 |
| 准度练习 | 进题、侧看、存盘重进 | 按当前题目冷入镜 | 题目、杆向、成绩及缩放复位 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 翻袋练习 | 瞄准及测量 | 按当前题目冷入镜 | 横滑跟杆、测量不改杆 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 解球练习 | 瞄准及选库 | 按当前题目冷入镜 | 回到题目杆位及库序 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 防守练习 | 瞄准、结果 | 按当前题目冷入镜 | 结果状态和实际停球局面 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 分离角练习 | 固定杆向 | 按当前题目冷入镜 | 侧看与临时 2D 往返 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 两球走位 | 固定杆向 | 按当前题目冷入镜 | 镜头能侧看、杆向固定 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 三球走位 | 预选下一袋、下一杆 | 按当前题目冷入镜 | 保留预选及两杆衔接 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| K 球练习 | 沿题面杆向 | 按当前题目冷入镜 | 保留第二目标和指定杆法 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 瞄准点练习 | 作答及结果 | 共享三键，区分作答与观察 | 横滑只改允许的草稿 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 翻袋求解 | 选择库边、选解及自由试打 | 教学三键 | 选解读取本解杆向 | [iPad通过](../../output/camera-v69/pad-test-details.json) |
| 颗星解球求解 | 选择库边、选解及自由试打 | 教学三键 | 自由试打可调向，结果只读 | [iPad通过](../../output/camera-v69/pad-test-details.json) |
| 打一走二想三 | 规划、开球及回看 | 教学三键 | 无合法杆向时底键禁用 | [iPad 专项通过](../../output/camera-v69/pad-camera-last-test-details.json)，规划与开球 |
| 角度练习 | 未答及结果 | 教学三键 | 未答时禁用第一人称并保密答案 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 角度与瞄准 | 观察题面 | 教学三键 | 维度往返、只观察 | [iPad 复测通过](../../output/camera-v69/pad-confirm-test-details.json) |
| 进球容错角 | 公开目标和袋口 | 第三人称回目标 | 无杆第一人称禁用，小眼睛临时俯视 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json) |
| 分离角图谱 | 更改参数与观察 | 教学三键 | 保留原反射／分离示意及参数 | [iPad 复测通过](../../output/camera-v69/pad-confirm-test-details.json) |
| 加塞吃库图谱 | 更改参数与观察 | 教学三键 | 保留吃库轨迹和参数 | [iPad 复测通过](../../output/camera-v69/pad-confirm-test-details.json) |
| 动作库详情 | 中袋直线出杆，第 1、3 杆 | 内嵌演示按录制杆向；正式维度开关 | 核同杆标准机位和真实卡片范围 | [iPhone 模拟器通过](../../output/camera-v69/final/evidence/test-details.json) |
| 训练记录 | 记录页内嵌演示 | 复用动作库内嵌演示 | 核维度往返及记录内容 | [iPad通过](../../output/camera-v69/pad-test-details.json) |
| 动作库上手试打（序列） | 进入、换杆、暂停、继续和重摆 | 录制杆向与共享第三人称 | 第 1、3 杆、八杆独立／四杆连续及三键 | [iPhone 模拟器通过](../../output/camera-v69/final/evidence/test-details.json) |
| 动作库上手试打（自由） | 序列转自由、直接进入及返回序列 | 统一相机策略，换题意图重新对正 | 自由手调及返回正确序号、盘面 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json)，序列与自由往返 |
| 自定义模板编辑 | 编辑摆球后进入练习 | 编辑保留摆球机位，进入练习使用共享机位 | 编辑不改原模板，核练习三键 | [iPhone 模拟器通过](../../output/camera-v69/final/evidence/test-details.json)，模板进入练习 |
| 拍照导入 | 校准、确认、去编排或求解 | 校准用正式 2D，后续按目的地接入 | 同一导入球位及合法编辑／求解权限 | [iPhone 模拟器通过](../../output/camera-v69/phone/evidence/test-details.json)，确认至编排；导入至求解单独待验 |
| 普通自由球桌／击球模拟 | 通用宿主与独立调试入口 | 默认使用共享策略 | 有合法杆向进入第三人称 | [独立击球模拟真机 3D 首屏](../../output/camera-v69/review/iphone16/shotSimulation.png)；普通自由击球本机以正式 2D 进入 |

## iPhone 16 Pro 实际安装与画面

已覆盖安装并正常启动 com.xinkuan.qiuji。从设备抓取的正式页面首杆可分别打开[竖屏动作详情](../../output/camera-v69/review/iphone16/drillDetail.png)和[横屏上手试打](../../output/camera-v69/review/iphone16/tryout.png)。截图深链采用 App 自带的深色外观设置，两张均为实际视口。截图经调试深链抵达正式页面，真机的第 3 杆由生产控制器逐杆运行取得几何读数。真机 UI 测试进程在建立 XCTest 连接前退出，错误码 74；这些截图不能证明三键在手机上均经自动点击。

修复跨杆击点后的真机套件首次 144 项通过，另一个连续四杆用例在 XCTest 的异步异常观察器中退出。单独重跑及随后整批重跑均通过，真机最终为 **145/145**。见[最终整批结果](../../output/camera-v69/device-acceptance-summary.json)。[整批记录](../../output/camera-v69/device-release-summary.json)与[该用例重跑记录](../../output/camera-v69/device-sequence-recheck-summary.json)。翻袋练习另用同一存盘验证，页内从第一人称切正式 2D 再回 3D 保留第一人称，重新打开同一题恢复当前杆向的默认第三人称。

## 正式界面已执行的用例

iPhone 17 Pro 模拟器，iOS 26.2，14 项全部通过。八个题目页分别进入正式 3D 检查三键，准度、解球、防守、K 球、分离角和三球练习核纵坐标并点击临时 2D 和第三人称；翻袋及两球另验横滑对杆向的影响。瞄准点核作答输入，角度练习核未答保密，进球容错角核无杆时的观察和临时 2D，照片导入核原球位及两个人称。动作库从正式入口跑同杆截图及暂停、重播、序列／自由往返。[用例与结果](../../output/camera-v69/phone/evidence/test-details.json)。这批的第 3 杆横向偏差由上文真机测量发现，之后单独修正并复验。

### 已保存布局与附加回归

旧四键模板带有单独移动过的打点控件、颠倒的相机坐标与旧全局键。测试经正式存储接口保存、重建存储实例并解码，再以实际默认控件尺寸排列。第三人称保留原纵坐标，临时 2D 和第一人称分别在其上、下方，打点坐标保留，重复应用结果一致。[存档往返测试](../../output/camera-v69/legacy-archive-summary.json)。这项检查使用测试存储，未覆盖从用户手机的真实个性化模板升级，以及打开系统 VoiceOver 后的手动遍历。

翻袋、颗星解球的自动求解生命周期、自由横滑和手选袋口等额外控制器用例 4/4 通过。[求解与镜头专项](../../output/camera-v69/solver-cameras-summary.json)。另一个既有的选解目录用例在固定翻袋球位得到 0 个候选，期望超过 1 个，单独重跑仍失败。它在点击切换候选之前即失败，尚未判定该球位应有几条物理可行路线。[失败记录](../../output/camera-v69/flow-recheck-summary.json)。

iPad Pro 11 英寸（M4）首轮在 iOS 26.2 上跑了 10 项。动作库详情／试打、训练记录、翻袋求解和颗星解球的正式 UI 通过。两个求解页面都实际切了第一和第三人称、点小眼睛往返，并核对当前解。另六项分别遇到已移除的手动求解按钮、旧角色按钮、三处旧的 3D 球库禁用断言，以及测试工具按竖屏宽高判断横屏窗口的问题。[iPad 首轮逐项结果](../../output/camera-v69/pad-test-details.json)。

iPhone 另从生产页面深链打开了[普通自由击球](../../output/camera-v69/review/iphone16/freePlay.png)和[击球模拟](../../output/camera-v69/review/iphone16/shotSimulation.png)。前者沿用本机保存的正式 2D，在 2D 中没有人称键；后者为默认第三人称，可见三个视角键。此处检查了进入后的画面。

iPhone 17 Pro 在跨杆击点修正后的 6 个正式 UI 用例全部通过，覆盖分离角与走位三键、动作库首杆和第 3 杆、每日清台、蛇彩、多球及自定义模板进入练习。[最新正式入口复验](../../output/camera-v69/final/evidence/test-details.json)。

最后核对高低杆时，发现详情演示在静止架杆后开始运杆的两处绘制只传入了左右打点。现已与镜头和试打使用同一上下打点；这不改变上表两杆中心球的读数。已在解锁的 iPhone 16 Pro 运行换杆、连续／独立序列、序列自由往返和旧布局存档共 6 项，全部通过。[最终专项结果](../../output/camera-v69/device-stroke-unlocked-summary.json)、[覆盖安装](../../output/camera-v69/device-stroke-preflight-install.json)和[启动记录](../../output/camera-v69/device-final-launch.json)。

iPad 随后逐页重走角度与瞄准、分离角图谱、加塞吃库图谱。三条完整流程通过，检查了第一人称、小眼睛临时 2D 进退、第三人称复位及页面参数。[三页复测明细](../../output/camera-v69/pad-confirm-test-details.json)。

iPad 的扎杆页另测了 75° 抬杆、旋转、小窗口和恢复最大化。小窗口中杆角、母球坐标保持，所查控件都在窗口内。恢复最大化后，SwiftUI 报告的内容高度为 814 pt，进入小窗前为 782 pt，相差 32 pt。该项仍失败，现有证据不能判定是系统窗口装饰还是页面布局所致。[窗口测试明细](../../output/camera-v69/pad-window-test-details.json)。

iPad 最后 4 项正式 UI 专项全部通过。走位求解和打一走二想三分别检查了规划及开球阶段的三键；图谱检查退出临时 2D 后返回原人称；扎杆页检查抬杆、临时 2D 移母球和恢复杆角设置。前两项验证了相机流程，旧用例后半段的完整解集筛选和试打流程尚未逐步复验。[四项结果](../../output/camera-v69/ipad-built/tests.json)。

拍照确认页的三个菜单项都把当前盘面传给相应目的地。经正式 UI 逐球比对过的是分离角与走位；照片直接进入走位求解或打一走二想三的整段流程仅核对了导航代码。工程门禁与进度文档体积检查均通过。[工程检查](../../output/camera-v69/gate-final.log)、[文档检查](../../output/camera-v69/doc-size.log)。

## 复核每日清台的镜头距离与内嵌取景

从每日清台正式 UI 的“点第三人称复位、横滑之前”导出了同一帧的[画面](../../output/camera-v69/daily-lens/daily-third.png)和[SceneKit 相机及母球坐标](../../output/camera-v69/daily-lens/daily-world.json)。该盘在 874 × 402 pt 视口中相机水平后撤 1.649 m，眼点到球心 1.762 m。动作库「中袋直线出杆」独立两杆的横屏真机读数换算后均为 1.650 m 和 1.763 m。两盘杆向不同，本项比较眼点相对母球的量。

此前卡片按 386 × 220 pt 和 64° 水平视场角计算纵向视场角，得到 39.21°；同设备横屏试打为 32.07°。投影中心对齐仍会出现这种差异。现在内嵌详情与训练记录在标准第三人称取本窗口横持的纵向视角，投影仍使用卡片真实尺寸。横屏试打、每日清台和既有相机距离沿用原实现。第 1、3 杆的回归同时断言眼点、纵向视角和杆轴上距击点 40 cm 处的相对画面高度。

iPhone 16 Pro 上以同一用例实跑详情及试打的第 1、3 杆，四个状态的断言全部通过。随后重新构建常规 App、覆盖安装并从动作详情正式页面采集首杆。[真机结果](../../output/camera-v69/daily-lens/test-summary.json)、[四个采样](../../output/camera-v69/daily-lens/strokes/manifest.json)、[覆盖安装](../../output/camera-v69/daily-lens/install.json)、[首杆同框对照，左旧右新](../../output/camera-v69/daily-lens/phone-before-after.jpg)。

## iPhone 横屏基准用于全部瞄准页

每日清台、分离角与走位／普通自由击球、模板练习、蛇彩、多球复用 `FreePlayView` 的相机。教学、图谱、专项和求解页经 `TeachingTableHost` 按阶段提供杆向。动作库内嵌演示、训练记录与序列试打也由 `CameraRig` 传入同一套瞄准镜头。拍照确认后的机位随目的地。模板编辑阶段继续按摆球和测量需要取景。路由与阶段详见本文件的逐入口表。

当前正式布局以每日清台 874 × 402 pt 原版横屏为准。第一人称纵向视场角约 27.49°，第三人称约 32.07°。默认眼点继续取自实际杆位、抬杆与净空条件；母球和杆身的纵向投影保持一致，水平可见范围随真实窗口变化。打断切镜时以同一镜头口径记录侧看的视场角。历史录像从原布局解码，无新镜头字段时按原轨迹播放。固定盘的控制器另验证了连续五次改视口、过渡中接管后旋转和旧布局镜头。[改视口的控制器记录](../../output/camera-v69/device-framing/resize.log)。

同一盘选中 1 号球、目标袋为左远角袋。在每日清台页面实际点按两个人称按钮，按画面等高并排显示。[六图总览与全分辨率原图](../../output/camera-v69/device-framing/review/index.html) · [相机与投影实测](../../output/camera-v69/device-framing/review/measurements.json)

| 同一盘面 | iPhone 17 Pro 横屏 | iPad Pro 11 英寸横屏 | iPad Pro 11 英寸竖屏 |
|---|---|---|---|
| 第三人称 | 杆身约 84 cm，1 号球和目标袋可见 | 同左 | 两者可见，袋口中心距左边约 51 pt |
| 第一人称 | 杆身约 80 cm，1 号球和目标袋可见 | 同左 | 杆身约 80 cm，1 号球可见，袋口中心超出左边约 34 pt |

杆身按从击点沿杆轴到画面下沿量取。截图采自 iOS 26.2 模拟器，[iPhone 定向测试 26/26](../../output/camera-v69/device-framing/phone/summary.json)、[iPad 定向测试 2/2](../../output/camera-v69/device-framing/pad/summary.json)。iPad 同次运行另覆盖动作库卡片与试打机位。常规签名版本已[装到 iPhone 16 Pro](../../output/camera-v69/device-framing/install.json)。其余共用页面按相机调用路径核对，本轮六图来自每日清台。
