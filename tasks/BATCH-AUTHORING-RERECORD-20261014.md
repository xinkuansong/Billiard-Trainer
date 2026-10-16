# 批量编排台：瞄准条与选杆重录

2026-10-14；用户反馈竖屏 iPad 缺少瞄准条、不能选择某杆修改。用户选择：从选中杆开始重录后续整段。

用户追加范围：这是本人专用的 iPad 竖屏内容工具；后续以 iPad 竖屏验收，不再为手机追加适配。

## 行为

- 各工具显示共享方向尺；与杆速尺同一尺寸规则。首次微调从当前求瞄方向进入手动方向，保留当前物理/求瞄算法。
- 顶部「选杆重录」与更多菜单同名入口：选择任意已有杆，恢复其 before 与击球参数。
- 选择/取消/调参/未成功击球均不删原步骤。新杆实际轨迹记录成功后，提交原前缀 + 新杆，移除旧选中杆及后续；随后沿新停点继续录。
- 「取消选杆，回末尾续录」保留所有原记录。载入存档原样进入内存，不再自动重算改写或在不可行杆处截断。
- 只有用户执行现有保存动作才写内容库；本轮验证不保存、不改原序列数据。

## 验证

- 最终构建 r3 通过。4 项真实引擎单测通过：首/中/末杆替换边界、取消与无效击球不破坏存档、轨迹捕获与接续录制。
- iPad 13 寸 Air M3：原五杆载入 → 选第三杆 → 方向尺微调 → 横竖切换保留球形 → 取消仍五杆 → 再选第三杆击球后仅保留前缀+新第三杆；UI 通过，原图已目视。
- 98 份内容库序列哈希与本轮前审计基线一致；没有执行任何保存动作。
- 用户收窄范围前已发起的手机/SE r3 UI 测试也已通过；不作为后续支持范围。
- r1 测试 helper 作用域编译错误已修；r2 SE 球库隐藏被原图审查发现并由 FL-159 修正；r2 手机测试断言通过后 xcresult 同路径冲突，r3 使用独立 resultBundlePath 全部成功。
- 证据：build-r3.log、unit.log、ipad-r3.log/xcresult、ipad-r3/*.png、source-integrity.json。
- 尚未经过用户体验确认；未提交、发布或安装真机。

## 现场

保留用户正在操作的 iPad FC1D1E55-98B0-4129-BE34-9890D9CA12EE，不安装、不重启。测试在其他受管设备执行。

证据：`output/batch-authoring-edit-20261014/`。

## 交付现场

新版已在另一台 13 寸 iPad Air M3（E3329A7F-4FD3-47A0-83DD-2B163AD14796 / QiuJi-Managed-Pool-b5f070e3）竖屏打开「初级蛇彩 manual02」，停在第一杆击球前，方向尺和「选杆重录」均可见。未点击击球或保存。原用户 iPad FC1D1E55 的旧编排现场未动。两台均保护保留。

### 13:58 模拟器窗口收尾
用户要求关闭无用窗口并前置新版。旧版 FC1D1E55 已通过 Simulator 关闭窗口，核验 Shutdown，保留设备数据；本任务手机测试机已 Shutdown。新版 E3329A7F 在另一任务 palette-real-pad-reuse 测试释放后，重新启动正常应用，Simulator AX 确认其为 focused window，原生截图为竖屏。其他活跃任务设备未停止。当前停在训练首页，未重新进入编排台；后续 CUA 输入返回 windowNotFoundAtPosition，桌面盘点超时，故不宣称编排台已恢复。

## iPad 竖屏个人工作台 · 第二轮（实施与模拟器验证完成）

用户批准常用操作进入左右栏，仅验证本人使用的 iPad 竖屏，不追加手机适配。保留物理与瞄准算法、原序列文件。

左侧：工具、方向尺、固定四向 0.5 mm 微调（无焦点置灰）、辅助线/母球换位/定位/网格/轨迹/特写；求解模式显示约束工具。右侧：原打点/杆速/击球、重录本杆/本杆回放/整段预览、初始球形/回到当前/从头重录、选杆重录、保存。两侧从桌框上部排列，保留桌体投影。

初始球形使用第一杆 before（无杆时 initial），查看时禁止击球/摆球/保存；返回恢复编辑快照、球姿态、瞄准选择、参数、杆选择及球库状态。查看不截断；从头/选杆/重录本杆均成功录成后替换后续。保存新增留在当前页，旧覆盖确认仍保留；本轮验证只取消覆盖，不写原序列。

证据：output/batch-pad-workbench-20261014/。改前 iPad 原生测试已通过并审阅截图；构建与新增功能验证进行中。单位：既有世界 X–Z 米制、Y 向上；竖屏画面上=+X、右=+Z，四向步进复用既有实现。

首轮新增单测的等待器在交互防抖尚未启动（0.5秒）时误以为求解已完成，`isFeasible`断言失败；其它状态恢复断言未失败。改为等待可行结果且计算结束，仍保留20秒上限与原断言，不修改引擎/防抖。首轮日志保留，复验另建结果。

首轮 iPad UI 核心交互断言通过，末尾保存确认取消步骤失败：iPad 原生确认浮层以点外部取消，不提供独立“取消”按钮；已依据失败AX证据改为点外部并断言覆盖按钮消失，完整流程待复验。原生截图复核发现初始查看态四向键已禁用但亮度未随禁用变化，补齐置灰与“球位只读”说明，复验增加四键禁用断言。桌框及六袋完整、主操作未与桌框重叠。


### 第二轮最终结果

- 最终构建 `build-final.log` 为 TEST BUILD SUCCEEDED；`final.log`/`final.xcresult` 为 TEST EXECUTE SUCCEEDED：7 项单测、1 项完整 iPad 竖屏 UI 测试，0 失败。
- 四向分别验证实际球位 0.5 mm 及屏幕方向，长按连续移动；初始查看恢复五球且禁止编辑，返回精确恢复编辑现场；从头/选第三杆均不提前删除后续，成功击球后按新停点继续录制。保存覆盖提示仅打开并取消，没有写入内容库。
- 目视复核 `final/workbench-nudge.png` 与 `final/workbench-initial-preview.png`：桌框六袋完整、四向按钮固定、只读状态明确、左右操作清晰可达。
- `integrity-final.json`：103 份原序列无新增、删除、内容变化；四份实现/测试文件与验证构建指纹一致。物理与瞄准算法未改。
- scoped diff check 与文档大小检查通过。未安装真机、未提交发布；用户操作体验待确认。

### 第二轮现场交付

已在 E3329A7F / QiuJi-Managed-Pool-b5f070e3 正常启动新版应用并前置，原生画面确认竖屏编排台左右工具栏。当前打开目录中的 drill_c001 / manual01，停在“初始球形·仅查看，原录制未改变”；“回到当前”“从头重录”“选杆重录”可见。未击球、未保存。蛇彩 manual02 的交互验证见上述 final.xcresult；交付导航阶段模拟器无 iOS AX 且滚动输入未生效，因此没有声称交付现场为蛇彩2。

## 第三轮：回上一杆球形（实施与模拟器验证完成）

用户明确：右侧独立入口，保留所有已录杆，回到最近一杆击球前，允许母球换位后追加下一杆。此操作只保留内存中的录制，不隐式归档。原误称“追加分支”恢复为“回上一杆球形”；重录入口独立保留。

根因：第二轮未将旧入口迁入右栏，且旧 restorePreviousBoard 没有处理选杆重录的挂起状态。新编排动作先解除挂起替换状态，再恢复最近已录杆起点，避免下一次击球误截断。六字标签在原44pt按钮内自然分两行。

验证使用 FC1D1E55-98B0-4129-BE34-9890D9CA12EE；E3329A7F 当前一杆未保存现场保留、不安装重启。证据目录 output/batch-previous-board-20261014/；新增逐杆内容不变+实际继续追加单测，并扩展真实iPad UI的恢复/母球交换/第四杆追加流程。

第三轮最终构建 TEST BUILD SUCCEEDED；final.xcresult / final.log 为 TEST EXECUTE SUCCEEDED：8 单测（34.580秒）+1完整UI（99.533秒），0失败。UI实证保留三杆→回第三杆起点→交换母球与3号球→实际录成第四杆→再次返回第四杆起点；包含选重录后改为追加的边界。单测逐字比较原杆编码不变。覆盖确认仅取消，未保存。

视觉复核：已打开 final/workbench-default.png 与 final/previous-board-cue-swapped.png，右栏六字按钮完整两行，44pt命中框不侵入桌体，与重录本杆独立；桌框六袋及左右工具完整。before/portrait.png保留用户原窗口状态，前后球形不同，不声称球位同态对照。integrity-final.json核对103份序列，无新增/缺失/内容差异，代码指纹与测试构建一致。

第三轮现场交付：新版正常启动于 FC1D1E55 / QiuJi-Managed-Pool-6f47d1cd，已前置到 iPad 竖屏编排台 drill_c001 / manual01。现场点击右栏“回上一杆球形”，已目视确认恢复击球前母球与4号球、进入摆球模式，可换位继续追加；未击球、未保存。原 E3329A7F 一杆编辑现场保留。模拟器验证完成，用户体验待确认，未安装真机或提交发布。

## 第四轮：单杆替换与后续重录（实现与模拟器验证完成）

用户确认名称：选杆重录＝只替换选中杆，其余球形、轨迹与顺序原样保留；选杆重录后续＝原截断后续功能。右栏两个独立按钮。替换须实际轨迹录成才提交，选择/取消/失败不改序列；编排预览逐杆从作者球形播放。仅iPad竖屏，保留物理与瞄准，不保存原内容。当前FC1D八杆编辑现场保持；测试复用已Shutdown的E332。证据output/batch-single-rerecord-20261014/，本轮103份序列SHA基线已冻结。

第四轮r1：11项单测全部通过（74.858秒），首/中/末替换、其余杆逐字节不变、序列编解码、整段实际回放均通过。UI完成第三杆重录后，新增断言的标识误写为batch.editStep.(index)，未插入序号；修正测试定位，保留五杆数量断言与生产实现不变，完整UI待r2复验。r1失败原件保留。

r2构建通过，但UI runner被SpringBoard以Busy/preflight拒绝启动，0项执行，不能计通过。后续读回测试设备已Shutdown；没有触碰FC1D。仅启动测试设备并等待bootstatus完成后以r3重试，保留r2.xcresult。

第四轮最终：build-r2.log为TEST BUILD SUCCEEDED；r1业务单测11/11通过（74.858秒），修正测试选择器后r3完整iPad UI通过（154.402秒、TEST EXECUTE SUCCEEDED）。未改生产代码重试。真实蛇彩2仅重录第三杆后保留五杆、第四杆球形精确不变、整段完成；截图和AX明确“序列预览完成 · 5杆”。随后后续重录第三杆成功截断为三杆，回上一杆/换母球再追加第四杆，四向/初始/保存取消回归通过。

视觉：已打开r1/workbench-default.png、single-shot-picker.png与r3/single-five-shot-preview-complete.png、workbench-third-replaced.png，右栏两个名称独立且六字自然两行，菜单标题/说明完整，球桌六袋/球库完整。r1与r3生产布局相同；改前八杆与测试五杆数据不同，不宣称球位同态对比。integrity-final.json核103份序列无新增/删除/内容变化，四份实现测试文件与构建指纹一致。物理/瞄准算法未改；未保存原存档、未装真机、未提交发布。

第四轮现场交付：已正常启动最新版（无测试夹具）并前置QiuJi-Managed-Pool-b5f070e3 / E3329A7F，打开初级蛇彩manual02，选择「选杆重录」第3杆。原生AX及截图确认只重录第3杆提示、3/4/5号球起始球形、双入口均可见；未击球或保存。handoff.png留证。FC1D原八杆编辑现场未重启安装。


## 分离角综合挑战重录副本（2026-10-14）

用户授权只建重录副本并校正非法贴库球，由用户重新击球录制。新增 `content/position_play/sequences/drill_c031__manual01-分离角综合挑战 · 重录副本（待重录）-13杆.json`；原 Snipaste 序列不变，副本使用独立序列/杆 UUID，13 杆参数及旧 after/outcome 保留为参考，各杆备注标明待重录。未把旧结果宣称为修正后的模拟结果，也未同步到 Bundle、精讲或发布内容。

复用与当前代码一致的 `EngineNumerics.planarIntrusions`、`TableGeometry.chineseEightBallQiuJi` 与坐标转换，在独立模拟器诊断程序中沿实际接触法线向内修正，留 0.1 mm 摆位余量（未更改引擎容差）。initial + 13 before 共 14 盘面均通过有限库边/袋角、capture region、球间重叠断言，共 84 处坐标修正；初始 10 球移动 2.233–5.286 mm，母球/1号球及所有 shot 参数保持。after 保留旧参考，需用户逐杆替换。

证据：`output/c031-rerecord-copy-20261014/geometry.json`、`verification.json`、`handoff.png`。初次诊断编译因直接引用完整翻袋模块缺依赖失败；恢复既有诊断程序的取消令牌提取文件后编译成功，该程序只做真实几何校验、不调用翻袋或击球求解。iPad E3329A7F-4FD3-47A0-83DD-2B163AD14796（b5f070e3）已前置，打开 manual01 → 选杆重录 → 第1杆，击球按钮可用且出现当前轨迹预览。未代用户击球/保存，未重编 App，保留另一旧编辑窗口。下一步：用户逐杆重录并保存副本；完成后另行决定替换正式内容。

### 同日用户改为替换原入口

用户明确要求「把修改后的替换下，不要用manual」。已将修正副本的 initial/13 before 及参数原样替换到原 `drill_c031__Snipaste_2026_06_19_13_52_32-分离角综合挑战-13杆.json`，恢复名称「分离角综合挑战」，保留原 token；manual01 文件移入 `output/c031-rerecord-copy-20261014/replacement/`，不再出现在编排台。原未校正文件先备份为该目录的 `original-before-replacement.json`，校验与前次原 SHA 一致。原序列保护要求已由本次明确替换授权更新；未改物理/瞄准代码。当前仍为待用户重录的起始球位修正，0条新轨迹，旧终局参考尚未替换；未发布或重烘焙教学内容。

交接已核验：重启当前 App 刷新目录后 c031 仅 1 球形，选图页无 manual01；从原截图「重做」进入 13 杆记录并选择第1杆，竖桌/选袋/击球可用。截图 `output/c031-rerecord-copy-20261014/replacement/handoff.png`；未代用户击球或保存。


## K球综合挑战原球形校正（2026-10-14）

用户授权直接替换原球形并备份旧文件，保留当前物理和瞄准，交用户重录。已修改原 `drill_c085__manual01-K球综合挑战 · 球形1-14杆.json`，未新增球形。备份 `output/c085-rerecord-20261014/original-before-replacement.json`，SHA256 `2c5c0169db8642633fd7de812f265cff5f1d810870c4d3b3b550b08ee64a9e35`。

前12杆 before 的11/12号球、13杆 before 的11号球共25处向内移动1.883984mm（原侵入1.7839mm，加0.1mm摆位余量）；第14杆及仅母球的initial不变。14杆起始盘面+initial全部通过当前有限库边/袋角、capture region、球间重叠检查。首轮诊断误将浮点舍入量级侵入也列为非法而触发断言，未改内容；修正诊断使用生产引擎同一 `depth > 8*max(x.ulp,z.ulp)` 门限后通过，生产代码未改。

除25处球位与updatedAt外所有JSON字段保留，包括序列/杆ID、shot、note、after及进球结果。旧终局仍是历史参考，未作为修正后的实际轨迹，待用户重录；未同步Bundle/精讲/发布。基线核对全部序列和QiuJi Swift源码，仅c085源JSON变化。证据：geometry.json、verification.json、handoff.png，均在上述output目录。

iPad E3329A7F / b5f070e3 已前置，正常编排台原manual01入口→选杆重录→第1杆；AX确认14杆载入、竖桌、仅重录第1杆、击球可用，目视球桌和工具完整。未代用户击球或界面保存，未安装重编App；设备已保护待用户操作。


## 两项修正纳入 App 资源与厚球第6杆交接（2026-10-14）

用户要求 c031/c085 更新到生产代码，并打开 c026 球形2第6杆供重录。检查发现：c085源已修但Bundle旧；c031当前源与Bundle均回到旧SHA `275104e1...`，与上次交付修正SHA不同，回退发生机制尚未确认。已先备份本轮源/Bundle原件到 `output/challenge-production-sync-20261014/backup/`，从上轮不可变 `replacement/replacement.json` 恢复c031修正版（SHA `9619e289...`），没有覆盖新录制。两项均保留原token与入口。

`make tryout-sync`增加可选 `TRYOUT_DRILL_IDS`，本轮仅指定c031/c085；默认仍全库。rsync增加checksum，避免相同大小/mtime却内容不同被跳过。临时fixture实测最初暴露旧快速比较漏传，增加checksum后验证通过：同大小同mtime目标更新、目标旧文件清理、其他drill原样保留。真实资源与源逐字节一致；其余尚在编辑的c001/c003/c015/c023未被同步。

通过Makefile的build动作完成当前App构建，`build.log`明确BUILD SUCCEEDED（不是测试通过）；实际.app内c031/c085两份文件SHA与源一致。已安装E3329A7F / b5f070e3、正常启动，编排台进入c026 manual02（7杆）→选杆重录→第6杆，AX确认「仅重录第6杆」、8号球在桌、竖桌、击球可用，原生截图 `handoff-c026-shot6.png`。未代用户击球或保存c026，未改任何物理/瞄准Swift。当前设备已保护。

全量 `verify-tutorials` 已运行但未全绿：8项FAIL＝c031/c085及已有c001/c015旧出片新鲜度4项＋其他未同步drill的I8四项。C4结构对齐无差异；本轮两项I8均通过。`verify_manual_formations.py`已运行输出覆盖矩阵。两项本次只同步授权的球形数据，旧终局仍为历史参考，教学出片待用户重录定稿后刷新；不宣称完整内容发布、真机安装或提交发布。证据目录另含built-resource-verification.json、sync-verification.json与scoped-sync-check.txt。


## drill_c039 逐杆调位合并为统一初始球形（2026-10-14）

用户新录8杆存档 updatedAt=2026-10-14T11:57:50Z：2～8号球各在轮到自己前调位，母球衔接不变。按用户授权将各目标球该杆before中的最终位置前置到initial及所有更早杆的before/after；1号球和母球不改。原文件备份 `output/c039-unified-layout-20261014/original.json`，原Bundle另备份bundle-before.json。保留原token、序列/杆ID。

28个更早杆静止球轨道已先确认全帧stationary、速度为0、无碰撞/音效事件；只替换其恒定position及finalPositions，移动球轨道、时间、旋转、瞄向、打点力度、声音与进袋结果逐字段不变。修改过的轨迹source标记为recorded-live-v1:static-layout-edited，通过生产encodedStep重新绑定，不冒充未经编辑的原录制。以连续采样线段核所有新静止球与母球/目标球路线，最小球面间距143.900mm，没有新增路径相交。

独立模拟器诊断程序使用与当前相同的PositionPlayModels/SequenceReplayResolver及生产几何，17个盘面全部合法（库/袋角、袋捕获区、球间距）；8杆经生产recordedTrajectory及prediction转换通过、编码重读仍可用，7次after→before逐坐标完全一致。Python独立逐字段验证8杆母球/目标球轨迹、停点、参数、事件完全不变；Before/Unified布局图已目视核对。首轮诊断编译因throw放入precondition autoclosure失败，移出后编译与验证通过，未改生产Swift。证据verification.json、dynamic-integrity.txt、swept-clearance.json、layout-comparison.png、integrity.json。

已替换原源文件并用 `make tryout-sync TRYOUT_DRILL_IDS=drill_c039` 定向同步到生产DrillBoards，逐字节一致。全量内容校验已执行，旧出片未跟随本次布局更新，相关新鲜度债保留，不宣称全量通过。本轮不重启/重装用户正在录制的App，未改物理或瞄准；编排台需退出当前球形再进入以载入新文件，新安装包需后续构建。没有代用户重新击球或把当前物理重新求解结果替换录制轨迹。

本轮末尾完整性检查还发现c031源文件在执行期间由外部发生变化（不属于本次写入），已保留现场且未回写；本轮全部Swift未变、c039源与Bundle一致。全库校验FAIL为12项，未误记为通过。


### c039 新版安装交付（2026-10-14）
用户授权重新安装。通过Makefile执行arm64模拟器build，build.log为BUILD SUCCEEDED；安装到E3329A7F / b5f070e3后实际容器DrillBoards的c039 SHA与统一球位源一致（0081a7d1...44ade，8杆）。正常启动，无测试夹具；已前置iPad竖屏动作库→直线球组合走位详情，AX第1/8杆等待回放，截图目视8球完整。未代用户击球/保存或更改内容。证据output/c039-install-20261014/内build.log、expected.json、installed-verification.json、handoff.png。此为模拟器安装，未发布线上。
