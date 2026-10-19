# 首次体验学习引导 · Figma · 2026-10-17

状态：r6按本轮五项反馈完成，待用户审阅。恢复渲染原色，三张2D改短边第三人称；计划记录用真实App截图叠合；底部进度居中，资料页精简分组。未改App产品代码。

## r6 当前交付（2026-10-17）

[七屏总览](https://www.figma.com/design/C6Qt7HUPFvP13ut8NAZGlU?node-id=68-693) · [原型起点](https://www.figma.com/proto/C6Qt7HUPFvP13ut8NAZGlU?node-id=72-4733&starting-point-node-id=72%3A4733) · [资料页](https://www.figma.com/design/C6Qt7HUPFvP13ut8NAZGlU?node-id=72-4635)。独立页68:692，旧稿保留。

- 雾感核查：r5图片在Figma额外设置曝光−8%、饱和度−30%、对比度+8%，第一人称镜头还叠加渐变。r6删除全部额外滤镜与遮罩，图片不透明度1、八项滤镜全0；不修改原生灯光/材质以假造质感。
- 分离角、走位、清台均使用当前源码重新渲染3D，从短边外侧略偏置第三人称看向球桌；15°碰撞后的轨迹朝画面下方。保持r5物理条件与散局终态、极简赛事球房/黑金球杆，只有机位改变。瞄准/加塞复用同条件原生图恢复原色。
- 计划页使用本轮用户提供的三张真实App截图，以裁切容器呈现计划列表→详细计划→训练记录，错位重叠；不重绘记录数据。文字/导航/资料控件仍可编辑。用户截图中的2D缩略图保留原样。
- 删除底部01/06等编号；六段进度宽126、x138，中心201与402宽屏幕严格对齐。上方章节编号保留。
- “个人计划”按用户附图解释为资料页：更大标题、整组分段选项、细线分区、生日行，减少多块按钮边框。无昵称/水平，球种/球龄/性别/生日选填且不预选。生日滚轮仍为固定示例，可确认/取消/清空；未实现真实滚轮输入。

验证：当前采集脚本XCTest成功（capture-build-r2.log），三张新3D原图、Figma整图与资料单屏目视检查完成。50条导航读回目标有效；10个选项初始false、生日未填写；0缺失字体，0渐变遮罩、0底部编号。保持Noto Sans SC替代字体，未做原生SF/苹方还原验收；未在浏览器逐次点击。模拟器经生命周期入口借用和释放，最终Shutdown。没有修改App产品源码、用户资料设置或当前球局，未提交发布。

证据：`output/intro-three-page-20261017/r6/`中的harness、render、compose.js、figma-state.json、verification.json、source-evidence.json、preview-final.png和profile.png。首次capture-build.log误用r5采集源，不计为r6证据；修正独立采集项目的harness路径后，capture-build-r2.log才是本轮有效输出。

## r5 历史交付（2026-10-17）

[七屏总览](https://www.figma.com/design/C6Qt7HUPFvP13ut8NAZGlU?node-id=61-827) · [原型起点](https://www.figma.com/proto/C6Qt7HUPFvP13ut8NAZGlU?node-id=62-4634&starting-point-node-id=62%3A4634) · [生日滚轮](https://www.figma.com/design/C6Qt7HUPFvP13ut8NAZGlU?node-id=62-4836)。独立页61:826，旧稿保留。

- 瞄准：母球至目标球1.503m、约39.45°切角，近第一人称，角袋可见。加塞：参考第二图球位，1.89m/s、右塞与高杆组合；仅第一人称。两图显式启用当前“极简赛事”球房与“黑金几何”球杆。
- 分离角：15.0000002°切角，3m/s，8种高低杆法由当前ShotPredictor计算。按用户追加要求，将俯视机位翻转，让碰撞后轨迹向下展开，角度文字保持正向；没有镜像物理或重绘轨迹。
- 走位：与加塞共用参考球形与预测，完整俯视图。清台：当前RackLayout＋BreakSimulator开球，四个种子均完成；选20261018（6.5m/s、无白球落袋/无黑八落袋、余14球含母球），按平均最近邻距离选较散局，未移动任何结果球。
- 计划与记录：一页前后叠合两块可编辑内容面板；计划采用plan_accuracy首课“近台小角度入门”的真实阶段，记录12/15、80%、3组明确为示例，不冒充用户记录或原生截图。
- 移除标题下辅助段落、清台小字、生日辅助文案、昵称；保持球种/球龄/性别/生日全部可跳过且不预选，无水平输入。生日五行滚轮展示、确认/取消/清空；已填行显示生日和周岁。原型是固定1996-06-18→30岁示例，非真实滚轮输入。
- 按钮使用HUDStyle所消费的btOverviewDays深色值#68C88A；不改r3/r4组件。所有文字与控制为可编辑节点，5个离散实渲图片；总览1792×2047，七屏402×874。沿用Noto Sans SC替代字体，缺字0，不代表SF/苹方原生字体一致性通过。

验证：独立采集项目使用原工程当前源码、隔离bundle id；XCTest出口与球形/终局断言通过（capture-build-r5.log）。原生输出、总览与生日弹层目视检查；50条导航目标均为同页有效顶层Frame，10个选择变量初始false，生日未填。未在浏览器逐次点击验收，不持久化，不接App。只在output下创建采集工程/测试，不修改产品代码。借用池设备由生命周期入口释放并恢复Shutdown；未删设备/未改用户资料设置/未安装真机/未提交发布。

返工记录：首轮采集只改相机变换、未切perspective3D，导致reference_room仍隐藏；独立环境默认original球杆。用户指出后改采集装配：显式setCameraMode与applyStyle(.blackGold)，回读manifest的roomVisible=true、cueStyle=blackGold，并重新出图同步总览和原型。属于采集脚本修正，未改引擎。

证据：`output/intro-three-page-20261017/r5/`下harness、独立项目、compose.js、figma-state.json、render/manifest.json、source-evidence.json、preview-final.png、birthday.png。源码哈希用于明确当前版本；原生导出不等于生产App回归或用户视觉验收。下一步由用户审阅构图/器材/场景；App接入另行授权。

## r4 历史交付（2026-10-17）

[七屏总览](https://www.figma.com/design/C6Qt7HUPFvP13ut8NAZGlU?node-id=57-692) · [原型起点](https://www.figma.com/proto/C6Qt7HUPFvP13ut8NAZGlU?node-id=58-946&starting-point-node-id=58%3A946) · [生日选择状态](https://www.figma.com/design/C6Qt7HUPFvP13ut8NAZGlU?node-id=58-1153)。独立页面56:692；保留r3，未覆盖已认可方向。

| 页 | 学习主题 | 主文案 |
|---|---|---|
| 01 | 瞄准 | 进球，从看准开始。 |
| 02 | 分离角 | 打进之后，母球去哪？ |
| 03 | 加塞 | 看懂旋转，再学会运用。 |
| 04 | 走位 | 这一杆，为下一杆留位置。 |
| 05 | 清台 | 把一杆，连成一局。 |
| 06 | 训练计划与记录 | 有方向地练，有依据地回看。 |
| 07 | 可跳过资料 | 认识一下你。 |

资料分“台球习惯”（主打球种、球龄）与“个人资料”（昵称、性别、生日）。全部选填且不预选；性别为男／女／不愿透露，可取消选择。生日未填不显示年龄；填写生日后按周岁自动计算，不直接存固定年龄。原型用1996-06-18→30岁（2026-10-17）的固定示例表现确认、取消与清空，未模拟真实滚轮输入或昵称键盘。

流程：六页顺序继续／返回，任一页可跳过介绍进入资料，稍后填写不保存草稿直接进入既有首页。开始使用只保存主动填写项。老用户直接首页；主动重看介绍结束返回来源，不重复填资料。移除水平入口不清空旧水平资料，保留旧资料、设置、页面记忆和当前球局；主打球种不得覆盖已有默认玩法选择。上述为设计合同，本轮未实现或测试App行为。

视觉沿用r3深色背景、无衬线标题、低饱和绿和组件；总览1792×2047，七屏402×874。复用原按钮与选项组件，103个可编辑Text、31个Instance、37个Frame、60个Rectangle；仅5个离散球桌图片节点，无整页UI栅格。Noto Sans SC缺失字体0，仍不代表SF／苹方原生字体匹配通过。

验证：整图与生日弹层已目视检查；分离角图下补明“同一进球角度，对比不同杆法”，避免把图中30°进球角误当统一分离角。50条导航读回，目的地均为同页有效顶层Frame。10个选项布尔初值均false；生日未填写；无当前水平输入。未在浏览器逐次点击验收；原型无持久化，不接App或真实输入。未构建、未操作模拟器／真机、未提交或发布。

素材：瞄准与三球衔接复用r3真实截图／c042精讲导出；分离角来自`output/separation-intro-20260916/r2/frames/simulation-30.png`局部；加塞来自`output/solver-markers-20260915/after/reflection-3d-spin-402.png`球桌局部；走位来自`QiuJi/Resources/TutorialFigures/drill_c080_s01.heic`。只做裁切、旋转、外围黑底透明化及显示色调处理，没有生成图，没有重绘物理轨迹。

证据：`output/intro-three-page-20261017/r4/`：compose.js、figma-state.json、preview-final.png、birthday.png、真实素材裁片。下一步由用户评审七页内容节奏与资料密度；App实施另行授权。

## r3 历史交付（2026-10-17；风格保留，内容由r4更新）

[四屏总览](https://www.figma.com/design/C6Qt7HUPFvP13ut8NAZGlU?node-id=49-693) · [原型起点](https://www.figma.com/proto/C6Qt7HUPFvP13ut8NAZGlU?node-id=51-1465&starting-point-node-id=51%3A1465)。独立页49:692，旧稿保留，r2页面已标退回。

- 01「你的台球实验室」：现有3D球桌近景裁片，以构图与暗部过渡呈现；未用生成图。
- 02「看线路，也看角度」：2D／3D静态视角切换。素材限制下采用真实视角示例，未伪造“切换打点后的物理结果”。
- 03「想明白，再练熟」：同一初级蛇彩首杆的俯视图与看精讲／上台练／留记录的价值衔接。
- 04资料：主打球种、水平、球龄初始不预选，昵称选填；头像／性别／生日后补。跳过与开始均到既有首页衔接节点。

总览4屏402×874；另有2D状态、4个顶层原型副本和首页衔接说明。3个复用组件、24实例、62可编辑Text，总览仅3个离散球桌图片节点，没有整页UI栅格导入。17条导航目的地读回均为有效顶层Frame；11个资料布尔变量初始false，单选／取消条件反应已写入。整图检查修复了按钮换行，并将早期5球导出替换为对应c042三球首杆。最终图：`output/intro-three-page-20261017/r3/preview-final.png`。

边界：云端SF Pro hasMissingFont=true，本稿采用Noto Sans SC可编辑替代；缺字检查为0，但不代表SF／苹方一致性通过。未实机或浏览器逐次点击验收；昵称不接真实输入，原型不保存数据；镜头为静态裁切与过渡，无新增动画或渲染实现。旧用户资料、通用设置、页面记忆与当前球局保护仍为已有合同，本轮未修改代码或验证App。

素材来源：`output/drill-sequence-camera-20261014/tryout/drill_c042-opening.png`（只裁球桌区域）与`QiuJi/Resources/TutorialFigures/drill_c042_manual01_s01.heic`（只裁球桌并旋转、去外围黑底）。生成图片已被用户否决，未导入r3。构建脚本、状态与审查证据在`output/intro-three-page-20261017/r3/`。

## 交付

[Figma 四屏与衔接说明](https://www.figma.com/design/C6Qt7HUPFvP13ut8NAZGlU?node-id=33-3722)。新增独立页面 `33:3721`，旧设置草图保留。

- 01 `35:697`：看懂这一杆，再上台练。沿用 A2 瞄准关系素材。
- 02 `35:764`：每次上台，都知道练什么。沿用横向蛇彩围8球形，关联今日安排与动作精讲。
- 03 `35:885`：练完之后，留住经验。记录卡和心得为示例，不写入真实数据。
- 04 `35:1025`：认识一下你。球种、水平、球龄均不预选，昵称选填；头像/性别/生日后续在个人信息补充。

## 衔接

首次新用户：介绍1→2→3→资料→首页。任意介绍页「跳过介绍」进入资料；末页「继续，认识一下你」进入资料。「稍后填写」不保存草稿直接到首页；「开始使用」仅保存主动填写项。老用户直接首页，已有资料/设置/页面记忆/当前球局保持。默认玩法不被主打球种覆盖已有明确选择。

从我的→认识球迹重看时只显示介绍三页，末页按钮「完成」回到原页面，不再次进入资料页。以上为静态设计规则，本稿未实现可点击原型或保存逻辑。

## 规范与验证

延续已确认 A2：btIntroBackground #03120A、btIntroForeground #F3E6C9、btIntroRule #92815B；Noto Serif SC Bold 34pt标题、52pt描边胶囊按钮。资料页沿用既有Token、17pt绿标题、16pt边距、12pt卡片。402×874内容画框，省略系统状态栏和设备外壳；品牌字样保留当前介绍的「涨球记」。

Figma SF Pro 探测 hasMissingFont=true，继续采用之前草图的本机SF/苹方真实字形转曲；正文不是可直接编辑的Text，源文案保存在manifest.json。标题为可编辑Noto Serif SC，旁注为可编辑Noto Sans SC。无完整UI截图导入；仅2张离散球桌图片，记录与控件为组件/图层。

整图初审修复旁注高度、统一三页标题基线后复验。最终画板1816×1535；480后代节点（23 TEXT、55 FRAME、77 INSTANCE、310 VECTOR、6 RECTANGLE、9 ELLIPSE），Text缺失字体0。截图仅代表静态草图视觉检查，不代表App适配/交互/真机验收。

证据：`output/intro-three-page-20261017/r1/` 下 composition-final.png、figma-state.json、foundations.json、manifest.json、compose.js。未构建、未操作模拟器/真机、未提交或发布。

下一步：先向用户说明竞品研究与重做方向，再推进设计；旧稿技术复验不代表视觉验收。当前未修改 Figma 或 App。

## 2026-10-17 竞品调研与返工范围

用户明确要求内容与样式一起重做，先调研其他 App。公开案例：Nike Training Club（https://screensdesign.com/apps/nike-training-club-wellness/）、Headspace 历史流程（https://sendbird.com/blog/mobile-app-onboarding）、Kino 官方设计回顾（https://www.lux.camera/kino-a-pro-video-camera-in-four-months/）及手册（https://www.shotwithkino.com/post/kino-pro-video-camera-manual）、Runna（https://revyl.com/atlas/runna/flows/sign-up-and-complete-onboarding/）、Duolingo 桌面网页流程（https://screenrove.com/duolingo/flows）。来源为公开流程记录与官方资料，非本机实测当前各版本。

候选方向：品牌欢迎→一次简短能力体验→可跳过的轻量资料引导；页数随内容决定。视觉转向现代专业运动工具表达，真实台球主视觉、清晰无衬线字体、克制品牌绿、明确主操作。暂不冻结新文案、配色或页数。资料减项、互动演示均为建议，未实施；已有资料、设置、页面记忆与当前球局保护继续有效。

## r2 · 品牌欢迎 → 看一杆 → 认识一下你（2026-10-17）

用户授权按竞品研究后的新方向重做Figma，暂不改代码。

- 设计总览：https://www.figma.com/design/C6Qt7HUPFvP13ut8NAZGlU?node-id=42-693
- 页面：`42:692`；总览：`42:693`；四屏：`42:695`～`42:698`（三阶段，体验前后两个状态）。
- 可点击原型入口：`45:953`；体验前后：`45:972` / `45:1010`；资料：`45:1054`；首页衔接说明：`45:943`。不是重画的首页。
- 欢迎页采用重新生成的台球照片、无衬线大标题和实色主操作；保留当前产品显示名“涨球记”。展示文案为“看清每一杆，练好每一步”。
- 演示围绕同一球形显示方向，提供跳过与再看一次。球形为可编辑矢量，假想球位置以局部像素数值核验，非真实物理引擎预测；不展示未经验证的母球后续轨迹。
- 资料仅主打球种与水平，默认不预选，可跳过；其余资料在个人信息补充。原型资料选项为静态示意，不保存。保存／跳过、老用户保护、重看介绍规则在画布旁注中说明。
- 继承既有btPrimary、BTRadius/md，局部新视觉变量和9个组件仅用于r2候选。当前Figma的SF Pro试写hasMissingFont=true，采用可编辑Noto Sans SC；不是原生系统字体完全复刻。App仍保留原实现。
- 总览177后代节点：43 FRAME、58 TEXT、6 RECTANGLE、59 VECTOR、11 INSTANCE；唯一图像填充是欢迎照片，无完整UI栅格图。字体检查missingFonts=0。
- 完整画面已目视检查；14处原型动作的目的地存在且均为合法同页顶层Frame，未在浏览器实际逐个点击，不能等同App交互测试。首次嵌套Frame的NAVIGATE被API拒绝并回滚，改为独立顶层原型副本后成功。
- 临时生成图层`43:692`已删除，照片已填入新版并本地保存；r1改名“已退回·保留对照”，未删除旧稿。
- 证据：`output/intro-three-page-20261017/r2/`：preview.png、hero.png、compose.js、geometry.json、figma-state.json。

下一步：用户评审主视觉、文案与流程；未构建、未操作模拟器／真机、未提交或发布。


## r2退回后的五方向研究（2026-10-17）

用户反馈：内容与样式均缺少高级感，要求深入调研并提供5个方案。判断：r2照片欢迎、平面教学图、普通资料表单缺乏连续视觉语言；单次显示瞄准线不足以表达完整产品价值。以下均为提案，未获选，页数不冻结。

| 方向 | 参考 | 内容与首次体验 | 主要取舍 |
|---|---|---|---|
| 运动品牌 | Nike Training Club | 真实训练影像建立情绪→实际产品帮助→可跳过资料 | 需高质量台球摄影，避免通用运动广告 |
| 专业推演工具（优先建议） | Kino、Flighty | 球桌与击球结果为主视觉→推演衔接练习→同语言资料设置 | 必须保证真实渲染与镜头质量 |
| 互动探索 | Brilliant | 一个有因果反馈的小实验→解释与练习入口→可跳过资料 | 不做测验门槛，不把产品缩成瞄准教学 |
| 立体动效 | Not Boring Habits | 球与轨迹贯穿推演/练习/复盘→自然进入资料 | 运动与材质质量要求最高，静态图不代表成片体验 |
| 个人训练陪伴 | Gentler Streak | 训练节奏与兴趣→实际训练内容预览→自然补资料 | 不虚构AI或自动生成个性化计划能力 |

研究边界：依据公开流程截图/录像及官方设计访谈，未实机安装逐一验证当前版本。Kino/Flighty主要参考领域化视觉语言；Brilliant真实归档中注册及订阅页先于课程，不声称其允许免登录先体验；Not Boring不借用未核查的习惯天数或学习效果承诺。

共同衔接：介绍与资料均可跳过；不以填资料解锁体验；昵称可选，头像/性别/生日后续个人信息补充。演示不写入真实训练、页面记忆或通用设置，不影响当前球局。老用户已有资料/设置保留。

来源：
- Nike实际流程：https://screensdesign.com/apps/nike-training-club-wellness/
- Kino官方设计过程：https://www.lux.camera/kino-a-pro-video-camera-in-four-months/
- Flighty官方设计访谈：https://developer.apple.com/news/?id=970ncww4
- Brilliant设计师案例：https://www.mrdavenport.co/brilliant
- Brilliant实际流程：https://screensdesign.com/apps/brilliant-learn-by-doing/?vs=25756
- Not Boring官方：https://notbor.ing/；流程：https://screensdesign.com/apps/not-boring-habits/
- Gentler Streak官方访谈：https://developer.apple.com/news/?id=3m0ht22s；流程：https://screensdesign.com/apps/workout-tracker-gentler-streak/
