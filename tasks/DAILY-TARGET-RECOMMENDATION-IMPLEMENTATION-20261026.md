# 每日清台舒适度推荐接入 · 2026-10-26

状态：✅ 已按用户“开始实现”授权完成代码接入、定向验证及对照图；待用户试用反馈，未提交/发布。需求真源：[方案](DAILY-TARGET-RECOMMENDATION-PLAN-20261026.md)。

范围：每日进袋模式；合法球—袋候选经中袋区域/几何/遮挡检查，以W全局排序。既有两球固定anchor与旧评分版本、题库/85门槛/P2保持。手动选择与其他共享页面保留既有策略；不增加公式或分数面板。

## 接线与实现决定

- 新的Core `DailyShotRecommendation` 独立于冻结的AngleSceneCalculator；生产中袋区域按实测口沿、圆角位置/半径/角区间绑定，未知几何不使用排除式。
- `ShotComfortScore` 提供显式aim纯计算；TwoBallComfortScore保留原返回类型/版本/固定anchor，用共用函数执行同样D/E/A计算。
- 每日候选缓存包含策略身份；全合法目标最高W，同分保留当前有效组合，再用稳定标识排序。空候选进入原临时自由流程。
- `PlannedShot.pocketAim`为可缺省字段（归一化坐标）；每日胜出瞄点进入当前意图、序列化与ShotInput.pocketAimOverride，旧记录缺省仍用原求瞄。物理落袋判定不变。
- 源码before身份保存在 `output/daily-recommendation-implementation-20261026/before/`。新推荐不走全候选物理预测，后续仅预测选中杆。

## 页面局部检查

|条款|判定与处理|本轮证据|
|---|---|---|
|TP14|按业务调整：每日从最近/75°优先改为合法候选W；手动选择及反馈继承|新策略11项、每日既有18项、手机及iPad选择UI通过|
|TP15|继承：完整意图、代际取消、提交aim随快照走|实际ShotPredictor aim一致＋PlannedShot新旧解码通过|
|TP16|继承：2D/3D同VM结果|手机横屏和iPad横竖2D/3D往返通过|
|TP24|继承：算法分项留内部，不增加显示|源码与最终原生截图检查通过|
|TP29|继承：生产几何校准与物理预测分开；区域不是进球保证|原研究＋4个远端直进物理见证＋64个贴库样本通过|
|TP30|继承：盘面稳定后计算、缓存失效、离页取消|旧流程与手动意图/无候选恢复回归通过|
|TP35|按局部改动验证；不重做布局全矩阵|手机2D/3D＋iPad横竖定向检查通过；真机/VoiceOver/全矩阵未测|
|TP36|本卡和每日设计规格记录本页策略，不改其他练习默认|每日DC16、信息架构、UI实施合同和本卡已更新|

## 验证轮次

1. `14a6cfba12b34f56807bcfebcf635d80`：构建题库源码校验拒绝AngleSceneCalculator文件变化，未执行测试。没有关闭校验或改题库manifest；新策略迁入独立Core，AngleSceneCalculator恢复本轮before逐字节，782528题正式校验通过。
2. `3a6f33fa0ae14ddf85dec9ed7ede828b`：49项单元/集成中48通过，1个距离断言因Float sqrt/hypot差1ulp失败；统一新候选距离为Double hypot后复验通过。旧UI用例仍找顶栏视图按钮，实际按钮已移入更多菜单；只更新测试导航，不改生产UI。两球25项在此轮全部通过，包括旧版本/36个黄金样本/22停点/578参考路线与参数题库。
3. `r3`：新策略8＋旧每日18项、手机2D/3D UI通过；`pad`：同样8项及iPad横竖2D/3D UI通过。7个对照球形的额外真实预测揭示：高分裸袋嘴端点可导致近袋球误荐。
4. `final`（被否决的尝试，保留日志）：用直线与捕获区相交做硬门槛，造成60个贴库候选误删，且近袋问题2项仍失败。该尝试已移除，不作为生产结论。最终使用已有clean pipe检查有限样本；无此类可用候选时惰性复用原effectivePocketAimPoint作单个后备，仍经区域/主库/遮挡/切角检查。新策略不改变物理引擎，也不跑全候选模拟。
5. `pipe`：修正后的9项通过，近袋球1.5/3m/s真实进袋、64个贴库候选保留。增加圆角角区间版本绑定、无候选→临时自由→恢复集成测试及正式性能计时。
6. 最终`verified`：11项新策略＋18项旧每日全部通过；iPad Pro 11 M4 / iOS26.3.1，横竖屏各自2D/3D UI通过。最终`phone`：同一最终构建在iPhone16ProMax / iOS26.3.1，2D/3D规则拒绝与手动选择UI通过。合计54项不同单元/集成用例（11＋18＋25），3次定向UI执行（手机横屏、iPad横/竖），均有实际Executed结果；不把尝试轮次重复累加。

## 最终证据与边界

- 代码/研究/截图：[交付目录](../output/daily-recommendation-implementation-20261026/)。最终源码SHA见`source-binding-final.json`，最终日志/结果包为`verified.log/.xcresult`和`phone.log/.xcresult`；旧分证据为第2轮xcresult，不因后续推荐模块变化而失效。
- [7球形新旧对照图](../output/daily-recommendation-implementation-20261026/comparison.png)、[原始候选数据](../output/daily-recommendation-implementation-20261026/comparison.json)。统一W比较各自实际aim；较远1号球W89.2胜过旧近球2号W61.6，低分W15.1仍入选，无候选返回空。
- [手机2D](../output/daily-recommendation-implementation-20261026/screenshots/verified-phone-selection-valid-landscape-2d.png)、[手机3D](../output/daily-recommendation-implementation-20261026/screenshots/verified-phone-selection-valid-landscape-3d.png)、[iPad横屏3D](../output/daily-recommendation-implementation-20261026/screenshots/verified-pad-selection-valid-landscape-3d.png)、[iPad竖屏2D](../output/daily-recommendation-implementation-20261026/screenshots/verified-pad-selection-valid-portrait-2d.png)。截图为规则选择夹具，不声称完成整局清台；核心选择/手动状态/实际预测用集成断言验证。
- `verify_grid_bank.py`正式校验782528布局通过；AngleSceneCalculator与本轮before逐字节一致，未改变题库manifest和旧分口径。
- 生产代码Debug模拟器性能：80个15球盘面，均值32.17ms、P95 40.39ms、最大44.81ms，含几何/袋口管道/评分/排序，无候选缓存；选中杆物理预测和UI不在计时内。此前-O原型0.044ms不代表最终代码。真机、Release端到端及用户实际推荐体验尚未验证。
- 区域是当前App几何的候选外沿，不宣称普适真实球桌角度或保证进球。有限样本及管道后备仍是初步推荐；不按完整物理结果再悄悄换球袋。
- 未运行全App矩阵、真机或VoiceOver；未提交、合并、发布。测试设备租约已由fleet归还；本轮两个受管构建目录在证据导出后关闭，原失败结果保留。


## 其他入口复用盘点（2026-10-26）

用户要求“把这个记录下吧，然后你看看其他地方哪里可以用到，同时记录到球桌统一规范中”。本轮检查实际调用方并回填规范，只记录推广建议，不改变其他页面生产开关。共用合同落在TP14/29，验证仍按TP15/16/24/26/30/33–36；不把每日54项测试作为其他页面验收。

|入口与建议顺序|源码核对的现状|可以复用什么；保留什么|当前状态|
|---|---|---|---|
|已接入：每日清台|FreePlayView仅在isDailyClearance时开启usesDailyShotRanking|完整区域＋线路＋W；合法目标来自规则层|已实现，验证见上文|
|已复用：两球自由成绩|TwoBallQuestionPreparer的TwoBallComfortScore调用ShotComfortScore|共用D/E/A/W数学；固定anchor与历史版本保持；新区域尚未接入该消费链|数学已接入；本轮不动题库/排序/P2|
|优先1：多球走位|同用FreePlayView/PositionPlayViewModel；MultiBallPracticeController提供legalKeys，中八限己方/黑八最后，顺序玩法只返回最小号|中八可在合法己方球间推荐；顺序玩法只为当前指定球选袋。保持失败、成绩、重开和权限合同|适合完整策略，但目前开关未启用|
|优先1：普通自由击球|同宿主，usesDailyShotRanking仍为false|在本页玩法合法集合内推荐球＋袋，保留主动自由、手动意图与开球阶段|待接入与该页验证|
|分离角与走位工具；编辑宿主排除|FreePlayView区分shotSimulation/editor/tryout及sequenceReadOnly|工具已接入；编辑器及其试打/自定义球形保持作者目标、编辑操作和序列|用户确认编辑器不需要推荐，不列后续接入|
|优先2：蛇彩|SnakePracticeController.legalAimTargets仅返回当前targetKey|只对当前顺序球选袋；不能改变出球顺序、失误规则或成绩|适合“单球多袋”，未接入|
|排除：思路/规划|SiluTrainerViewModel保留现有规划逻辑|用户确认不需要接入初步自动推荐|不列后续待办，也不是本次未完成项|
|后续：角度与瞄准、分离角图谱、加塞吃库图谱|AngleDynamicViewModel、SeparationAngleAtlasViewModel、CushionEnglishAtlasViewModel的selectBestPocket以小切角为主|优先只复用中袋区域过滤自动初选；教学仍可观察大切角或手选不可进方向，不按W强行改教学主题|区域能力候选；暂不建议统一W排序|
|离线/未来：新题生成与教学区域图|准度/分离角/两球题目有固定目标与袋；两球消费仍有独立85筛选和sourceRecommendationRank|新生成流程可用区域初筛、W分层或目标球位置图；保持实际物理核验。图示按目标球心区，不当成母球走位区|提案；未改任何现有题库、题面答案、历史分或参考顺序|

源码锚点（本轮只读核对）：[共享宿主](../QiuJi/Features/PositionPlay/Views/FreePlayView.swift)、[共享VM](../QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift)、[多球规则](../QiuJi/Features/MultiBallPractice/MultiBallPracticeController.swift)、[蛇彩规则](../QiuJi/Features/SnakePractice/SnakePracticeController.swift)、[思路](../QiuJi/Features/PositionPlay/ViewModels/SiluTrainerViewModel.swift)、[角度图谱](../QiuJi/Features/AngleTraining/ViewModels/AngleDynamicViewModel.swift)、[分离角图谱](../QiuJi/Features/AngleTraining/ViewModels/SeparationAngleAtlasViewModel.swift)、[加塞图谱](../QiuJi/Features/AngleTraining/ViewModels/CushionEnglishAtlasViewModel.swift)、[两球评分/题库消费](../QiuJi/Features/TwoBallPractice/TwoBallQuestionPreparer.swift)。

后续建议先做多球走位与普通自由击球，复用现成合法集合与宿主；本轮仅记录，未获得或执行这些页面的推广实施。性能预算按具体消费者实测；32ms均值/40ms P95仅为已记录的15球Debug模拟器算法耗时，不作为其他页面或真机承诺。


2026-10-26后续授权与状态：用户已确认“好的，开始吧”，上述普通自由击球、多球、蛇彩及分离角与走位工具进入首批接入；上表“未接入/仅记录”是盘点时快照，最新实现与本轮验证以[接入记录](SHOT-RECOMMENDATION-REUSE-20261026.md)为准。用户随后确认编辑器和思路规划不需要接入；编辑宿主及规划保留现状，不列后续待办。图谱/离线仅为范围外能力提案。
