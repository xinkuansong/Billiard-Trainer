# 2D / 3D 功能与截图盘点 · 2026-09-15

现状盘点：32 个页面/模式条目，259 条功能清单（含组合项），610 张关联原图。已汇总 524 张手机状态图（含注明来源的新版复用图）；各页未覆盖状态仍单列。

本轮经授权在独立 iPhone 17 Pro（iOS 26.3.1）构建并运行 XCUITest。源码快照、测试补充及日志位于 xcuitest-r1，App 产品代码未改。此前 CUA 截图与复用图来自不同安装版本，只作历史证据；本轮冻结源码图有独立源码指纹；newer-reuse 明确标记为另一次新版截图。最新名称、背景音乐、球杆及线条差异另列，不能把跨版本图当成同次运行。截图和测试通过均不代表全部模式覆盖。

## 阅读入口

- [本轮手机连续状态与相机对照](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/phone-evidence.html)
- [显隐与相机条件矩阵](/Users/song/projects/13.billiard_trainer/tasks/ui-reviews/UR-20260915-control-state-matrix.md)
- [截图与功能图册](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/index.html)
- [功能清单 CSV](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/functions.csv)
- [原图清单与哈希](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/manifest.json)
- [安装包与源码环境记录](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/evidence/environment.json)

截图表示采到画面；源码表示存在分支；两者均不等于操作已全部验证。初次启动未就绪的图片不计入关联图册。

## 页面 / 模式索引

| 编号 | 页面 / 模式 | 关联图数 | 待补 |
|---|---|---:|---|
| P01 | 自由击球：2D / 3D × 进袋 / 自由 | 15 | 已补 2D/3D、进袋/自由、更多、开球、打点、精调特写、击球停稳、回放与重打。球形拖动的全边界和全部触点仍属后续质量验收。 |
| P02 | 每日清台：同一View的dailyClearance分支 | 47 | 已补两种维度的结果页、重开/换玩法确认及取消、最后一球完成和母球落袋恢复。玩法对照与 3D 确认另见本轮图；结果夹具与真实击球流程分别标记，不等于自然完成所有规则对局。 |
| P03 | 分离角与走位：2D / 3D × 进袋 / 自由 | 27 | 已补 2D/3D、同球形九种构图、更多、打点微调、拖动特写、击球/回放/重打。打点浮层与动作列有重叠；全部遮挡位置的命中未逐点验证。力度0.5显示“未进袋”，仍可击球；不同于无解禁用。 |
| P04 | 自由走位（编排台）：2D / 3D × 进袋 / 自由；普通手机入口不提供录制 | 21 | 已补普通编辑、更多、重命名、2D/3D、击球与恢复、精调特写。普通手机入口不启动序列录制；录制与保存关联到 P22，不再把保留条件分支列作手机缺页。 |
| P05 | 上手试打：试打变体：序列 / 进袋 / 自由 × 2D / 3D | 21 | 已补序列/进袋/自由、手机 2D 对照、说明卡显示/隐藏、八杆逐杆边界及末杆后继续回第一杆。序列打点/力度为只读；手动模式才可编辑。 |
| P06 | 思路训练：2D编辑 / 3D观察；未设约束/计算/有解/播放 | 26 | 已补 2D/3D、三个约束工具及其画面、求解中/有解、更多求解范围、打点、击球与上一杆。候选/无解必须以具体截图读数判断，不因点了求解就计为有解。 |
| P07 | 打一走二想三：2D编辑 / 3D观察；三球角色规划 | 33 | 已补三球角色入口、两球计划夹具、2D/3D、三种约束工具、求解与窗口前移、恢复上一杆和更多。完整三球多杆自然执行不是本轮已经通过的质量结论。 |
| P08 | 防守：2D编辑 / 3D观察；目标选择/求解/播放 | 28 | 已补 2D/3D 的无解、完全斯诺克、高难度可行解、对象观察及回编辑；求解/击球/恢复已有连续图。已真实移动障碍恢复6个候选、切下一解并击球回放。 |
| P09 | 翻袋解球（旧称翻袋解球器）：当前源码与 09-15 小屏复用图：2D / 3D；初轮 iPad 旧包固定 2D | 34 | 已补求解/自由、库数、更多与原理、2D/3D、打点和精调特写、击球停稳与恢复。新版“翻袋解球”及线条样式用另一次测试原图单列；力度1.0后的恢复图明确出现“该袋暂无翻袋解”、击打禁用。 |
| P10 | 颗星解球（旧称反射解球器）：当前源码与 09-15 小屏复用图：2D / 3D；初轮 iPad 旧包固定 2D | 31 | 已补求解/自由、库数、更多与原理、2D/3D、打点和精调特写、击球停稳与恢复。新版“颗星解球”及线条样式单列；没有翻袋的选袋能力，不能合并成同一业务模式。 |
| P11 | 角度与瞄准：2D编辑 / 3D观察 | 16 | 已补教学指标、台面 2D/3D、对象观察与新版线条；球库、拖动、指标滚动和更多见本轮补跑。随机球形触发的所有几何提示不视为独立漏页。 |
| P12 | 分离角图谱：2D编辑 / 3D观察；八档高低杆比较 | 16 | 已补手机 2D/3D、八档/单档轨迹、力度与网格菜单；新版球杆图单列。44pt 命中尺寸断言的浮点误差在测试副本加容差后复跑通过，不改产品控件。 |
| P13 | 加塞吃库图谱：2D编辑 / 3D观察；八档左右塞比较 | 17 | 已补手机 2D/3D、八档/单档、力度、高低杆面板及网格；新版球杆图单列。八种左右塞轨迹开关与高低杆面板是两类能力。 |
| P14 | 2D 角度训练：固定2D；20题 / 自由练习 | 24 | 已补题面、辅助线、键盘、反馈、完整 20 题总结、训练类型与自由练习、额度大卡和紧凑提示。成绩保存错误目前只有源码；不算真实异常画面。 |
| P15 | 3D 角度训练：固定3D；20题 / 自由练习 | 26 | 已补五种相机动作、题面/键盘/反馈及完整 20 题总结。设置组件与 2D 共用但保留 3D 宿主图；免费入口会打开 Pro 弹层（P32），Pro 用户绕过题数额度；不能据共用视图分支虚构正常可达的3D免费额度页。成绩保存异常为源码边界。 |
| P16 | 2D 瞄准点训练：由路由固定2D或3D | 12 | 已补答题精调、按住时特写、提交/物理验证/下一题、额度大卡和紧凑提示。没有用户可选的难度或球号设置；保存失败和验证重试尚无真实故障截图。 |
| P17 | 3D 瞄准点训练：由路由固定2D或3D | 25 | 已补五种相机动作、方向轮特写、3D 环绕时特写、三题作答验证；免费入口为 Pro 弹层（P32），不是3D题面额度卡。3D 台面拖动用于相机；保存/验证异常仅源码核对。 |
| P18 | 动作详情中的球桌：嵌入式2D / 3D；多球形 / 逐杆演示 | 17 | 已补 2D/3D 控件可见→自动隐藏→点台面唤回→杆末暂停；两组球形分别跑完 8 杆和 5 杆（共 13 杆），并补播放/暂停中切球形。参数 HUD 仍显示，不是所有信息都消失。 |
| P19 | 训练记录页中的球桌：嵌入DrillSceneView | 22 | 已补独立记录宿主的 2D/3D 显隐与杆末暂停，球形切换已补；小幅右拖无明显环绕，大幅右拖触发父级总览，已复现并列为实际手势冲突。训练计组/结束仍属于宿主任务；不能用击球动作替代。 |
| P20 | 拍照建球形：选四步：选图 / 标定 / 标球 / 确认 | 33 | 已补真实选图→标定→标球→确认，长短库、拖动放大镜、退化四角禁用、撤销/重做、球库拖上/拖回，以及三目的地实际进入。改号/移除已补；不宣称照片几何识别精度验收。 |
| P21 | 批量出片台：建球形：仅模拟器内容生产工具 | 11 | 模拟器专用内容生产入口。新增空台、克隆与删除确认按真实存档补图；实际删除不执行。照片四步编辑复用 P20 的能力，但生产文件导出不冒充已验证。 |
| P22 | 批量出片台：编排求解：仅模拟器；固定2D生产编辑 | 10 | 模拟器专用编排入口。已补工具区、自由模式和更多；已采保存覆盖确认；四向精确球位控件未展开，仅源码确认。未保存或覆盖跨项目内容，完整录制导出属于内容生产验收。 |
| P23 | 设置中的球桌相关偏好：全局偏好；不是页内全部工具 | 14 | 已补相关设置的连续滚动位置、帧率、清台默认玩法；新版背景音乐与音效独立开关有浅/深色来源图。外观素材本身不是这次按键重组对象。 |
| P24 | 瞄准原理（关联教学页）：文档与示意图；无球桌相机 | 6 | 已补首屏至页尾、关联入口与练习 CTA。源码为阅读文档，没有教学滑杆或重播按钮，先前泛化缺口已撤销。 |
| P25 | 瞄准方法（关联教学页）：共享切角与局部试瞄角 | 10 | 已补切角 θ 与试瞄角 φ 两个独立滑杆端点和各教学章节；不能合并为含义不明的单个调节器。 |
| P26 | 瞄准修正（关联教学页）：参数联动引擎示意 | 12 | 已补力度/左右塞端点与三个高低杆档位、各章节读数。教学计算参数不等于可执行击球命令；未穷举所有物理输入。 |
| P27 | 旋转与加塞（关联教学页）：切角 × 接触旋转状态 | 11 | 已补切角端点、滑动/前旋/后旋三种示意状态及页尾关联入口。示意路径不是即时物理求解。 |
| P28 | 角度预测（几何测验）：Canvas题面 / 输入 / 结果 / 额度 | 10 | 已补答题/键盘、参考、结果与近期表现、两种额度状态；重置统计确认及点外部取消已采。保存错误横幅保留源码边界。 |
| P29 | 瞄准点（拖假想球测验）：Canvas拖动 / 提交 / 结果 | 11 | 已补拖假想球、偏移反馈、下一题与两种额度状态。所采拖动不宣称覆盖几何可达范围的所有端点；成绩保存失败只有源码。 |
| P30 | 瞄准点对照表：教学示意与对照表 | 12 | 已补首屏至页尾、切角与距离滑杆两端、正弦图和对照表；静态表格不列成额外可操作控件。 |
| P31 | 浅谈球感：教学文档与2D/3D对照插图 | 6 | 已补首屏至页尾及“用真台验证”进入 2D 角度训练。2D/3D 差异为插图，不是可操控台面。 |
| P32 | Pro 练习入口拦截：付费练习入口共用订阅弹层 | 6 | 3D 两种测验的免费入口实际弹出订阅页；不是题面内额度页。补拍入口、滚动与关闭；模拟器产品加载情况不代表商店交易验收。 |

## 修订与版本边界

- 翻袋、反射当前源码已经有 3D：旧 iPad 安装包图保留，新增小屏图取自另一轮测试附件，不能再把两页写成当前固定 2D。
- 21 张复用手机原图均逐张目视，并保存原 manifest、测试名、设备、时间和 SHA256；3 张纯渲染探针从页面覆盖计数剔除。
- 测试记录及拍照确认页已补实图；第5轮已用独立手机 XCUITest 补充系统照片选择器及记录页连续状态，详见手机图册。
- 前3轮没有构建、安装或运行自动化测试。第4轮已获授权并运行独立手机测试，结果见 phone-evidence.html 与 xcuitest-r1；功能盘点仍不是全功能通过声明。

## 已有证据支持的观察

### 小屏打点展开与动作区重叠

复用原图 reuse-bankshot-3d-spin、reuse-reflection-3d-spin、reuse-v63-planthree-compact-spin 中，半透明打点面板覆盖了部分击球/上一杆/回放区域。这里只确认视觉重叠；是否发生命中冲突尚未实测。

### 全桌与瞄准不能只按桌面放大倍数比较

小屏翻袋全桌图能看到完整目标路线；瞄准图更突出母球、目标球和出杆方向，同时裁掉部分桌面。需要按当前任务定义必须入镜的对象，再讨论哪些视角入口可合并。

### 同一位置不总是同一能力

试打序列中的打点/力度是只读参数；手动试打才是编辑控件。分离角图谱是八种杆法比较，不是普通击球面板。

### 编辑和观察是两组状态

思路训练、打一走二想三、防守进入 3D 后仍保留部分禁用的编辑工具；截图 47、49、50 可对照。是否隐藏、如何返回编辑，应逐模式讨论。

### 视角需要按任务核对

序列观察菜单包含全桌、母球、目标球、目标袋；回到瞄准并非所有模式都有。还不能直接判定所有对象观察都冗余。

### 球桌占比必须和焦点一起记录

3D 图 30、39 中房间背景、近端桌沿及长球杆占用明显空间；全桌观察与瞄准需要分别检查可见球、目标袋和遮挡。补充的小屏翻袋/反射图可对照全桌与瞄准构图；另有3张独立渲染探针不计页面覆盖。当前不把不同版本、不同球形混算为统一占比。

### 并非从零开始做自动收起

当前源码 DrillSceneView 已有播放时延迟收起控制的逻辑。补采记录页可启动回放并看到杆序改变，第5轮已在独立手机补齐记录页2D/3D按钮收起与点台面唤回证据。应先核实，再决定向哪些训练页推广。

### 设置层级确实跨页面

轨迹档位在台面，网格/瞄准特写在更多，全局页面另有帧率、音效、90°辅助线和玩法偏好。需要逐项区分临时动作、页内参数和持久偏好。

### 工具页不能当成手机常用入口

批量建球形/编排是模拟器内容生产工具；保留共享组件影响核查，不混入手机训练主界面。

## 逐页功能清单

每项列出位置、出现/启用条件及影响；组合项不当作独立已测试控件计数。

### P01 自由击球

模式：2D / 3D × 进袋 / 自由。源码：[FreePlayView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift)。

截图：[01-freeplay-2d-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/01-freeplay-2d-ready.png) · [reuse-settled-9-3d-375](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-settled-9-3d-375.png) · [reuse-break-spin-9-375](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-break-spin-9-375.png) · [reuse-initial-3d-375](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-initial-3d-375.png) · [xcui-r4-completion-freeplay-table-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-freeplay-table-released.png) · [xcui-r4-completion-freeplay-wheel-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-freeplay-wheel-released.png) · [xcui-r4-completion-freeplay-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-freeplay-ready.png) · [xcui-r4-completion-r5-freeplay-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-freeplay-restored.png) · [xcui-r4-completion-r5-freeplay-replay](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-freeplay-replay.png) · [xcui-r4-completion-r5-freeplay-stopped](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-freeplay-stopped.png) · [xcui-r4-completion-r5-freeplay-shooting](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-freeplay-shooting.png) · [xcui-r4-interactive-r4-freeplay-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-freeplay-more.png) · [xcui-r4-interactive-r4-freeplay-initial](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-freeplay-initial.png) · [xcui-r4-hold-freeplay-table.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-freeplay-table.held.png) · [xcui-r4-hold-freeplay-wheel.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-freeplay-wheel.held.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 2D/3D | 右上导航 | 非受限流程 | 仅观察模式 |
| 进袋/自由 | 顶部信息行 | 非开球 | 改变瞄准方式 |
| 目标球/目标袋选择 | 台面点选 | 按宿主允许条件 | 改变击球目标 |
| 母球移动 | 2D台面拖动 | 宿主指定的可拖母球；不能据球库外观推断目标球可拖 | 改变球形 |
| 瞄准微调 | 左侧刻度轮 | 自由瞄准 | 改变出杆方向 |
| 打点 | 右侧母球图打开面板 | 未播放 | 改变高低杆与左右塞 |
| 力度 | 右侧刻度柱 | 未播放 | 改变速度 |
| 轨迹档位 | 球桌右上 | 未播放 | 全局偏好并重绘 |
| 击球 | 右下动作列 | canStrike | 执行击球 |
| 重打 | 右下动作列 | canUndoShot | 恢复前杆状态 |
| 回放 | 右下动作列 | canPlayback | 重播前杆 |
| 开球 | 左下 | 未播放 | 进入玩法/摆架流程 |
| 视角/回到瞄准 | 3D底部 | 3D且相应对象存在 | 改变相机，不改击球目标 |
| 参考球库 | 2D底部 | 非3D | 显示桌上球/进球状态，非任意加球许可 |
| 更多 | 右上 | 按页面分支 | 网格、瞄准特写、清空桌面等 |

待补：已补 2D/3D、进袋/自由、更多、开球、打点、精调特写、击球停稳、回放与重打。球形拖动的全边界和全部触点仍属后续质量验收。

### P02 每日清台

模式：同一View的dailyClearance分支。源码：[FreePlayView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift)。

截图：[45-phone-daily](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/45-phone-daily.png) · [reuse-v63-daily-3d-failed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-daily-3d-failed.png) · [reuse-v63-daily-3d-completed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-daily-3d-completed.png) · [reuse-v63-daily-manual-delivered-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-daily-manual-delivered-3d.png) · [reuse-v63-daily-manual-settled-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-daily-manual-settled-3d.png) · [reuse-v63-daily-manual-ready-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-daily-manual-ready-3d.png) · [xcui-r2-photo2-v63-daily-3d-failed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo2-v63-daily-3d-failed.png) · [xcui-r2-photo2-v63-daily-3d-completed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo2-v63-daily-3d-completed.png) · [xcui-r2-photo3-v52-daily-manual-rack](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-v52-daily-manual-rack.png) · [xcui-r2-photo3-r2-daily-rerack-cancelled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-r2-daily-rerack-cancelled.png) · [xcui-r2-photo3-r2-daily-rerack-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-r2-daily-rerack-confirm.png) · [xcui-r2-photo3-r2-daily-game-changed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-r2-daily-game-changed.png) · [xcui-r2-photo3-r2-daily-game-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-r2-daily-game-confirm.png) · [xcui-r2-photo3-r2-daily-game-options](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-r2-daily-game-options.png) · [xcui-r2-photo3-r2-daily-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-r2-daily-more.png) · [xcui-r4-completion-daily-table-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-daily-table-released.png) · [xcui-r4-completion-daily-wheel-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-daily-wheel-released.png) · [xcui-r4-completion-daily-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-daily-ready.png) · [xcui-r4-completion-r5-daily-fourBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-fourBall-3d.png) · [xcui-r4-completion-r5-daily-fourBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-fourBall-2d.png) · [xcui-r4-completion-r5-daily-fiveBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-fiveBall-3d.png) · [xcui-r4-completion-r5-daily-fiveBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-fiveBall-2d.png) · [xcui-r4-completion-r5-daily-sixBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-sixBall-3d.png) · [xcui-r4-completion-r5-daily-sixBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-sixBall-2d.png) · [xcui-r4-completion-r5-daily-nineBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-nineBall-3d.png) · [xcui-r4-completion-r5-daily-nineBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-nineBall-2d.png) · [xcui-r4-completion-r5-daily-chineseEightBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-chineseEightBall-3d.png) · [xcui-r4-completion-r5-daily-chineseEightBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-daily-chineseEightBall-2d.png) · [xcui-r4-core-v63-daily-new-rack-after-completion](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-daily-new-rack-after-completion.png) · [xcui-r4-core-v63-daily-last-ball-completed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-daily-last-ball-completed.png) · [xcui-r4-core-v63-daily-last-ball-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-daily-last-ball-ready.png) · [xcui-r4-core-v63-daily-scratch-resumed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-daily-scratch-resumed.png) · [xcui-r4-core-v63-daily-scratch-cue-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-daily-scratch-cue-restored.png) · [xcui-r4-core-v63-daily-scratch-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-daily-scratch-ready.png) · [xcui-r4-remaining-r5-daily-3d-restart-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-3d-restart-confirm.png) · [xcui-r4-remaining-r5-daily-fourBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-fourBall-3d.png) · [xcui-r4-remaining-r5-daily-fourBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-fourBall-2d.png) · [xcui-r4-remaining-r5-daily-fiveBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-fiveBall-3d.png) · [xcui-r4-remaining-r5-daily-fiveBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-fiveBall-2d.png) · [xcui-r4-remaining-r5-daily-sixBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-sixBall-3d.png) · [xcui-r4-remaining-r5-daily-sixBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-sixBall-2d.png) · [xcui-r4-remaining-r5-daily-nineBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-nineBall-3d.png) · [xcui-r4-remaining-r5-daily-nineBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-nineBall-2d.png) · [xcui-r4-remaining-r5-daily-chineseEightBall-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-chineseEightBall-3d.png) · [xcui-r4-remaining-r5-daily-chineseEightBall-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-daily-chineseEightBall-2d.png) · [xcui-r4-hold-daily-wheel.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-daily-wheel.held.png) · [xcui-r4-hold-daily-table.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-daily-table.held.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 当前玩法/剩余球/杆数 | 顶部与状态区 | 对局中 | 只读进度 |
| 开球/瞄准/打点/力度/击球 | 球桌两侧 | 按清台阶段允许 | 推进对局 |
| 2D/3D与观察 | 右上/3D底部 | 按当前模式 | 相机变化 |
| 轨迹与辅助显示 | 台面/更多 | 允许时 | 共享显示偏好 |
| 重新开球 | 更多/结果分支 | 未结束对局时确认放弃 | 重新开始当前玩法 |
| 临时换玩法 | 更多→选择器 | 未结束对局时确认放弃 | 改变当前玩法 |
| 结束对局 | 更多 | 有进行中对局 | 结束并记录结果 |
| 再来一局 | 完成态 | 对局结束 | 创建新局 |
| 重打与回放 | 共享动作列 | 以每日分支实际能力为准 | 不可从自由击球无条件继承 |
| 默认玩法 | 全局设置 | 只影响下一新局 | 持久偏好 |

待补：已补两种维度的结果页、重开/换玩法确认及取消、最后一球完成和母球落袋恢复。玩法对照与 3D 确认另见本轮图；结果夹具与真实击球流程分别标记，不等于自然完成所有规则对局。

### P03 分离角与走位

模式：2D / 3D × 进袋 / 自由。源码：[ShotSimulationView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/ShotSimulationView.swift)。

截图：[29-ipad-shotsim-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/29-ipad-shotsim-2d.png) · [30-ipad-shotsim-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/30-ipad-shotsim-3d.png) · [31-ipad-shotsim-spinpad](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/31-ipad-shotsim-spinpad.png) · [32-ipad-shotsim-free](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/32-ipad-shotsim-free.png) · [xcui-r1-after-replay-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-after-replay-3d.png) · [xcui-r1-after-shot-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-after-shot-2d.png) · [xcui-r1-after-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-after-spin.png) · [xcui-r1-v63-restored-orbit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-restored-orbit.png) · [xcui-r1-v63-resumed-orbit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-resumed-orbit.png) · [xcui-r1-after-orbit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-after-orbit.png) · [xcui-r1-after-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-after-3d.png) · [xcui-r1-v63-pocket-low-close](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-pocket-low-close.png) · [xcui-r1-v63-observe-pocket](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-observe-pocket.png) · [xcui-r1-v63-observe-target](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-observe-target.png) · [xcui-r1-v63-observe-cue](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-observe-cue.png) · [xcui-r1-v63-observe-table](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-observe-table.png) · [xcui-r1-after-3d-pocket](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-after-3d-pocket.png) · [xcui-r1-after-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-after-2d.png) · [xcui-r4-completion-shotBlank-table-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-shotBlank-table-released.png) · [xcui-r4-completion-shotBlank-wheel-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-shotBlank-wheel-released.png) · [xcui-r4-completion-shotBlank-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-shotBlank-ready.png) · [xcui-r4-interactive-r4-shotsim-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-shotsim-more.png) · [xcui-r4-interactive-r4-shotsim-initial](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-shotsim-initial.png) · [xcui-r4-remaining-r6-shotsim-low-power-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-shotsim-low-power-3d.png) · [xcui-r4-remaining-r6-shotsim-low-power](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-shotsim-low-power.png) · [xcui-r4-hold-shotBlank-table.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-shotBlank-table.held.png) · [xcui-r4-hold-shotBlank-wheel.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-shotBlank-wheel.held.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 进袋/自由 | 顶部 | 未播放 | 切换瞄准方式 |
| 2D/3D | 顶部信息行右端 | 模式切换 | 只改相机 |
| 选袋/拖球/球库 | 2D台面与底部 | 宿主允许的球 | 设置实验球形 |
| 瞄准轮 | 左侧 | 自由模式 | 精调方向 |
| 打点盘 | 右侧母球图 | 未播放 | 拖点、四向1%微调、回中、关闭 |
| 力度 | 右侧 | 未播放 | 改变出杆速度 |
| 轨迹档位 | 台面右上 | 未播放 | 全/双/瞄准线 |
| 击球/重打/回放 | 右侧动作列 | 各自can条件 | 模拟、回退、重播 |
| 视角/回到瞄准 | 3D底部 | 3D | 全桌/母球/目标球/目标袋；返回瞄准 |
| 网格/瞄准特写 | 更多 | 显示设置 | 共享偏好 |

待补：已补 2D/3D、同球形九种构图、更多、打点微调、拖动特写、击球/回放/重打。打点浮层与动作列有重叠；全部遮挡位置的命中未逐点验证。力度0.5显示“未进袋”，仍可击球；不同于无解禁用。

### P04 自由走位（编排台）

模式：2D / 3D × 进袋 / 自由；普通手机入口不提供录制。源码：[PositionPlayComposerView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/PositionPlayComposerView.swift)。

截图：[33-ipad-composer-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/33-ipad-composer-2d.png) · [34-ipad-composer-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/34-ipad-composer-more.png) · [35-ipad-composer-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/35-ipad-composer-3d.png) · [36-ipad-break-picker](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/36-ipad-break-picker.png) · [37-ipad-break-racked](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/37-ipad-break-racked.png) · [38-ipad-break-playing](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/38-ipad-break-playing.png) · [39-ipad-break-settled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/39-ipad-break-settled.png) · [xcui-r1-v63-composer-returned-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-composer-returned-2d.png) · [xcui-r1-v63-composer-shot-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-composer-shot-restored.png) · [xcui-r1-v63-composer-shot-settled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-composer-shot-settled.png) · [xcui-r1-v63-composer-observed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-composer-observed.png) · [xcui-r1-v63-composer-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-composer-3d.png) · [xcui-r1-v63-composer-editing-baseline](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-composer-editing-baseline.png) · [xcui-r4-completion-composer-table-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-composer-table-released.png) · [xcui-r4-completion-composer-wheel-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-composer-wheel-released.png) · [xcui-r4-completion-composer-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-composer-ready.png) · [xcui-r4-interactive-r4-composer-reset-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-composer-reset-confirm.png) · [xcui-r4-interactive-r4-composer-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-composer-more.png) · [xcui-r4-interactive-r4-composer-initial](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-composer-initial.png) · [xcui-r4-hold-composer-table.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-composer-table.held.png) · [xcui-r4-hold-composer-wheel.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-composer-wheel.held.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 进袋/自由 | 顶部 | 普通编排 | 切换瞄准方式 |
| 球库上桌/拖回撤下 | 2D底部与台面 | 非受限状态 | 增减及摆放球 |
| 选球/选袋 | 2D台面 | 按宿主能力 | 设目标 |
| 微调/打点/力度 | 两侧 | 自由方向轮；打点力度按可用状态 | 调参数 |
| 击球/重打/回放 | 右侧 | 各自can条件 | 逐杆推进/回退/重播 |
| 下一解 | 左侧 | 有翻袋备选解 | 切换备选 |
| 开球 | 左下 | 未播放/计算/录制 | 玩法选择→摆架→开球→完成或取消 |
| 2D/3D/视角/回到瞄准 | 导航与3D底部 | 按模式 | 观察 |
| 重命名 | 更多 | 非试打 | 修改序列名称 |
| 清空桌面 | 更多 | 普通手机直接清空；录制确认是保留条件分支 | 清球；不等同清空重来 |
| 清空并重来 | 更多 | 确认 | 重置编排 |
| 网格/瞄准特写 | 更多 | 显示设置 | 共享偏好 |
| 录制条件分支（普通手机不可达） | 条件分支 | 普通Composer没有startRecording入口；实际调用在BatchAuthoringView | 保留代码关联供设计迁移核查，不计手机现有功能按键 |

待补：已补普通编辑、更多、重命名、2D/3D、击球与恢复、精调特写。普通手机入口不启动序列录制；录制与保存关联到 P22，不再把保留条件分支列作手机缺页。

### P05 上手试打

模式：试打变体：序列 / 进袋 / 自由 × 2D / 3D。源码：[PositionPlayComposerView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/PositionPlayComposerView.swift)。

截图：[07-tryout-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/07-tryout-ready.png) · [09-ipad-tryout-free](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/09-ipad-tryout-free.png) · [10-ipad-tryout-sequence](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/10-ipad-tryout-sequence.png) · [11-ipad-tryout-playing](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/11-ipad-tryout-playing.png) · [12-ipad-tryout-3d-sequence](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/12-ipad-tryout-3d-sequence.png) · [13-ipad-tryout-view-menu](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/13-ipad-tryout-view-menu.png) · [14-ipad-tryout-overview](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/14-ipad-tryout-overview.png) · [reuse-v63-tryout-pocket-after-replay-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-tryout-pocket-after-replay-3d.png) · [reuse-v63-tryout-pocket-editable-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-tryout-pocket-editable-spin.png) · [xcui-r4-core-v63-tryout-3d-eight-shots-reset](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-tryout-3d-eight-shots-reset.png) · [xcui-r4-core-v63-tryout-3d-boundary-8](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-tryout-3d-boundary-8.png) · [xcui-r4-core-v63-tryout-3d-boundary-7](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-tryout-3d-boundary-7.png) · [xcui-r4-core-v63-tryout-3d-boundary-6](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-tryout-3d-boundary-6.png) · [xcui-r4-core-v63-tryout-3d-boundary-5](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-tryout-3d-boundary-5.png) · [xcui-r4-core-v63-tryout-3d-boundary-4](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-tryout-3d-boundary-4.png) · [xcui-r4-core-v63-tryout-3d-boundary-3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-tryout-3d-boundary-3.png) · [xcui-r4-core-v63-tryout-3d-boundary-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-tryout-3d-boundary-2.png) · [xcui-r4-core-v63-tryout-3d-boundary-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-tryout-3d-boundary-1.png) · [xcui-r4-interactive-r4-tryout-info](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-tryout-info.png) · [xcui-r4-interactive-r4-tryout-menu](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-tryout-menu.png) · [xcui-r4-interactive-r4-tryout-2d-sequence](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-tryout-2d-sequence.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 序列/进袋/自由 | 顶部三选项 | 非播放 | 更换试打方式 |
| 局面目标/训练重点/参考打法 | 台面上方说明卡 | 初入及召回 | 只读任务说明 |
| 击打/暂停/继续 | 序列动作列 | 按序列播放阶段 | 逐杆演示；暂停语义按状态机 |
| 上一杆/重播 | 序列动作列 | 有对应前杆/回放 | 恢复/重播序列杆 |
| 本杆打点与力度 | 仪表或3D上方 | 序列模式 | 已录参数只读，不能画成可编辑尺 |
| 重摆球形 | 左下 | 允许恢复时 | 恢复来源球形 |
| 进袋/自由打点力度瞄准 | 两侧 | 非序列且未播放 | 手动试打 |
| 2D/3D与对象观察 | 导航/3D底部 | 相应模式和对象存在 | 只观察 |
| 试打说明 | 更多 | 试打分支 | 召回说明卡 |
| 网格/瞄准特写/轨迹档位 | 更多/右上 | 允许时 | 共享显示 |

待补：已补序列/进袋/自由、手机 2D 对照、说明卡显示/隐藏、八杆逐杆边界及末杆后继续回第一杆。序列打点/力度为只读；手动模式才可编辑。

### P06 思路训练

模式：2D编辑 / 3D观察；未设约束/计算/有解/播放。源码：[SiluTrainerView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/SiluTrainerView.swift)。

截图：[02-silu-2d-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/02-silu-2d-ready.png) · [47-ipad-silu-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/47-ipad-silu-3d.png) · [48-ipad-silu-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/48-ipad-silu-more.png) · [xcui-r3-planning-v63-silu-region-returned](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-region-returned.png) · [xcui-r3-planning-v63-silu-shot-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-shot-restored.png) · [xcui-r3-planning-v63-silu-shot-finished](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-shot-finished.png) · [xcui-r3-planning-v63-silu-compact-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-compact-spin.png) · [xcui-r3-planning-v63-silu-current-aim](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-current-aim.png) · [xcui-r3-planning-v63-silu-solved-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-solved-3d.png) · [xcui-r3-planning-r3-silu-solve-requested](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-r3-silu-solve-requested.png) · [xcui-r3-planning-v63-silu-region-orbit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-region-orbit.png) · [xcui-r3-planning-v63-silu-break-cancel-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-break-cancel-restored.png) · [xcui-r3-planning-v63-silu-region-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-region-3d.png) · [xcui-r3-planning-v63-silu-region-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-silu-region-2d.png) · [xcui-r4-completion-r5-silu-more-constraints](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-more-constraints.png) · [xcui-r4-completion-r5-silu-next-过点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-next-过点.png) · [xcui-r4-completion-r5-silu-result-过点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-result-过点.png) · [xcui-r4-completion-r5-silu-computing-过点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-computing-过点.png) · [xcui-r4-completion-r5-silu-constraint-过点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-constraint-过点.png) · [xcui-r4-completion-r5-silu-next-落点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-next-落点.png) · [xcui-r4-completion-r5-silu-result-落点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-result-落点.png) · [xcui-r4-completion-r5-silu-computing-落点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-computing-落点.png) · [xcui-r4-completion-r5-silu-constraint-落点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-constraint-落点.png) · [xcui-r4-completion-r5-silu-result-落区](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-result-落区.png) · [xcui-r4-completion-r5-silu-computing-落区](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-computing-落区.png) · [xcui-r4-completion-r5-silu-constraint-落区](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-silu-constraint-落区.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 落区/落点/过点/摆球 | 顶部工具组 | 2D可编辑，3D禁用 | 决定台面拖动含义 |
| 清除约束 | 工具组旁橡皮 | 有约束且可编辑 | 仅移除约束 |
| 目标球/目标袋 | 2D台面 | 先选择目标，再画约束 | 设求解条件 |
| 球库与球位置 | 2D底部/台面 | 未播放 | 编辑球形 |
| 求解 | 左下 | 有约束、未计算/播放 | 运行求解 |
| 下一解 | 左下 | 至少两解 | 切换候选 |
| 打点/力度 | 右侧 | 有解可调整 | 调整当前解并重新预测 |
| 击球/上一杆/回放 | 右下 | 各自can条件 | 模拟/恢复/重播 |
| 开球 | 左下 | 未忙 | 共享开球流程 |
| 允许左右塞/仅基础走位≤1库 | 更多→求解范围 | 本页特有 | 修改求解范围 |
| 网格/清空桌面/恢复默认 | 更多 | 按功能条件 | 显示/清球/整体恢复 |
| 2D/3D与对象观察 | 导航/3D底部 | 3D没有编辑权限 | 相机 |

待补：已补 2D/3D、三个约束工具及其画面、求解中/有解、更多求解范围、打点、击球与上一杆。候选/无解必须以具体截图读数判断，不因点了求解就计为有解。

### P07 打一走二想三

模式：2D编辑 / 3D观察；三球角色规划。源码：[PlanThreeView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/PlanThreeView.swift)。

截图：[03-planthree-2d-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/03-planthree-2d-ready.png) · [49-ipad-planthree-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/49-ipad-planthree-3d.png) · [reuse-v63-planthree-compact-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-planthree-compact-spin.png) · [reuse-v63-planthree-table-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-planthree-table-3d.png) · [reuse-v63-planthree-target-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-planthree-target-3d.png) · [reuse-v63-planthree-roles-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-planthree-roles-2d.png) · [xcui-r3-planning-v63-planthree-roles-returned](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-roles-returned.png) · [xcui-r3-planning-v63-planthree-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-restored.png) · [xcui-r3-planning-v63-planthree-advanced](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-advanced.png) · [xcui-r3-planning-v63-planthree-compact-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-compact-spin.png) · [xcui-r3-planning-v63-planthree-aim](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-aim.png) · [xcui-r3-planning-v63-planthree-solved](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-solved.png) · [xcui-r3-planning-r3-planthree-solve-requested](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-r3-planthree-solve-requested.png) · [xcui-r3-planning-v63-planthree-table-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-table-3d.png) · [xcui-r3-planning-v63-planthree-target-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-target-3d.png) · [xcui-r3-planning-v63-planthree-break-cancel-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-break-cancel-restored.png) · [xcui-r3-planning-v63-planthree-roles-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-planthree-roles-2d.png) · [xcui-r4-completion-r5-planthree-more-constraints](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-more-constraints.png) · [xcui-r4-completion-r5-planthree-next-过点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-next-过点.png) · [xcui-r4-completion-r5-planthree-result-过点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-result-过点.png) · [xcui-r4-completion-r5-planthree-computing-过点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-computing-过点.png) · [xcui-r4-completion-r5-planthree-constraint-过点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-constraint-过点.png) · [xcui-r4-completion-r5-planthree-next-落点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-next-落点.png) · [xcui-r4-completion-r5-planthree-result-落点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-result-落点.png) · [xcui-r4-completion-r5-planthree-computing-落点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-computing-落点.png) · [xcui-r4-completion-r5-planthree-constraint-落点](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-constraint-落点.png) · [xcui-r4-completion-r5-planthree-next-落区](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-next-落区.png) · [xcui-r4-completion-r5-planthree-result-落区](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-result-落区.png) · [xcui-r4-completion-r5-planthree-computing-落区](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-computing-落区.png) · [xcui-r4-completion-r5-planthree-constraint-落区](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-planthree-constraint-落区.png) · [xcui-r4-core-v63-three-roles-undone](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-three-roles-undone.png) · [xcui-r4-core-v63-three-roles-advanced](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-three-roles-advanced.png) · [xcui-r4-core-v63-three-roles-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-three-roles-ready.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 落区/落点/过点/摆球 | 顶部 | 2D可编辑 | 设置约束工具 |
| 清除约束 | 顶部橡皮 | 有约束 | 只清约束 |
| ①球/①袋/②球/②袋/③球 | 底部角色槽 | 2D可编辑；3D禁用 | 点击槽再在台面指定对象 |
| 清空计划 | 角色槽右侧 | 可编辑 | 清角色计划，区别于清空桌面 |
| 球库/拖球 | 底部/台面 | 2D | 修改球形 |
| 求解/下一解 | 左下 | 前置角色完整/有多个解 | 求解/换解 |
| 打点/力度 | 右侧 | 有解且未播放 | 调整当前解 |
| 打一/上一杆/回放 | 右侧动作列 | 相应can条件 | 执行第一杆及回退/重播 |
| 开球 | 左下 | 未忙 | 共享开球 |
| 网格/清空桌面/恢复默认 | 更多 | 本页没有思路页的求解范围项 | 共享显示与页面重置 |
| 2D/3D与观察 | 导航/3D底部 | 按对象存在性 | 相机 |

待补：已补三球角色入口、两球计划夹具、2D/3D、三种约束工具、求解与窗口前移、恢复上一杆和更多。完整三球多杆自然执行不是本轮已经通过的质量结论。

### P08 防守

模式：2D编辑 / 3D观察；目标选择/求解/播放。源码：[SnookerTacticsView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/SnookerTactics/Views/SnookerTacticsView.swift)。

截图：[04-snooker-2d-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/04-snooker-2d-ready.png) · [50-ipad-snooker-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/50-ipad-snooker-3d.png) · [xcui-r3-planning-v63-snooker-returned](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-snooker-returned.png) · [xcui-r3-planning-v63-snooker-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-snooker-restored.png) · [xcui-r3-planning-v63-snooker-finished](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-snooker-finished.png) · [xcui-r3-planning-v63-snooker-compact-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-snooker-compact-spin.png) · [xcui-r3-planning-v63-snooker-aim](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-snooker-aim.png) · [xcui-r3-planning-v63-snooker-solved](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-snooker-solved.png) · [xcui-r3-planning-r3-snooker-solve-requested](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-r3-snooker-solve-requested.png) · [xcui-r3-planning-v63-snooker-observe](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-snooker-observe.png) · [xcui-r3-planning-v63-snooker-before](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-planning-v63-snooker-before.png) · [xcui-r3-defense-v8-complete-snooker-back-to-edit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-complete-snooker-back-to-edit.png) · [xcui-r3-defense-v8-complete-snooker-observation-menu](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-complete-snooker-observation-menu.png) · [xcui-r3-defense-v8-complete-snooker-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-complete-snooker-3d.png) · [xcui-r3-defense-v8-complete-snooker](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-complete-snooker.png) · [xcui-r3-defense-v8-high-difficulty-back-to-edit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-high-difficulty-back-to-edit.png) · [xcui-r3-defense-v8-high-difficulty-observation-menu](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-high-difficulty-observation-menu.png) · [xcui-r3-defense-v8-high-difficulty-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-high-difficulty-3d.png) · [xcui-r3-defense-v8-high-difficulty](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-high-difficulty.png) · [xcui-r3-defense-v8-no-solution-back-to-edit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-no-solution-back-to-edit.png) · [xcui-r3-defense-v8-no-solution-observation-menu](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-no-solution-observation-menu.png) · [xcui-r3-defense-v8-no-solution-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-no-solution-3d.png) · [xcui-r3-defense-v8-no-solution](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r3-defense-v8-no-solution.png) · [xcui-r4-remaining-r6-snooker-replay](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-snooker-replay.png) · [xcui-r4-remaining-r6-snooker-next](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-snooker-next.png) · [xcui-r4-remaining-r6-snooker-recovered](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-snooker-recovered.png) · [xcui-r4-remaining-r6-snooker-blocker-moved](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-snooker-blocker-moved.png) · [xcui-r4-remaining-r6-snooker-no-solution](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-snooker-no-solution.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 目标球/摆球 | 顶部 | 2D，3D禁用 | 目标选择与摆球手势分工 |
| 清除约束 | 顶部橡皮 | 已有选择 | 清目标选择 |
| 球库/拖球 | 底部/台面 | 2D | 改变球形 |
| 求解/下一解 | 左下 | 可求解/多解 | 求防守路线及换解 |
| 打点/力度 | 右侧 | 有解可调 | 调整当前解 |
| 击球/上一杆/回放 | 右下 | 各自can条件 | 试打/恢复/重播 |
| 网格/清空桌面/恢复默认 | 更多 | 无求解范围组 | 显示/清球/恢复 |
| 2D/3D与观察 | 导航/3D底部 | 无目标袋观察项时不补造 | 相机 |

待补：已补 2D/3D 的无解、完全斯诺克、高难度可行解、对象观察及回编辑；求解/击球/恢复已有连续图。已真实移动障碍恢复6个候选、切下一解并击球回放。

### P09 翻袋解球（旧称翻袋解球器）

模式：当前源码与 09-15 小屏复用图：2D / 3D；初轮 iPad 旧包固定 2D。源码：[BankShotView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/BankShotView.swift)。

截图：[40-ipad-bank-unsolved](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/40-ipad-bank-unsolved.png) · [41-ipad-bank-solved](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/41-ipad-bank-solved.png) · [42-ipad-bank-free](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/42-ipad-bank-free.png) · [43-ipad-bank-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/43-ipad-bank-more.png) · [reuse-bankshot-3d-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-bankshot-3d-spin.png) · [reuse-bankshot-3d-aim](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-bankshot-3d-aim.png) · [reuse-bankshot-3d-overview](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-bankshot-3d-overview.png) · [reuse-bankshot-2d-before](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-bankshot-2d-before.png) · [xcui-r4-completion-bankBlank-table-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-bankBlank-table-released.png) · [xcui-r4-completion-bankBlank-wheel-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-bankBlank-wheel-released.png) · [xcui-r4-completion-bankBlank-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-bankBlank-ready.png) · [xcui-r4-core-bankshot-2d-undo](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-bankshot-2d-undo.png) · [xcui-r4-core-bankshot-3d-settled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-bankshot-3d-settled.png) · [xcui-r4-core-bankshot-3d-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-bankshot-3d-spin.png) · [xcui-r4-core-bankshot-3d-aim](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-bankshot-3d-aim.png) · [xcui-r4-core-bankshot-2d-returned](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-bankshot-2d-returned.png) · [xcui-r4-core-bankshot-3d-orbit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-bankshot-3d-orbit.png) · [xcui-r4-core-bankshot-3d-overview](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-bankshot-3d-overview.png) · [xcui-r4-core-bankshot-2d-before](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-bankshot-2d-before.png) · [xcui-r4-interactive-r4-bank-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-bank-more.png) · [xcui-r4-interactive-r4-bank-initial](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-bank-initial.png) · [xcui-r4-remaining-r6-bankshot-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-bankshot-restored.png) · [xcui-r4-remaining-r6-bankshot-minimum-power-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-bankshot-minimum-power-3d.png) · [xcui-r4-remaining-r6-bankshot-minimum-power](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-bankshot-minimum-power.png) · [xcui-r4-hold-bankBlank-table.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-bankBlank-table.held.png) · [xcui-r4-hold-bankBlank-wheel.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-bankBlank-wheel.held.png) · [xcui-r4-newer-solver-markers-20260915-bankshot-3d-orbit-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-bankshot-3d-orbit-402.png) · [xcui-r4-newer-solver-markers-20260915-bankshot-3d-spin-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-bankshot-3d-spin-402.png) · [xcui-r4-newer-solver-markers-20260915-bankshot-2d-returned-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-bankshot-2d-returned-402.png) · [xcui-r4-newer-solver-markers-20260915-bankshot-3d-overview-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-bankshot-3d-overview-402.png) · [xcui-r4-newer-solver-markers-20260915-bankshot-2d-undo-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-bankshot-2d-undo-402.png) · [xcui-r4-newer-solver-markers-20260915-bankshot-3d-settled-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-bankshot-3d-settled-402.png) · [xcui-r4-newer-solver-markers-20260915-bankshot-2d-before-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-bankshot-2d-before-402.png) · [xcui-r4-newer-solver-markers-20260915-bankshot-3d-aim-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-bankshot-3d-aim-402.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 求解/自由 | 顶部 | 未播放 | 切换求解与自主击球 |
| 自动/1库/2库/3库 | 顶部 | 仅求解模式 | 筛选库数 |
| 选目标袋 | 台面袋口 | 可操作时 | 触发相应翻袋求解 |
| 母球/黑8位置及障碍球库 | 台面/底部 | 按固定球和障碍球权限 | 摆形、增加/撤下障碍球 |
| 下一解 | 左侧 | 存在备选 | 切换方案 |
| 恢复球形 | 左侧 | 自由模式且有快照 | 恢复求解时球形 |
| 瞄准微调 | 左侧 | 自由模式 | 调方向 |
| 打点/力度 | 右侧 | 自由或有解可调 | 参数调整；求解态为草稿重预测 |
| 击打/击球/上一杆/回放 | 右侧 | 随模式与can条件变化 | 执行/恢复/重播 |
| 原理说明 | 更多 | 任意可打开时 | 只读说明 |
| 网格/瞄准特写/恢复默认 | 更多 | 按功能条件 | 显示偏好与默认球形 |
| 2D/3D 切换（本轮源码新增核对） | 右上导航 | 切换时关闭打点面板 | 切换观察模式；3D 禁止台面摆球/选袋/拖瞄准 |
| 视角菜单与回到瞄准 | 3D 底部 | 播放时禁用；返回瞄准按 canObserveCurrentAim | 按对象观察；球库在 3D 隐藏 |
| 3D 打点/力度/击球/下一解 | 透视布局两侧 | 按求解与播放状态 | 手动参数和求解能力延续；底部提示摆球请切回2D |

待补：已补求解/自由、库数、更多与原理、2D/3D、打点和精调特写、击球停稳与恢复。新版“翻袋解球”及线条样式用另一次测试原图单列；力度1.0后的恢复图明确出现“该袋暂无翻袋解”、击打禁用。

### P10 颗星解球（旧称反射解球器）

模式：当前源码与 09-15 小屏复用图：2D / 3D；初轮 iPad 旧包固定 2D。源码：[DiamondSystemView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/DiamondSystemView.swift)。

截图：[44-ipad-diamond](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/44-ipad-diamond.png) · [reuse-reflection-3d-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-reflection-3d-spin.png) · [reuse-reflection-3d-aim](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-reflection-3d-aim.png) · [reuse-reflection-3d-overview](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-reflection-3d-overview.png) · [reuse-reflection-2d-before](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-reflection-2d-before.png) · [xcui-r4-completion-diamondAimed-table-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-diamondAimed-table-released.png) · [xcui-r4-completion-diamondAimed-wheel-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-diamondAimed-wheel-released.png) · [xcui-r4-completion-diamondAimed-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-diamondAimed-ready.png) · [xcui-r4-core-reflection-2d-undo](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-reflection-2d-undo.png) · [xcui-r4-core-reflection-3d-settled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-reflection-3d-settled.png) · [xcui-r4-core-reflection-3d-spin](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-reflection-3d-spin.png) · [xcui-r4-core-reflection-3d-aim](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-reflection-3d-aim.png) · [xcui-r4-core-reflection-2d-returned](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-reflection-2d-returned.png) · [xcui-r4-core-reflection-3d-orbit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-reflection-3d-orbit.png) · [xcui-r4-core-reflection-3d-overview](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-reflection-3d-overview.png) · [xcui-r4-core-reflection-2d-before](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-reflection-2d-before.png) · [xcui-r4-interactive-r4-reflection-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-reflection-more.png) · [xcui-r4-interactive-r4-reflection-initial](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-reflection-initial.png) · [xcui-r4-remaining-r6-reflection-restored](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-reflection-restored.png) · [xcui-r4-remaining-r6-reflection-minimum-power-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-reflection-minimum-power-3d.png) · [xcui-r4-remaining-r6-reflection-minimum-power](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r6-reflection-minimum-power.png) · [xcui-r4-hold-diamondAimed-wheel.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-diamondAimed-wheel.held.png) · [xcui-r4-hold-diamondAimed-table.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-diamondAimed-table.held.png) · [xcui-r4-newer-solver-markers-20260915-reflection-3d-overview-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-reflection-3d-overview-402.png) · [xcui-r4-newer-solver-markers-20260915-reflection-2d-returned-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-reflection-2d-returned-402.png) · [xcui-r4-newer-solver-markers-20260915-reflection-3d-orbit-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-reflection-3d-orbit-402.png) · [xcui-r4-newer-solver-markers-20260915-reflection-3d-settled-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-reflection-3d-settled-402.png) · [xcui-r4-newer-solver-markers-20260915-reflection-2d-before-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-reflection-2d-before-402.png) · [xcui-r4-newer-solver-markers-20260915-reflection-3d-spin-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-reflection-3d-spin-402.png) · [xcui-r4-newer-solver-markers-20260915-reflection-3d-aim-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-reflection-3d-aim-402.png) · [xcui-r4-newer-solver-markers-20260915-reflection-2d-undo-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-solver-markers-20260915-reflection-2d-undo-402.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 求解/自由 | 顶部 | 未播放 | 切换操作方式 |
| 自动/1库/2库/3库 | 顶部 | 求解模式 | 筛选反射库数 |
| 摆球与障碍球库 | 台面/底部 | 可编辑时 | 母球经库接触目标；没有翻袋选袋入口 |
| 下一解/恢复球形 | 左侧 | 分别对应求解/自由快照 | 方案切换/恢复 |
| 瞄准轮/打点/力度 | 两侧 | 按模式与可调状态 | 调整方向及参数 |
| 击打/击球/上一杆/回放 | 右侧 | 按模式与can条件 | 执行/回退/重播 |
| 原理/网格/瞄准特写/恢复默认 | 更多 | 共享SolverStageChrome | 说明/显示/恢复 |
| 2D/3D 切换（本轮源码新增核对） | 右上导航 | 切换时关闭打点面板 | 切换观察模式；3D 禁止台面摆球/选袋/拖瞄准 |
| 视角菜单与回到瞄准 | 3D 底部 | 播放时禁用；返回瞄准按 canObserveCurrentAim | 按对象观察；球库在 3D 隐藏 |
| 3D 打点/力度/击球/下一解 | 透视布局两侧 | 按求解与播放状态 | 手动参数和求解能力延续；底部提示摆球请切回2D |

待补：已补求解/自由、库数、更多与原理、2D/3D、打点和精调特写、击球停稳与恢复。新版“颗星解球”及线条样式单列；没有翻袋的选袋能力，不能合并成同一业务模式。

### P11 角度与瞄准

模式：2D编辑 / 3D观察。源码：[AngleDynamicView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AngleDynamicView.swift)。

截图：[15-ipad-angle-dynamic-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/15-ipad-angle-dynamic-2d.png) · [16-ipad-angle-dynamic-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/16-ipad-angle-dynamic-3d.png) · [17-ipad-angle-dynamic-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/17-ipad-angle-dynamic-more.png) · [xcui-r4-core-v63-angleDynamic-grid-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-angleDynamic-grid-3d.png) · [xcui-r4-remaining-r5-dynamic-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-dynamic-more.png) · [xcui-r4-remaining-r5-dynamic-metrics-scroll](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-dynamic-metrics-scroll.png) · [xcui-r4-remaining-r5-dynamic-drag](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-dynamic-drag.png) · [xcui-r4-remaining-r5-dynamic-palette-added](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-dynamic-palette-added.png) · [xcui-r4-newer-output-v63-angle-dynamic-returned-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-output-v63-angle-dynamic-returned-402.png) · [xcui-r4-newer-output-v63-angle-dynamic-returned-375](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-output-v63-angle-dynamic-returned-375.png) · [xcui-r4-newer-output-v63-angle-dynamic-zoom-375](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-output-v63-angle-dynamic-zoom-375.png) · [xcui-r4-newer-output-v63-angle-dynamic-3d-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-output-v63-angle-dynamic-3d-402.png) · [xcui-r4-newer-output-v63-angle-dynamic-baseline-375](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-output-v63-angle-dynamic-baseline-375.png) · [xcui-r4-newer-output-v63-angle-dynamic-baseline-402](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-output-v63-angle-dynamic-baseline-402.png) · [xcui-r4-newer-output-v63-angle-dynamic-3d-375](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-output-v63-angle-dynamic-3d-375.png) · [xcui-r4-newer-output-v63-angle-dynamic-orbit-375](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-output-v63-angle-dynamic-orbit-375.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 切角/厚度/d/R/横移mm/偏移% | 顶部指标行 | 按当前目标/袋 | 只读联动教学指标 |
| 拖母球/目标球 | 2D台面 | 允许拖动节点 | 改变几何关系 |
| 目标球/袋口选择 | 2D台面 | 点击 | 更新教学目标 |
| 球库添加/撤下/换目标 | 2D底部 | 按球状态 | 教学球形编辑 |
| 2D/3D | 右上 | 可切换 | 相机 |
| 全桌/母球/目标球/目标袋 | 3D视角菜单 | 对象有效 | 观察；无回到瞄准任务 |
| 台面网格 | 更多 | 显示 | 共享偏好 |
| 常驻教学提示 | 台面下方 | 当前教学状态 | 只读，不是短时Toast |

待补：已补教学指标、台面 2D/3D、对象观察与新版线条；球库、拖动、指标滚动和更多见本轮补跑。随机球形触发的所有几何提示不视为独立漏页。

### P12 分离角图谱

模式：2D编辑 / 3D观察；八档高低杆比较。源码：[SeparationAngleAtlasView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SeparationAngleAtlasView.swift)。

截图：[18-ipad-separation-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/18-ipad-separation-2d.png) · [19-ipad-separation-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/19-ipad-separation-3d.png) · [reuse-v63-separationAngleAtlas-3d-single-track](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-separationAngleAtlas-3d-single-track.png) · [reuse-v63-separationAngleAtlas-3d-all](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-separationAngleAtlas-3d-all.png) · [xcui-r1-a15-separation-angle-atlas-default](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a15-separation-angle-atlas-default.png) · [xcui-r1-a15-separation-angle-atlas](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a15-separation-angle-atlas.png) · [xcui-r4-core-v63-separationAngleAtlas-grid-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-separationAngleAtlas-grid-3d.png) · [xcui-r4-core-v63-separationAngleAtlas-2d-returned](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-separationAngleAtlas-2d-returned.png) · [xcui-r4-core-v63-separationAngleAtlas-3d-track-off](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-separationAngleAtlas-3d-track-off.png) · [xcui-r4-core-v63-separationAngleAtlas-3d-all](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-separationAngleAtlas-3d-all.png) · [xcui-r4-interactive-v63-separationAngleAtlas-3d-single-track](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-v63-separationAngleAtlas-3d-single-track.png) · [xcui-r4-interactive-v63-separationAngleAtlas-2d-returned](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-v63-separationAngleAtlas-2d-returned.png) · [xcui-r4-interactive-v63-separationAngleAtlas-3d-track-off](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-v63-separationAngleAtlas-3d-track-off.png) · [xcui-r4-interactive-v63-separationAngleAtlas-3d-all](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-v63-separationAngleAtlas-3d-all.png) · [xcui-r4-newer-atlas-cue-20260915-separation-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-atlas-cue-20260915-separation-3d.png) · [xcui-r4-newer-atlas-cue-20260915-separation-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-atlas-cue-20260915-separation-2d.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 八档高低杆轨迹开关 | 左侧八个小打点盘 | 至少保留一档 | 选择对比轨迹，不是连续方向尺 |
| 力度 | 右侧 | 可调时 | 联动八档模拟 |
| 切角/力度/已选档数 | 顶部 | 当前对比状态 | 只读指标 |
| 拖球/选目标/选袋/球库 | 2D台面与底部 | 宿主允许 | 修改实验球形 |
| 2D/3D与对象观察 | 导航/3D底部 | 按模式 | 只观察 |
| 网格 | 更多 | 显示 | 共享偏好 |

待补：已补手机 2D/3D、八档/单档轨迹、力度与网格菜单；新版球杆图单列。44pt 命中尺寸断言的浮点误差在测试副本加容差后复跑通过，不改产品控件。

### P13 加塞吃库图谱

模式：2D编辑 / 3D观察；八档左右塞比较。源码：[CushionEnglishAtlasView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/CushionEnglishAtlasView.swift)。

截图：[20-ipad-cushion-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/20-ipad-cushion-2d.png) · [21-ipad-cushion-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/21-ipad-cushion-3d.png) · [reuse-v63-cushionEnglishAtlas-3d-single-track](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-cushionEnglishAtlas-3d-single-track.png) · [reuse-v63-cushionEnglishAtlas-3d-all](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/reuse-v63-cushionEnglishAtlas-3d-all.png) · [xcui-r1-a17-cushion-english-atlas-default](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a17-cushion-english-atlas-default.png) · [xcui-r1-a17-cushion-english-atlas](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a17-cushion-english-atlas.png) · [xcui-r4-core-v63-cushionEnglishAtlas-grid-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-cushionEnglishAtlas-grid-3d.png) · [xcui-r4-core-v63-cushionEnglishAtlas-2d-returned](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-cushionEnglishAtlas-2d-returned.png) · [xcui-r4-core-v63-cushionEnglishAtlas-3d-track-off](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-cushionEnglishAtlas-3d-track-off.png) · [xcui-r4-core-v63-cushionEnglishAtlas-3d-all](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-v63-cushionEnglishAtlas-3d-all.png) · [xcui-r4-interactive-v63-cushionEnglishAtlas-3d-height-adjusted](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-v63-cushionEnglishAtlas-3d-height-adjusted.png) · [xcui-r4-interactive-v63-cushionEnglishAtlas-3d-single-track](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-v63-cushionEnglishAtlas-3d-single-track.png) · [xcui-r4-interactive-v63-cushionEnglishAtlas-2d-returned](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-v63-cushionEnglishAtlas-2d-returned.png) · [xcui-r4-interactive-v63-cushionEnglishAtlas-3d-track-off](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-v63-cushionEnglishAtlas-3d-track-off.png) · [xcui-r4-interactive-v63-cushionEnglishAtlas-3d-all](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-v63-cushionEnglishAtlas-3d-all.png) · [xcui-r4-newer-atlas-cue-20260915-cushion-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-atlas-cue-20260915-cushion-2d.png) · [xcui-r4-newer-atlas-cue-20260915-cushion-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-atlas-cue-20260915-cushion-3d.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 八档左右塞轨迹开关 | 左侧小打点盘 | 至少留一档 | 选择轨迹对比 |
| 高低杆打点面板 | 右侧打点入口 | 本页限制对应分量 | 选择高低杆，不能把八档塞量当同一控件 |
| 力度 | 右侧 | 可调时 | 更新对比结果 |
| 切角/打点/可加塞/已选档数 | 顶部 | 当前实验 | 只读教学指标 |
| 拖球/换目标/选袋/球库 | 2D台面与底部 | 可编辑时 | 实验球形 |
| 2D/3D与对象观察 | 导航/3D底部 | 按模式 | 相机 |
| 网格 | 更多 | 显示 | 共享偏好 |

待补：已补手机 2D/3D、八档/单档、力度、高低杆面板及网格；新版球杆图单列。八种左右塞轨迹开关与高低杆面板是两类能力。

### P14 2D 角度训练

模式：固定2D；20题 / 自由练习。源码：[SceneAimingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SceneAimingView.swift)。

截图：[05-angle-settings-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/05-angle-settings-ready.png) · [xcui-r1-s5-05-aiming2d-keypad-overlay](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-s5-05-aiming2d-keypad-overlay.png) · [xcui-r1-s5-04-aiming2d-assist-ghost-dot](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-s5-04-aiming2d-assist-ghost-dot.png) · [xcui-r1-s5-03-aiming2d-layout](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-s5-03-aiming2d-layout.png) · [xcui-r4-completion-r4-angle-2D-completed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r4-angle-2D-completed.png) · [xcui-r4-completion-r4-angle-2D-feedback-20](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r4-angle-2D-feedback-20.png) · [xcui-r4-completion-r4-angle-2D-feedback-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r4-angle-2D-feedback-1.png) · [xcui-r4-completion-r4-angle-2D-setup](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r4-angle-2D-setup.png) · [xcui-r4-completion-r5-angle-free-question](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-free-question.png) · [xcui-r4-completion-r5-angle-free-settings](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-free-settings.png) · [xcui-r4-completion-r5-angle-type-8](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-type-8.png) · [xcui-r4-completion-r5-angle-type-7](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-type-7.png) · [xcui-r4-completion-r5-angle-type-6](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-type-6.png) · [xcui-r4-completion-r5-angle-type-5](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-type-5.png) · [xcui-r4-completion-r5-angle-type-4](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-type-4.png) · [xcui-r4-completion-r5-angle-type-3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-type-3.png) · [xcui-r4-completion-r5-angle-type-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-type-2.png) · [xcui-r4-completion-r5-angle-type-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-type-1.png) · [xcui-r4-completion-r5-angle-type-0](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-angle-type-0.png) · [xcui-r4-interactive-r4-angle-2D-feedback-20](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-angle-2D-feedback-20.png) · [xcui-r4-interactive-r4-angle-2D-feedback-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-angle-2D-feedback-1.png) · [xcui-r4-interactive-r4-angle-2D-setup](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-angle-2D-setup.png) · [xcui-r4-interactive-w7-c23-08-scene-aiming-compact](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-w7-c23-08-scene-aiming-compact.png) · [xcui-r4-interactive-w7-c23-02-scene-aiming-full](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-w7-c23-02-scene-aiming-full.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 训练设置：20题/自由练习 | 初入设置sheet | 未开始或重新设置 | 训练规则 |
| 训练类型 | 设置sheet | 随机/距离角度题型 | 出题范围 |
| 台面网格 | 训练设置 | 共享显示项 | 显示偏好，与重新开始同sheet |
| 开始训练/重新开始 | 设置右上 | 是否已有题目 | 开始新轮 |
| 题数/目标袋/平均误差/限额 | 顶部 | 按题与权益 | 只读状态 |
| 辅助/隐藏 | 题面动作区 | 题目进行中允许时 | 显示瞄准辅助 |
| 答题/取消 | 动作区/键盘 | 未提交 | 打开/收起键盘 |
| 数字0–9/退格/提交 | 底部答题键盘 | 有效输入后可提交 | 提交角度答案 |
| 误差结果/下一题 | 答后反馈 | 提交完成 | 显示结果与换题 |
| 视角 | 仅3D | 键盘/反馈时可禁用 | 观察不改变试题；2D无此项 |
| 装饰球库 | 仅2D底部 | 显示分支 | 无编辑权限 |

待补：已补题面、辅助线、键盘、反馈、完整 20 题总结、训练类型与自由练习、额度大卡和紧凑提示。成绩保存错误目前只有源码；不算真实异常画面。

### P15 3D 角度训练

模式：固定3D；20题 / 自由练习。源码：[SceneAimingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SceneAimingView.swift)。

截图：[22-ipad-angle3d-settings](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/22-ipad-angle3d-settings.png) · [23-ipad-angle3d-question](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/23-ipad-angle3d-question.png) · [24-ipad-angle3d-keypad](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/24-ipad-angle3d-keypad.png) · [25-ipad-angle3d-feedback](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/25-ipad-angle3d-feedback.png) · [xcui-r1-inventory-angle-feedback-q3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-angle-feedback-q3.png) · [xcui-r1-v57-framed-keypad-q3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v57-framed-keypad-q3.png) · [xcui-r1-v57-framed-q3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v57-framed-q3.png) · [xcui-r1-inventory-angle-feedback-q2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-angle-feedback-q2.png) · [xcui-r1-v57-framed-keypad-q2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v57-framed-keypad-q2.png) · [xcui-r1-v57-framed-q2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v57-framed-q2.png) · [xcui-r1-inventory-angle-feedback-q1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-angle-feedback-q1.png) · [xcui-r1-v57-framed-keypad-q1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v57-framed-keypad-q1.png) · [xcui-r1-v57-framed-q1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v57-framed-q1.png) · [xcui-r1-v63-angleTraining-observe-aim](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-angleTraining-observe-aim.png) · [xcui-r1-v63-angleTraining-observe-pocket](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-angleTraining-observe-pocket.png) · [xcui-r1-v63-angleTraining-observe-target](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-angleTraining-observe-target.png) · [xcui-r1-v63-angleTraining-observe-cue](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-angleTraining-observe-cue.png) · [xcui-r1-v63-angleTraining-observe-table](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-angleTraining-observe-table.png) · [xcui-r1-v63-angleTraining-observation-menu](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-angleTraining-observation-menu.png) · [xcui-r4-completion-r4-angle-3D-completed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r4-angle-3D-completed.png) · [xcui-r4-completion-r4-angle-3D-feedback-20](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r4-angle-3D-feedback-20.png) · [xcui-r4-completion-r4-angle-3D-feedback-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r4-angle-3D-feedback-1.png) · [xcui-r4-completion-r4-angle-3D-setup](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r4-angle-3D-setup.png) · [xcui-r4-interactive-r4-angle-3D-feedback-20](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-angle-3D-feedback-20.png) · [xcui-r4-interactive-r4-angle-3D-feedback-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-angle-3D-feedback-1.png) · [xcui-r4-interactive-r4-angle-3D-setup](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-angle-3D-setup.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 训练设置：20题/自由练习 | 初入设置sheet | 未开始或重新设置 | 训练规则 |
| 训练类型 | 设置sheet | 随机/距离角度题型 | 出题范围 |
| 台面网格 | 训练设置 | 共享显示项 | 显示偏好，与重新开始同sheet |
| 开始训练/重新开始 | 设置右上 | 是否已有题目 | 开始新轮 |
| 题数/目标袋/平均误差/限额 | 顶部 | 按题与权益 | 只读状态 |
| 辅助/隐藏 | 题面动作区 | 题目进行中允许时 | 显示瞄准辅助 |
| 答题/取消 | 动作区/键盘 | 未提交 | 打开/收起键盘 |
| 数字0–9/退格/提交 | 底部答题键盘 | 有效输入后可提交 | 提交角度答案 |
| 误差结果/下一题 | 答后反馈 | 提交完成 | 显示结果与换题 |
| 视角 | 仅3D | 键盘/反馈时可禁用 | 观察不改变试题；2D无此项 |
| 装饰球库 | 仅2D底部 | 显示分支 | 无编辑权限 |

待补：已补五种相机动作、题面/键盘/反馈及完整 20 题总结。设置组件与 2D 共用但保留 3D 宿主图；免费入口会打开 Pro 弹层（P32），Pro 用户绕过题数额度；不能据共用视图分支虚构正常可达的3D免费额度页。成绩保存异常为源码边界。

### P16 2D 瞄准点训练

模式：由路由固定2D或3D。源码：[AimPointSceneTrainingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointSceneTrainingView.swift)。

截图：[28-ipad-aimpoint2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/28-ipad-aimpoint2d.png) · [xcui-r1-aim-point-2D-next-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-2D-next-1.png) · [xcui-r1-aim-point-2D-submitted-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-2D-submitted-1.png) · [xcui-r1-aim-point-2D-adjusted-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-2D-adjusted-1.png) · [xcui-r1-aim-point-2D-aiming-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-2D-aiming-1.png) · [xcui-r4-completion-aimpoint2d-table-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-aimpoint2d-table-released.png) · [xcui-r4-completion-aimpoint2d-wheel-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-aimpoint2d-wheel-released.png) · [xcui-r4-completion-aimpoint2d-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-aimpoint2d-ready.png) · [xcui-r4-interactive-w7-c23-07-aimpoint-scene-compact](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-w7-c23-07-aimpoint-scene-compact.png) · [xcui-r4-interactive-w7-c23-04-aimpoint-scene-full](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-w7-c23-04-aimpoint-scene-full.png) · [xcui-r4-hold-aimpoint2d-table.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-aimpoint2d-table.held.png) · [xcui-r4-hold-aimpoint2d-wheel.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-aimpoint2d-wheel.held.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 题数/均差/剩余额度 | 顶部 | 会话进行 | 只读状态 |
| 瞄准微调 | 左侧刻度轮 | 作答中 | 改变作答方向 |
| 台面瞄准手势 | 2D台面 | 作答中 | 修改瞄准；3D台面用于相机 |
| 瞄准特写 | 操作时浮层 | 偏好开启且相应手势活跃 | 辅助精调 |
| 提交 | 右下 | 作答中 | 提交瞄准方向 |
| 误差mm/偏厚偏薄 | 反馈 | 提交后 | 评分 |
| 延迟自动验证击球 | 台面 | 提交后阶段 | 按用户方向播放物理验证 |
| 重试验证/下一题 | 错误或反馈区 | 对应阶段 | 重试/换题 |
| 视角 | 仅3D | 非提交验证锁定阶段 | 相机 |
| 网格/瞄准特写 | 更多 | 显示偏好 | 共享设置 |
| 装饰球库 | 仅2D | 题面 | 只读无编辑 |

待补：已补答题精调、按住时特写、提交/物理验证/下一题、额度大卡和紧凑提示。没有用户可选的难度或球号设置；保存失败和验证重试尚无真实故障截图。

### P17 3D 瞄准点训练

模式：由路由固定2D或3D。源码：[AimPointSceneTrainingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointSceneTrainingView.swift)。

截图：[26-ipad-aimpoint3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/26-ipad-aimpoint3d.png) · [27-ipad-aimpoint3d-verification](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/27-ipad-aimpoint3d-verification.png) · [xcui-r1-aim-point-3D-next-3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-next-3.png) · [xcui-r1-aim-point-3D-submitted-3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-submitted-3.png) · [xcui-r1-aim-point-3D-adjusted-3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-adjusted-3.png) · [xcui-r1-aim-point-3D-aiming-3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-aiming-3.png) · [xcui-r1-aim-point-3D-next-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-next-2.png) · [xcui-r1-aim-point-3D-submitted-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-submitted-2.png) · [xcui-r1-aim-point-3D-adjusted-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-adjusted-2.png) · [xcui-r1-aim-point-3D-aiming-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-aiming-2.png) · [xcui-r1-aim-point-3D-next-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-next-1.png) · [xcui-r1-aim-point-3D-submitted-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-submitted-1.png) · [xcui-r1-aim-point-3D-adjusted-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-adjusted-1.png) · [xcui-r1-aim-point-3D-aiming-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-aim-point-3D-aiming-1.png) · [xcui-r1-v63-aimPointTraining-observe-aim](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-aimPointTraining-observe-aim.png) · [xcui-r1-v63-aimPointTraining-observe-pocket](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-aimPointTraining-observe-pocket.png) · [xcui-r1-v63-aimPointTraining-observe-target](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-aimPointTraining-observe-target.png) · [xcui-r1-v63-aimPointTraining-observe-cue](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-aimPointTraining-observe-cue.png) · [xcui-r1-v63-aimPointTraining-observe-table](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-aimPointTraining-observe-table.png) · [xcui-r1-v63-aimPointTraining-observation-menu](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-v63-aimPointTraining-observation-menu.png) · [xcui-r4-completion-aimpoint3d-orbit-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-aimpoint3d-orbit-released.png) · [xcui-r4-completion-aimpoint3d-wheel-released](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-aimpoint3d-wheel-released.png) · [xcui-r4-completion-aimpoint3d-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-aimpoint3d-ready.png) · [xcui-r4-hold-aimpoint3d-wheel.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-aimpoint3d-wheel.held.png) · [xcui-r4-hold-aimpoint3d-orbit.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-aimpoint3d-orbit.held.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 题数/均差/剩余额度 | 顶部 | 会话进行 | 只读状态 |
| 瞄准微调 | 左侧刻度轮 | 作答中 | 改变作答方向 |
| 台面瞄准手势 | 2D台面 | 作答中 | 修改瞄准；3D台面用于相机 |
| 瞄准特写 | 操作时浮层 | 偏好开启且相应手势活跃 | 辅助精调 |
| 提交 | 右下 | 作答中 | 提交瞄准方向 |
| 误差mm/偏厚偏薄 | 反馈 | 提交后 | 评分 |
| 延迟自动验证击球 | 台面 | 提交后阶段 | 按用户方向播放物理验证 |
| 重试验证/下一题 | 错误或反馈区 | 对应阶段 | 重试/换题 |
| 视角 | 仅3D | 非提交验证锁定阶段 | 相机 |
| 网格/瞄准特写 | 更多 | 显示偏好 | 共享设置 |
| 装饰球库 | 仅2D | 题面 | 只读无编辑 |

待补：已补五种相机动作、方向轮特写、3D 环绕时特写、三题作答验证；免费入口为 Pro 弹层（P32），不是3D题面额度卡。3D 台面拖动用于相机；保存/验证异常仅源码核对。

### P18 动作详情中的球桌

模式：嵌入式2D / 3D；多球形 / 逐杆演示。源码：[DrillSceneView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/DrillSceneView.swift)。

截图：[06-drill-detail-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/06-drill-detail-ready.png) · [xcui-r1-inventory-detail-3D-paused](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-3D-paused.png) · [xcui-r1-inventory-detail-3D-playing-revealed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-3D-playing-revealed.png) · [xcui-r1-inventory-detail-3D-playing-hidden](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-3D-playing-hidden.png) · [xcui-r1-inventory-detail-3D-playing-visible](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-3D-playing-visible.png) · [xcui-r1-inventory-detail-3D-idle](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-3D-idle.png) · [xcui-r1-inventory-detail-2D-paused](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-2D-paused.png) · [xcui-r1-inventory-detail-2D-playing-revealed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-2D-playing-revealed.png) · [xcui-r1-inventory-detail-2D-playing-hidden](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-2D-playing-hidden.png) · [xcui-r1-inventory-detail-2D-playing-visible](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-2D-playing-visible.png) · [xcui-r1-inventory-detail-2D-idle](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-detail-2D-idle.png) · [xcui-r4-completion-v63-detail-manual02-completed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-v63-detail-manual02-completed.png) · [xcui-r4-completion-v63-detail-manual02-first-boundary](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-v63-detail-manual02-first-boundary.png) · [xcui-r4-completion-v63-detail-manual01-completed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-v63-detail-manual01-completed.png) · [xcui-r4-completion-v63-detail-manual01-first-boundary](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-v63-detail-manual01-first-boundary.png) · [xcui-r4-completion-v63-detail-formation1-restored-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-v63-detail-formation1-restored-3d.png) · [xcui-r4-completion-v63-detail-formation2-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-v63-detail-formation2-3d.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 2D/3D | 嵌入球桌上沿 | 当前球桌 | 切换相机 |
| 全桌 | 球桌上沿 | 仅3D | 全桌构图 |
| 播放/暂停请求/继续 | 球桌左下 | 按播放阶段 | 源码为杆边界暂停，不是任意时刻停球 |
| 自动隐藏/点台面唤回 | 球桌控制层 | 播放中2秒隐去；点台面唤回 | 手机2D/3D已有连续状态取证；参数HUD不随按钮全隐 |
| 球形切换 | 球桌右下 | availableFormations>1 | 更换球形 |
| 当前杆号 | 球桌上沿 | 有序列 | 只读 |
| 打点力度HUD | 球桌下方 | 播放时有overlayData | 只读参数 |
| 上手试打 | 宿主详情底栏 | 权限允许 | 进入独立试打页 |

待补：已补 2D/3D 控件可见→自动隐藏→点台面唤回→杆末暂停；两组球形分别跑完 8 杆和 5 杆（共 13 杆），并补播放/暂停中切球形。参数 HUD 仍显示，不是所有信息都消失。

### P19 训练记录页中的球桌

模式：嵌入DrillSceneView。源码：[DrillRecordView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/DrillRecordView.swift)。

截图：[46-phone-record](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/46-phone-record.png) · [55-ipad-record-2d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/55-ipad-record-2d.png) · [56-ipad-record-3d](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/56-ipad-record-3d.png) · [57-ipad-record-playback](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/57-ipad-record-playback.png) · [xcui-r2-probe-r2-record-3D-paused](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-3D-paused.png) · [xcui-r2-probe-r2-record-3D-revealed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-3D-revealed.png) · [xcui-r2-probe-r2-record-3D-hidden](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-3D-hidden.png) · [xcui-r2-probe-r2-record-3D-playing](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-3D-playing.png) · [xcui-r2-probe-r2-record-3D-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-3D-ready.png) · [xcui-r2-probe-r2-record-2D-paused](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-2D-paused.png) · [xcui-r2-probe-r2-record-2D-revealed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-2D-revealed.png) · [xcui-r2-probe-r2-record-2D-hidden](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-2D-hidden.png) · [xcui-r2-probe-r2-record-2D-playing](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-2D-playing.png) · [xcui-r2-probe-r2-record-2D-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-record-2D-ready.png) · [xcui-r4-completion-r5-record-orbit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-record-orbit.png) · [xcui-r4-completion-r5-record-manual01](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-record-manual01.png) · [xcui-r4-completion-r5-record-manual02](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-record-manual02.png) · [xcui-r4-final-r7-record-long-drag-overview](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r7-record-long-drag-overview.png) · [xcui-r4-final-r7-record-small-orbit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r7-record-small-orbit.png) · [xcui-r4-final-r7-record-before-orbit](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r7-record-before-orbit.png) · [xcui-r4-verification-r5-record-manual01](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-record-manual01.png) · [xcui-r4-verification-r5-record-manual02](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-record-manual02.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 球桌2D/3D/全桌/播放/球形 | 训练内容区 | content存在 | 复用DrillSceneView |
| 计组/计次/结束等训练动作 | 宿主页面 | 训练会话 | 属于记录任务，不得替换成击球按钮 |

待补：已补独立记录宿主的 2D/3D 显隐与杆末暂停，球形切换已补；小幅右拖无明显环绕，大幅右拖触发父级总览，已复现并列为实际手势冲突。训练计组/结束仍属于宿主任务；不能用击球动作替代。

### P20 拍照建球形

模式：选四步：选图 / 标定 / 标球 / 确认。源码：[BallExtractionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BallExtraction/Views/BallExtractionView.swift)。

截图：[51-ipad-extraction-entry](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/51-ipad-extraction-entry.png) · [58-ipad-extract-confirm-fixture](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/58-ipad-extract-confirm-fixture.png) · [59-ipad-extract-destinations](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/59-ipad-extract-destinations.png) · [60-ipad-extract-photo-picker](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/60-ipad-extract-photo-picker.png) · [xcui-r2-probe-r2-photo-picker](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-probe-r2-photo-picker.png) · [xcui-r2-photo3-r2-photo-mark-empty](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-r2-photo-mark-empty.png) · [xcui-r2-photo3-r2-photo-calibrate-short](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-r2-photo-calibrate-short.png) · [xcui-r2-photo3-r2-photo-calibrate-long](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo3-r2-photo-calibrate-long.png) · [xcui-r2-photo4-r2-photo-back-to-mark](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-back-to-mark.png) · [xcui-r2-photo4-r2-photo-destinations-real-flow](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-destinations-real-flow.png) · [xcui-r2-photo4-r2-photo-confirm-real-flow](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-confirm-real-flow.png) · [xcui-r2-photo4-r2-photo-mark-redo](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-mark-redo.png) · [xcui-r2-photo4-r2-photo-mark-undo](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-mark-undo.png) · [xcui-r2-photo4-r2-photo-mark-two](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-mark-two.png) · [xcui-r2-photo4-r2-photo-mark-cue](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-mark-cue.png) · [xcui-r2-photo4-r2-photo-mark-empty](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-mark-empty.png) · [xcui-r2-photo4-r2-photo-calibrate-adjusted](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-calibrate-adjusted.png) · [xcui-r2-photo4-r2-photo-calibrate-short](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-calibrate-short.png) · [xcui-r2-photo4-r2-photo-calibrate-long](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r2-photo4-r2-photo-calibrate-long.png) · [xcui-r4-core-w4-extraction-04-after-drag-back](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-w4-extraction-04-after-drag-back.png) · [xcui-r4-core-w4-extraction-03-after-pulse](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-w4-extraction-03-after-pulse.png) · [xcui-r4-core-w4-extraction-02-after-place](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-w4-extraction-02-after-place.png) · [xcui-r4-core-w4-extraction-01-entry](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-core-w4-extraction-01-entry.png) · [xcui-r4-interactive-r4-photo-degenerate-corners](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-photo-degenerate-corners.png) · [xcui-r4-interactive-r4-photo-corner-moved](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-photo-corner-moved.png) · [xcui-r4-interactive-r4-photo-send-composer.cameraMode](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-photo-send-composer.cameraMode.png) · [xcui-r4-interactive-r4-photo-send-planthree.cameraMode](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-photo-send-planthree.cameraMode.png) · [xcui-r4-interactive-r4-photo-send-silu.cameraMode](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-photo-send-silu.cameraMode.png) · [xcui-r4-remaining-r5-photo-added](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-photo-added.png) · [xcui-r4-verification-r5-photo-removed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-photo-removed.png) · [xcui-r4-verification-r5-photo-renumbered](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-photo-renumbered.png) · [xcui-r4-verification-r5-photo-added](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-photo-added.png) · [xcui-r4-hold-loupe-request.held](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-hold-loupe-request.held.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 选择照片 | 第一步 | 尚无图片 | 系统选图 |
| 四角标定/桌面方向 | 第二步照片上 | 有图 | 几何校准 |
| 重新选图/下一步 | 第二步底部 | 标定有效才可前进 | 步骤切换 |
| 选球号/点照片标球/拖动微调/删除标记 | 第三步照片与球库 | 已标定 | 球号与位置编辑 |
| 确认台面拖球/改号/移除 | 第四步2D球桌 | 有球形 | 修正识别结果 |
| 撤销/重做 | 确认编辑工具 | 有历史 | 恢复编辑 |
| 送入自由走位/思路训练/打一走二想三 | 确认页送入菜单 | 桌上非空 | 把球形带入目标页 |
| 重新标记 | 确认页底部 | 已确认 | 返回标球 |

待补：已补真实选图→标定→标球→确认，长短库、拖动放大镜、退化四角禁用、撤销/重做、球库拖上/拖回，以及三目的地实际进入。改号/移除已补；不宣称照片几何识别精度验收。

### P21 批量出片台：建球形

模式：仅模拟器内容生产工具。源码：[BatchBallExtractionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchBallExtractionView.swift)。

截图：[52-ipad-batch-entry](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/52-ipad-batch-entry.png) · [53-ipad-batch-formations](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/53-ipad-batch-formations.png) · [xcui-r4-final-r5-batch-clone-picker](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r5-batch-clone-picker.png) · [xcui-r4-final-r5-batch-delete-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r5-batch-delete-confirm.png) · [xcui-r4-interactive-r4-batch-new-options](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-batch-new-options.png) · [xcui-r4-interactive-r4-batch-formations](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-batch-formations.png) · [xcui-r4-remaining-r4-batch-new-options](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r4-batch-new-options.png) · [xcui-r4-remaining-r4-batch-formations](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r4-batch-formations.png) · [xcui-r4-remaining-r5-batch-delete-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r5-batch-delete-confirm.png) · [xcui-r4-verification-r5-batch-clone-picker](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-batch-clone-picker.png) · [xcui-r4-verification-r5-batch-delete-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-batch-delete-confirm.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| Drill选择/截图选择 | 入口列表 | 模拟器 | 载入内容资产 |
| 读取已有球形/重做 | 球形列表 | 有存档 | 进入编辑，不等同保存 |
| 新增空台/克隆已有球形 | 新增菜单 | 可用来源 | 准备新球形 |
| 选图/四角标定/标球/确认 | 四步编辑区 | 选中图片 | 内容生产编辑 |
| 撤销/重做/改号/移除 | 确认台面 | 有对应状态 | 球形编辑 |
| 删除存档 | 长按已有球形 | 确认删除 | 文件写入；本轮未执行 |

待补：模拟器专用内容生产入口。新增空台、克隆与删除确认按真实存档补图；实际删除不执行。照片四步编辑复用 P20 的能力，但生产文件导出不冒充已验证。

### P22 批量出片台：编排求解

模式：仅模拟器；固定2D生产编辑。源码：[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift)。

截图：[54-ipad-batch-authoring](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/54-ipad-batch-authoring.png) · [xcui-r4-final-r5-batch-overwrite-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r5-batch-overwrite-confirm.png) · [xcui-r4-final-r5-batch-precise-position](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r5-batch-precise-position.png) · [xcui-r4-final-r5-batch-existing-author](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r5-batch-existing-author.png) · [xcui-r4-interactive-r4-batch-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-batch-more.png) · [xcui-r4-interactive-r4-batch-free](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-batch-free.png) · [xcui-r4-interactive-r4-batch-empty-authoring](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-batch-empty-authoring.png) · [xcui-r4-remaining-r4-batch-more](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r4-batch-more.png) · [xcui-r4-remaining-r4-batch-free](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r4-batch-free.png) · [xcui-r4-remaining-r4-batch-empty-authoring](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-remaining-r4-batch-empty-authoring.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 落区/落点/过点/摆球/自由 | 顶部 | 当前生产模式 | 手势工具 |
| 矩形/圆 | 顶部第二组 | 落区工具 | 约束形状 |
| 清除约束/求解/同步状态 | 顶部与台面 | 前置条件 | 求解及同步 |
| 点换/辅助线/清除线 | 台面工具 | 对应模式 | 对象与辅助几何编辑 |
| 球位四向0.5毫米微调 | 选球工具 | 选球时 | 精确编辑 |
| 打点/力度/瞄准轮 | 两侧 | 对应模式 | 击球参数 |
| 击球/上一杆/回放 | 动作列 | 对应能力 | 推进/回退/重播 |
| 播放当前录制序列/回上一杆球形 | 底部 | 已有序列 | 预览与恢复 |
| 保存·选下张图/保存·下个drill | 底部 | 可保存 | 写入内容文件；本轮不执行 |
| 左右塞/基础走位/重打/网格 | 更多 | 按源码分支 | 求解范围与显示 |

待补：模拟器专用编排入口。已补工具区、自由模式和更多；已采保存覆盖确认；四向精确球位控件未展开，仅源码确认。未保存或覆盖跨项目内容，完整录制导出属于内容生产验收。

### P23 设置中的球桌相关偏好

模式：全局偏好；不是页内全部工具。源码：[SettingsView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/SettingsView.swift)。

截图：[08-settings-ready](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/08-settings-ready.png) · [xcui-r4-completion-settings-five-games-light](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-settings-five-games-light.png) · [xcui-r4-interactive-frame-rate-settings](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-frame-rate-settings.png) · [xcui-r4-interactive-r4-settings-6](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-settings-6.png) · [xcui-r4-interactive-r4-settings-5](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-settings-5.png) · [xcui-r4-interactive-r4-settings-4](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-settings-4.png) · [xcui-r4-interactive-r4-settings-3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-settings-3.png) · [xcui-r4-interactive-r4-settings-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-settings-2.png) · [xcui-r4-interactive-r4-settings-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-settings-1.png) · [xcui-r4-interactive-r4-settings-0](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-settings-0.png) · [xcui-r4-verification-settings-five-games-expanded](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-settings-five-games-expanded.png) · [xcui-r4-verification-settings-five-games-light](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-settings-five-games-light.png) · [xcui-r4-newer-build-settings-after-light](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-build-settings-after-light.png) · [xcui-r4-newer-build-settings-after-dark](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-newer-build-settings-after-dark.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 外观浅深色 | 设置 | 全局 | 持久偏好 |
| 球桌帧率30/60/120 | 设置 | 设备能力约束 | 性能偏好 |
| 击球音效 | 设置 | 全局 | 声音偏好 |
| 90°分离角辅助线 | 设置教学辅助 | 全局 | 共享显示 |
| 每日清台默认玩法 | 设置 | 仅下一新局 | 持久偏好 |
| 球房/球桌/台呢/球/球杆外观 | 设置外观相关入口 | 按当前源码版本与设备 | 持久外观；入口归全局设置，素材设计不在本次按键盘点范围 |
| 背景音乐 | 设置声音 | 新增；默认关闭，与击球音效分别保存 | 练习页可见时播放；不在台面增加常驻按钮 |

待补：已补相关设置的连续滚动位置、帧率、清台默认玩法；新版背景音乐与音效独立开关有浅/深色来源图。外观素材本身不是这次按键重组对象。

### P24 瞄准原理（关联教学页）

模式：文档与示意图；无球桌相机。源码：[AimingPrincipleView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimingPrincipleView.swift)。

截图：[xcui-r1-a09-aiming-principle-scrolled3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a09-aiming-principle-scrolled3.png) · [xcui-r1-a09-aiming-principle-scrolled2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a09-aiming-principle-scrolled2.png) · [xcui-r1-a09-aiming-principle-scrolled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a09-aiming-principle-scrolled.png) · [xcui-r1-a09-aiming-principle](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a09-aiming-principle.png) · [xcui-r4-interactive-r4-principle-cta-destination](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-principle-cta-destination.png) · [xcui-r4-interactive-r4-principle-footer](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-principle-footer.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 名词/切角/公式/假想球/厚薄图解 | 滚动文档 | 阅读态 | 解释训练图中的线条和点 |
| 瞄准方法互链 | 正文 | 阅读态 | 进入方法页 |
| 去练一练 | 页末 | 阅读态 | 进入角度预测 |

待补：已补首屏至页尾、关联入口与练习 CTA。源码为阅读文档，没有教学滑杆或重播按钮，先前泛化缺口已撤销。

### P25 瞄准方法（关联教学页）

模式：共享切角与局部试瞄角。源码：[AimingMethodsView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimingMethodsView.swift)。

截图：[xcui-r1-a13-aiming-methods-scrolled4](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a13-aiming-methods-scrolled4.png) · [xcui-r1-a13-aiming-methods-scrolled3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a13-aiming-methods-scrolled3.png) · [xcui-r1-a13-aiming-methods-scrolled2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a13-aiming-methods-scrolled2.png) · [xcui-r1-a13-aiming-methods-scrolled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a13-aiming-methods-scrolled.png) · [xcui-r1-a13-aiming-methods](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a13-aiming-methods.png) · [xcui-r4-interactive-r4-methods-contact-play](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-methods-contact-play.png) · [xcui-r4-interactive-r4-methods-phi-max](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-methods-phi-max.png) · [xcui-r4-interactive-r4-methods-phi-min](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-methods-phi-min.png) · [xcui-r4-interactive-r4-methods-theta-max](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-methods-theta-max.png) · [xcui-r4-interactive-r4-methods-theta-min](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-methods-theta-min.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 切角θ | 页顶控件条 | 5°–75° | 联动各方法示意与读数 |
| 试瞄角φ | 管道法局部面板 | 5°–75° | 观察相交/相离/相切；切角改变时跟随 |
| 局部θ读数 | 各方法章节 | 控件滚出视野时仍可读 | 只读状态 |
| 方法/对照表互链 | 正文及页末 | 阅读态 | 关联教学导航 |

待补：已补切角 θ 与试瞄角 φ 两个独立滑杆端点和各教学章节；不能合并为含义不明的单个调节器。

### P26 瞄准修正（关联教学页）

模式：参数联动引擎示意。源码：[AimingCorrectionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimingCorrectionView.swift)。

截图：[xcui-r1-a16-aiming-correction-scrolled4](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a16-aiming-correction-scrolled4.png) · [xcui-r1-a16-aiming-correction-scrolled3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a16-aiming-correction-scrolled3.png) · [xcui-r1-a16-aiming-correction-scrolled2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a16-aiming-correction-scrolled2.png) · [xcui-r1-a16-aiming-correction-scrolled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a16-aiming-correction-scrolled.png) · [xcui-r1-a16-aiming-correction](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a16-aiming-correction.png) · [xcui-r4-interactive-r4-correction-spinY-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-correction-spinY-2.png) · [xcui-r4-interactive-r4-correction-spinY-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-correction-spinY-1.png) · [xcui-r4-interactive-r4-correction-spinY-0](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-correction-spinY-0.png) · [xcui-r4-interactive-r4-correction-spinX-max](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-correction-spinX-max.png) · [xcui-r4-interactive-r4-correction-spinX-min](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-correction-spinX-min.png) · [xcui-r4-interactive-r4-correction-velocity-max](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-correction-velocity-max.png) · [xcui-r4-interactive-r4-correction-velocity-min](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-correction-velocity-min.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 力度 | 共享控件条 | 参数可编辑 | 重算各章节示意 |
| 高低杆档位 | 共享控件条 | 参数可编辑 | 改变接触杆法；影响可用左右塞范围 |
| 左右塞 | 共享控件条 | spinXMaxAbs不足时禁用 | 在允许范围内重算 |
| 计算中/状态/Δ读数 | 章节内 | snapshot/isComputing/statusText分支 | 反馈当前计算情况 |
| 图谱与练习导流 | 正文及页末 | 阅读态 | 进入对应实验与练习 |

待补：已补力度/左右塞端点与三个高低杆档位、各章节读数。教学计算参数不等于可执行击球命令；未穷举所有物理输入。

### P27 旋转与加塞（关联教学页）

模式：切角 × 接触旋转状态。源码：[SpinAndEnglishView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SpinAndEnglishView.swift)。

截图：[xcui-r1-a14-spin-and-english-scrolled5](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a14-spin-and-english-scrolled5.png) · [xcui-r1-a14-spin-and-english-scrolled4](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a14-spin-and-english-scrolled4.png) · [xcui-r1-a14-spin-and-english-scrolled3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a14-spin-and-english-scrolled3.png) · [xcui-r1-a14-spin-and-english-scrolled2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a14-spin-and-english-scrolled2.png) · [xcui-r1-a14-spin-and-english-scrolled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a14-spin-and-english-scrolled.png) · [xcui-r1-a14-spin-and-english](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a14-spin-and-english.png) · [xcui-r4-interactive-r4-spin-state-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-spin-state-2.png) · [xcui-r4-interactive-r4-spin-state-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-spin-state-1.png) · [xcui-r4-interactive-r4-spin-state-0](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-spin-state-0.png) · [xcui-r4-interactive-r4-spin-theta-max](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-spin-theta-max.png) · [xcui-r4-interactive-r4-spin-theta-min](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-spin-theta-min.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 切角θ | 页顶控件条 | 5°–75° | 改变教学球形及半球提示 |
| 旋转状态选择 | 三条分离路径章节 | 滑动/前旋/后旋 | 高亮对应示意路径 |
| 状态与示意角读数 | 示意图下 | 随选择变化 | 只读解释；教学折线不是实时求解结果 |
| 修正与图谱互链 | 正文及页末 | 阅读态 | 进一步实验 |

待补：已补切角端点、滑动/前旋/后旋三种示意状态及页尾关联入口。示意路径不是即时物理求解。

### P28 角度预测（几何测验）

模式：Canvas题面 / 输入 / 结果 / 额度。源码：[GeometricAngleQuizView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/GeometricAngleQuizView.swift)。

截图：[xcui-r1-s5-07-geoquiz-compact-keypad](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-s5-07-geoquiz-compact-keypad.png) · [xcui-r1-a12-geometric-quiz-scrolled2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a12-geometric-quiz-scrolled2.png) · [xcui-r1-a12-geometric-quiz-scrolled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a12-geometric-quiz-scrolled.png) · [xcui-r1-a12-geometric-quiz-reference](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a12-geometric-quiz-reference.png) · [xcui-r1-a12-geometric-quiz](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a12-geometric-quiz.png) · [xcui-r4-final-r6-geometric-reset-cancelled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r6-geometric-reset-cancelled.png) · [xcui-r4-final-r6-geometric-reset-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-final-r6-geometric-reset-confirm.png) · [xcui-r4-interactive-w7-c23-05-geometric-compact](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-w7-c23-05-geometric-compact.png) · [xcui-r4-interactive-w7-c23-01-geometric-full](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-w7-c23-01-geometric-full.png) · [xcui-r4-verification-r6-geometric-reset-confirm](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r6-geometric-reset-confirm.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 换题 | 画布下方 | 额度未耗尽 | 关闭输入并生成新题 |
| 显示/隐藏参考 | 画布下方 | 题面 | 改变几何参考显示 |
| 答题与数字键盘 | 动作区/底部HUD | 输入中且未出结果/未达额度 | 提交角度答案 |
| 近期表现 | 题面下方 | 输入时透明且禁用命中/AX | 保留布局占位避免题面移动 |
| 结果/下一题/额度入口 | 结果区域 | 结果及额度分支 | 反馈误差或进入下一题/订阅 |
| 重置统计 | 导航右侧 | 确认后清空 | 本轮不执行 |
| 保存错误重试 | 错误横幅 | 有保存错误 | 重试失败保存 |

待补：已补答题/键盘、参考、结果与近期表现、两种额度状态；重置统计确认及点外部取消已采。保存错误横幅保留源码边界。

### P29 瞄准点（拖假想球测验）

模式：Canvas拖动 / 提交 / 结果。源码：[AimPointTrainingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointTrainingView.swift)。

截图：[xcui-r1-inventory-legacy-aimpoint-next](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-legacy-aimpoint-next.png) · [xcui-r1-inventory-legacy-aimpoint-feedback](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-legacy-aimpoint-feedback.png) · [xcui-r1-inventory-legacy-aimpoint-question](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-inventory-legacy-aimpoint-question.png) · [xcui-r4-completion-r5-legacy-drag-result](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-legacy-drag-result.png) · [xcui-r4-completion-r5-legacy-drag-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-legacy-drag-1.png) · [xcui-r4-completion-r5-legacy-drag-0](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-completion-r5-legacy-drag-0.png) · [xcui-r4-interactive-w7-c23-06-aimpoint-training-compact](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-w7-c23-06-aimpoint-training-compact.png) · [xcui-r4-interactive-w7-c23-03-aimpoint-training-full](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-w7-c23-03-aimpoint-training-full.png) · [xcui-r4-verification-r5-legacy-drag-result](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-legacy-drag-result.png) · [xcui-r4-verification-r5-legacy-drag-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-legacy-drag-1.png) · [xcui-r4-verification-r5-legacy-drag-0](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r5-legacy-drag-0.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 拖假想球 | 图形区域 | 题目交互 | 修改用户偏移 |
| 切角与当前偏移 | 题目卡 | 答题中 | 只读题目和毫米读数 |
| 提交瞄准点 | 题目卡 | 题目存在 | 计算误差 |
| 误差与正确偏移 | 结果卡 | 有结果 | 显示偏厚/偏薄反馈 |
| 下一题/额度入口 | 结果卡 | 额度未尽/已尽 | 生成下一题或显示订阅入口 |

待补：已补拖假想球、偏移反馈、下一题与两种额度状态。所采拖动不宣称覆盖几何可达范围的所有端点；成绩保存失败只有源码。

### P30 瞄准点对照表

模式：教学示意与对照表。源码：[ContactPointTableView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/ContactPointTableView.swift)。

截图：[xcui-r1-a10-contact-point-scrolled2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a10-contact-point-scrolled2.png) · [xcui-r1-a10-contact-point-scrolled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a10-contact-point-scrolled.png) · [xcui-r1-a10-contact-point](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a10-contact-point.png) · [xcui-r4-interactive-r4-contact-footer-4](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-contact-footer-4.png) · [xcui-r4-interactive-r4-contact-footer-3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-contact-footer-3.png) · [xcui-r4-interactive-r4-contact-footer-2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-contact-footer-2.png) · [xcui-r4-interactive-r4-contact-footer-1](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-contact-footer-1.png) · [xcui-r4-interactive-r4-contact-footer-0](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-contact-footer-0.png) · [xcui-r4-interactive-r4-contact-distance-max](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-contact-distance-max.png) · [xcui-r4-interactive-r4-contact-distance-min](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-contact-distance-min.png) · [xcui-r4-interactive-r4-contact-theta-max](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-contact-theta-max.png) · [xcui-r4-interactive-r4-contact-theta-min](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-contact-theta-min.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 切角 θ 滑杆 | 首段图下 | 0°–90° | 更新瞄准点、接触点及偏移读数 |
| 母球距离滑杆 | 实战估角段 | 0.30–1.60 m | 更新中心连线估角偏差演示 |
| 厚度与偏移表／正弦图 | 页面下段 | 只读 | 对照角度、厚度及毫米偏移 |

待补：已补首屏至页尾、切角与距离滑杆两端、正弦图和对照表；静态表格不列成额外可操作控件。

### P31 浅谈球感

模式：教学文档与2D/3D对照插图。源码：[BallFeelView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/BallFeelView.swift)。

截图：[xcui-r1-a11-ball-feel-scrolled3](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a11-ball-feel-scrolled3.png) · [xcui-r1-a11-ball-feel-scrolled2](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a11-ball-feel-scrolled2.png) · [xcui-r1-a11-ball-feel-scrolled](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a11-ball-feel-scrolled.png) · [xcui-r1-a11-ball-feel](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r1-a11-ball-feel.png) · [xcui-r4-interactive-r4-ballfeel-cta-destination](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-ballfeel-cta-destination.png) · [xcui-r4-interactive-r4-ballfeel-footer](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-interactive-r4-ballfeel-footer.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 2D/3D视角差异示意 | 教学段落 | 只读插图 | 解释同一球路的视觉差异，不是相机操控入口 |
| 用真台验证 | 页尾 | 学习完成后 | 进入2D角度训练 |

待补：已补首屏至页尾及“用真台验证”进入 2D 角度训练。2D/3D 差异为插图，不是可操控台面。

### P32 Pro 练习入口拦截

模式：付费练习入口共用订阅弹层。源码：[SubscriptionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/SubscriptionView.swift)。

截图：[xcui-r4-verification-r6-aimpoint3d-pro-gate-dismissed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r6-aimpoint3d-pro-gate-dismissed.png) · [xcui-r4-verification-r6-aimpoint3d-pro-gate-bottom](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r6-aimpoint3d-pro-gate-bottom.png) · [xcui-r4-verification-r6-aimpoint3d-pro-gate](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r6-aimpoint3d-pro-gate.png) · [xcui-r4-verification-r6-angle-3d-pro-gate-dismissed](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r6-angle-3d-pro-gate-dismissed.png) · [xcui-r4-verification-r6-angle-3d-pro-gate-bottom](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r6-angle-3d-pro-gate-bottom.png) · [xcui-r4-verification-r6-angle-3d-pro-gate](/Users/song/projects/13.billiard_trainer/output/ui-inventory-20260915/screenshots/xcui-r4-verification-r6-angle-3d-pro-gate.png)

| 功能 | 现有位置 | 条件 | 操作结果 |
|---|---|---|---|
| 关闭 | 弹层左上 | 订阅弹层显示 | 回练习入口 |
| 权益说明/订阅方案 | 可滚动正文 | 根据产品加载状态 | 只读权益及选择方案 |
| 加载失败/重新加载 | 方案区 | 商品列表为空或加载失败 | 重新请求商品 |
| 解锁 Pro | 底部主按钮 | 有可购买产品且不忙 | 购买流程；本轮不执行 |
| 恢复购买 | 右上 | 未忙 | 恢复商店交易；本轮不执行 |
| 服务条款/隐私政策 | 底部 | 链接可用 | 打开法律文档，不纳入台面按键重组 |
| 模拟器解锁 | 底部开发辅助 | 仅模拟器 | 测试权益开关，不计真实手机功能 |

待补：3D 两种测验的免费入口实际弹出订阅页；不是题面内额度页。补拍入口、滚动与关闭；模拟器产品加载情况不代表商店交易验收。

## 进入设计前必须补齐的证据

1. 手机 XCUITest 通道已建立，同球形视角、打点、答题和详情回放显隐已补；继续补其他宿主的特殊状态，分别记录台面区域、可见目标与遮挡。
2. 逐页补齐未选择、有解/无解、计算中、播放/暂停、回放/撤销、完成/错误与确认弹窗；上表逐页缺口仍有效。
3. 训练记录 iPad 内部及照片确认页已补；照片校准/标球仍受系统选图器点击无效阻塞，批量提取需到达真正台面。
4. P24–P31关联教学／Canvas页已有手机实图；全部教学滑杆及理论T01–T03交互示意仍需回归。31项不等于全App画面验收。
5. 建立可复现的源码/安装包对应关系后，再核实已有自动收起和状态分支。第4轮仅在独立模拟器构建安装，既有设备保持原样。

下一阶段才逐项决定：常驻、按状态出现、展开面板、页内更多、全局设置或合并入口；每一个被移走的功能都必须有去向。双手持机、精细操作和手机竖屏为既定设计约束。
