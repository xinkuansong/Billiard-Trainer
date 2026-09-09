# c042 两条正常旅程草稿审阅（snapshot004）

2026-09-08，只读。已全文读 DetailJourneyDiagnosticUITests.swift，并核冻结004实际内容、入口、launchClean与动作实现；未修改草稿/工程、未构建或操作UI。主控solver运行期间保持只读。结论：两条方法的内容身份与正常入口可复用，但旧snapshot002注释不能充当004执行证据；当前草稿不能仅凭绿状态宣称实际击球、不同球形或图片正确，正式前需主控处理下列诊断护栏，并保留硬性图审/动态证据验收。

## 输入与入口核对

新 CONTENT-FRESHNESS-004-AUDIT 与路径SHA原件已证明当前c042内容/两盘面/配图及相关入口与004相同，本轮直接读004 JSON确认：c042名“初级蛇彩”，isPremium=false。

|球形|精讲标题/真实图片字段|盘面与真实首杆|
|---|---|---|
|manual01|球形1：首杆八起点阶梯；manual01_s08；caption第8杆：约18°（源码有空格）|8 steps；首杆before含cueBall+_1/_2/_3；targetKey _1，topCenter，velocity1.3，spinX0/spinY约−.39|
|manual02|球形2：五球连续蛇彩；manual02_initial及manual02_s05；第5杆：约3°；开局五球连打说明|5 steps；cueBall+_1…_5；targetKey _1，topCenter，velocity约1.7，spinX约.02444/spinY约−.47362|

精确盘面路径为 `QiuJi/Resources/DrillBoards/drill_c042__manual01-初级蛇彩走位 · 球形1-8杆.json` 与 `...manual02-初级蛇彩走位 · 球形2-5杆.json`。8/3、5/5计数来自真实首杆before及steps；不是拿球形编号猜球数。两首杆都topCenter，不能凭相同袋口区分球形，也不能只数球就证明坐标对应。

正常路径成立：动作库 `librarySearchField` 搜“初级蛇彩”→`drillCard_drill_c042`→详情 `bottomTryoutButton`；查看精讲进入独立页面。DrillDetailView.startTryout因formations>1出现“选择球形”sheet，行ID `tryoutFormation_0/1`，行内部显示displayName和“8杆·3球”/“5杆·5球”。选择传递formation而非单独index文本。`backToDetail`同时等同名导航标题及bottomTryoutButton，比只看“初级蛇彩”正确；关闭按钮firstMatch仍须现场AX确定不是别的导航操作。

## 方法1：精讲切换/阅读位置

selector：`QiuJiUITests/DetailJourneyDiagnosticUITests/testC042TutorialTwoFormationsKeepDistinctPostersAndReadingPosition`。

源中picker确为 `tutorialFormationPicker`；每个已访问球形有独立ScrollView，未选球形opacity0、allowsHitTesting(false)、accessibilityHidden(true)。草稿选manual01末图及caption，再manual02开局/末图与caption，回manual01不reveal只ready原caption，属于有效的“阅读段落仍可见”oracle；不是精确像素滚动位置或完整末段阅读认证。

poster identifier直接绑定image字段，能证明所选图片控件路径；必须图审其真实海报，不得以ID含manual01/02证明没有错图/空白。另一poster不可hittable只是隐藏交互证据，不证明其像素不在屏幕或所选海报正确。caption使用CONTAINS firstMatch，没有唯一性/容器绑定；目前字段匹配源码，但现场必须确认同caption没有重复或隐藏节点误中。

必看原图阶段：tutorial-f1-eighth-shot、tutorial-f2-opening、tutorial-f2-fifth-shot、tutorial-f1-position-restored。逐图对照对应真实HEIC/正文：图像不是占位，球形/杆号/说明符合所选资源；回F1后同第8杆内容在视口且F2未叠入。不要把开局图中参照球与某一杆before目标球数混为一谈，也不认证caption角度的教学几何正确性。

## 方法2：两盘面试打/重打/重摆

selector：`QiuJiUITests/DetailJourneyDiagnosticUITests/testC042BothTryoutBoardsStrikeUndoAndRearrange`。

选择行的球形编号/杆数/球数绑定row本身，比全App凑文字强；入场brief的“本局共8/5杆”来自DrillTryoutBrief，实际source可用。但这些都是元数据，若错误board加载却保留对应brief，本方法也可能绿，必须比较实际桌面。`tryoutMode_序列`只查可用，没有断言选中状态；之后实际点自由模式。不得把初始有序列按钮称为已播放序列。

自由模式击球→重打/回放可用→重打→击球可用且重打禁用→重摆→回放禁用，源码分别为vm.play、vm.replayCurrent、vm.loadBoard(tryoutBoard)。**草稿从未点击“回放”**；回放仅作缓存就绪控件，方法名Undo指重打，不能报告回放已执行。也没有播放8/5杆整段序列。

仅重打从disabled到enabled与回放可用，是操作后状态/缓存证据；不能证明物理运动确实绘制。XCTest tap可能等动画结束才返回，after-shot PNG可能只有终态。严格动态验收应从该方法原始xcresult视频/主控现有视频记录中，分别为F1/F2标出击球前、运动中、稳定后时间/帧；若无运动帧，结论只能“操作与终态可用，实际运动未验”。不得用额外静默等待、瞬时busy缺失或另一个工具的运动视频代替。

图审每形choice、initial、after-shot、undo、rearranged；实际initial应与对应before坐标/球号布局一致（含母球共4/6球）。自由模式切换后的击球起始画面现草稿没有单独PNG，需要视频显示它保持正确原盘；无法从视频确认则保留这个缺口，必要仅追加该观察点，不改业务。重打/重摆都应回同一原盘的球号、位置，不能只看按钮变灰。击球不要求必进，不拿自由模式真实结果硬套存档after。第一形失败即后续未执行，不能按两形通过计覆盖。

## 会员、隔离与副作用

launchClean实际追加中文、跳过onboarding、resetDebugPremium，再叠加inMemoryStore与forcePremium。c042本来免费，forcePremium不是此课入口必要条件；若保留，仅标受控Pro环境，不能报告Free门控通过。该helper会在非前台时最多自动重启两次、每次sleep3秒；它不是磁盘/Keychain清理工具。当前草稿未显式设备UDID、guest身份或首次启动失败断言，不应复用真实用户设备或“clean”字样推断无凭据。

训练ModelContainer因-v50在App初始化前选择当前V5内存schema。试打.toolUsageSession可能写tool记录到该内存库；交互会写“已见手势提示”UserDefaults；launch参数写引导/调试会员偏好，截图写诊断目录。未点录制、分享、导出，不调用startRecording/export或生成资产。不证明真实磁盘持久、真实账户或云同步隔离；专用无凭据设备是主控外部前提。

## 正式前最小诊断护栏与最多现场适配

建议主控执行前独立审改诊断文件（本审阅不改）：显式expectedUDID核对；改为单次正常launch并确认foreground，取消隐藏重启；关键前置guard+throw使失败不会继续发操作。`continueAfterFailure=false`与XCTAssert在异步/工具边界不能代替明确中止。输出目录应在setUp验证，失败先证据再退出。

现reveal最多28次且只单向上滚、用全窗0.75/0.78→0.33硬坐标，只靠hittable，不检查非空frame/实际scroll容器/底栏遮挡，可能出现旧template类误触。正式前应将实际可见/点击边界绑定窗口与有效容器，元素已在上方时反向有界滚动；只读caption不用hittable。不要扩大次数或缩小通过条件掩盖错滚。

允许的现场适配仅限有原AX/PNG证据后的三类：①Picker/row实际节点类型或组合label拆分，仍在指定picker/row内唯一绑定；②滚动方向、容器和可见frame，保留回F1不滚动的关键oracle；③返回控件或稳定后截屏点，保留详情真实按钮身份。若发现内容/球形错配则记录产品问题，不改字面8/3、5/5、图片名或caption来凑绿；若需扩大到播放序列/回放/全屏图浏览，另列缺口，不偷加本批范围。

capture当前先取screen/AX再写png/txt，文件stem有方法+stage+UUID但不是exclusive-write；必须新目录，不复用旧图。teardown抓终态并terminate，不保证失败前关键状态始终保留。主控必须实际view_image读回原件并核视频，附件存在/日志绿不代替图审。

## 可复用既有证据与停止边界

DETAIL-JOURNEY-REVIEW.md是旧准备稿，不是执行通过。B3已有代表c012正常详情/试打及工具重打图审，不能替代c042双球形。CONTENT-SAMPLE-REVIEW已对c042两initial及manual01第6杆等做静态内容抽样，并保留CS-03方向文案问题；不用再重复该已知内容矛盾来扩大本批。当前Bundle全量解码/资源哈希证明文件存在与可读，不证明此双球形UI切换。

两方法可补SC17阅读切换及SC18多球形正常进入/返回的局部；完整自由击球运动必须视频，恢复布局必须图审。后续全屏放大/换图关闭、完整8/5杆序列不在现方法内，不能默认为已覆盖；也不因此让当前批无限增长。完成本批后按实际操作、图审、动态证据三层分别记录，不把SC17/18全域或整个目标宣布完成。

## 主控授权后的草稿修订（仍未注册/运行）

只改 `DetailJourneyDiagnosticUITests.swift` 与本文，原业务、球形字面8/3与5/5、图片字段、恢复状态及回F1不滚动oracle不变。前文“旧草稿缺护栏”的描述为审阅时状态，以下列最新实现为准：

- `QD_DETAIL_DEVICE_UDID` 与系统实际SIMULATOR_UDID严格相等，直接键优先，支持TEST_RUNNER_回退；不覆盖实际UDID。QD_SHOT_DIR支持同样回退，必须绝对目录，setUp用唯一probe文件确认可写后移除该probe，不清理其他证据。
- 删除launchClean调用，单次普通app.launch，固定中文/跳过引导/当前V5内存库/forceNonPremium，明确等待foreground；无失败自动重启。先正常进入我的页，profile.login可用且profile.accountHeader不存在，记录guest-free-before。c042为免费内容，此批不需要forcePremium，不提供真实会员/Keychain隔离证明。
- ready检查exists/hittable/enabled及非空有限frame、窗口、可交互TabBar/NavBar遮挡；reveal最多16步，在唯一实际可交互ScrollView与window交集内裁掉导航/底栏，依据元素相对上边界双向滚动。多个活跃scroll容器时失败取证，不任挑firstMatch。caption读取改为唯一有效可见StaticText，不要求hittable；F1恢复仍 `readCaption(..., revealFirst:false)`，没有通过滚动找回文字。
- 原XCTAssert状态语义换为require+throw，保持原预期，关键失败不会继续点击下一步；两方法do/catch先capture failure-before-termination后throw，teardown仍取证并终止。capture先保存PNG再读取/保存AX，均withoutOverwriting；capture本身错误不吞，XCTest原失败及已存PNG保留。setUp发生前置错误会由teardown在已有app/output时留终态，不启动补救流程。
- 每形自由模式可击球、重打禁用之后且tap击球之前，新增 `formation-1-free-before-shot` / `formation-2-free-before-shot`。图审可比较切自由后的真实原盘，实际运动仍需原始视频，不把新静态图当运动证据。

两精确方法名未改。执行所需新增变量只有显式设备UDID与已存在输出目录键；不加入seed/日期条件。语法检查 `xcrun swiftc -frontend -parse tasks/quality-diagnosis/DetailJourneyDiagnosticUITests.swift` 通过；未类型编译、注册、构建或运行UI。主控仍需独立全文核对定位/可见性helper和差异，现场只按前述三类证据适配，不修改业务与通过定义。
