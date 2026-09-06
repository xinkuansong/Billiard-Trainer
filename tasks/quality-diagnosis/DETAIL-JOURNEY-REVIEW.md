# 多球形精讲与实质试打诊断准备

2026-09-06。仅新增 `DetailJourneyDiagnosticUITests.swift` 与本文。**没有执行UI、编译、XcodeGen或资源生成，尚无通过结果。** 两个独立正常入口方法，主控审核后注册到snapshot-002并串行执行。

## 固定样本和独立内容依据

课程为 `drill_c042`「初级蛇彩」，固定来自冻结 `QiuJi/Resources/Drills/positioning/drill_c042.json`，不随机选择。两个精讲球形与Bundle序列如下：

| 顺序 | 精讲ID/标题 | Bundle文件 | 杆数 / 首杆before目标球 | 精讲关键图 |
|---|---|---|---|---|
| 1 | manual01 / 球形1：首杆八起点阶梯 | `DrillBoards/drill_c042__manual01-初级蛇彩走位 · 球形1-8杆.json` | 8杆；_1、_2、_3，不含cueBall共3球 | `drill_c042_manual01_s08`，caption“第8杆：约 18°” |
| 2 | manual02 / 球形2：五球连续蛇彩 | `DrillBoards/drill_c042__manual02-初级蛇彩走位 · 球形2-5杆.json` | 5杆；_1…_5，不含cueBall共5球 | `drill_c042_manual02_initial`及`drill_c042_manual02_s05`，第5杆caption“第5杆：约 3°” |

`DrillTryoutBoardStore.formations`按文件名排序，首杆before优先于initial，displayName重排为球形1/球形2。精讲使用长标题；试打选择行使用短名，两者不应错误期待逐字相同。表中token、杆数和开局球数从JSON独立读取；测试没有从App显示内容反推期望。

manual01本身是8次独立首杆，manual02才是5球连续。已有QD015涉及manual01第6杆教学自检与图示冲突，本测试不会改内容或隐藏该发现，也不以选课/击球通过反证QD015。

## 两方法的实际覆盖

### testC042TutorialTwoFormationsKeepDistinctPostersAndReadingPosition

1. 正常动作库Tab，`librarySearchField`输入“初级蛇彩”并回车，点`drillCard_drill_c042`，确认详情与底部试打按钮。
2. 从详情滚到“查看精讲”，正常push；确认`tutorialFormationPicker`默认第1球形selected。
3. 实际下滚到球形1第8杆poster和caption。按钮ID含正确资源名，只有图片成功加载时才生成此button；并确认球形2第5杆不可点。保存图+AX。
4. 固定Picker切球形2，确认selected；核对manual02开局poster与五球连打caption，再滚到其第5杆poster/caption；确认球形1poster不可点。
5. 切回球形1，**不滚动补找**直接等待第8杆caption可见可点，检查各球形独立保留阅读位置；确认球形2poster不可点。
6. 返回详情，再返回列表，核对原搜索文字和原结果仍在。

这是实际内容/图像按钮对应与独立滚动状态，不只是精讲标题。没有打开全屏图集（关闭按钮当前缺显式AX标识）、没有假造Disclosure：DrillTutorialView各section本来常驻，动作是实际长文滚动和固定分段切换。全屏放大/左右换图/关闭仍单列缺口。

### testC042BothTryoutBoardsStrikeUndoAndRearrange

1. 同样从正常动作库搜索c042进入；先选球形1再选球形2，每次都必须出现“选择球形”sheet。
2. 对**指定row自身label**断言球形N、8杆3球或5杆5球，避免匹配到另一行；通过`tryoutFormation_0/1`进入。
3. 等真实序列模式控件，核对`tryout.briefCard`及当前“本局共8/5杆”，另一个计数不能出现；截图保存实际初始桌面。杆数与token对应，不仅看相同课程标题。
4. 切到“自由”模式，等待可击球；先检查重打不可用，然后实际击球，等待重打与回放可用（60秒上限）。拍击球后图。
5. 点重打，检查再次可击球且重打禁用，拍恢复图；点“重摆球形”，检查可击球且回放禁用，拍重摆图。
6. 返回同一课程详情，再选另一个球形重复；最后返回库和原搜索。

动作取自 `PositionPlayComposerView`：有steps默认sequence；`selectTryoutMode(.free)`退出序列并loadBoard；自由击球按钮调用vm.play、重打调用vm.replayCurrent；`tryout.rearrange`调用loadBoard清lastShot/canReplay/canPlayback。**没有开启录制**，新VM `isRecording=false`，不调用startRecording/export，工具使用记录局限内存库。

## 严格边界与待目视

- 测试明确用现有launchClean + `-v50.inMemoryStore` / `-forcePremium`，专用无凭据设备；不证明真实付费/磁盘/同步。正常路由没有被deepLink替换。
- 每个方法截图/AX命名为固定方法名-stage-runUUID。QD_SHOT_DIR或TEST_RUNNER_QD_SHOT_DIR必须指向新执行目录。正常入场/每球形关键操作/返回/teardown都有证据；失败保留XCTest与原图，不能运行后拿旧图补齐。
- 图片button存在证明其对应UIImage可加载，**不证明球的几何和文字正确**。主控必须比对已保存截图：F1原台3目标球、F2原台5目标球，两组击球前/重打后/重摆后的球数与位置是否恢复；不能把测试AX通过自动升级为视觉通过。
- 试打使用自由模式的一杆物理击球，不强求必进球，亦不声称重现存档预期potted/after；那需要独立模拟和坐标核对。序列默认入场与杆数已检查，但未自动播放8/5杆序列、未验证逐杆推进/暂停/重播。
- 精讲多球形切换已有隐藏/非交互判定；若AX把不可见poster仍暴露，则先核对实际isHittable与截图，不能直接归因串图。
- 第二方法内部两球形是同一路径的两轮；若第一轮失败，第二轮不执行，报告中必须写明未执行，不能按2球形计覆盖。主控可仅调整独立测试拆分排查，勿改业务。

## 首跑风险与失败归类

- Picker长标题可能在画面截短，但AX通常保留原label；需原始AX确定，不能只扩大等候时间。
- `tryoutFormation`行文本来自嵌套HStack/VStack。若button.label未合并其子文字，先查AX，改为row范围内子staticTexts断言，禁止改成全App范围凑数。
- 首次精讲深滚最多28次，若仍未找到末图，查内容加载/手势落点/图片缺失。未完成滚动不算内容缺陷已证实。
- 返回详情与试打标题同为初级蛇彩，所以`backToDetail`还必须等`bottomTryoutButton`，避免仅标题误认返回成功。
- Swift编译与实际定位尚未验证。主控先运行两个方法，保存编译错误或失败；不在运行中修改snapshot输入。

可覆盖SC16正常搜索局部、SC17精讲阅读/切换局部、SC18正常详情→多球形→实质试打返回、SC21一杆重打/重摆局部。完整SC仍不能标全量完成。
