# 两球参数题库正式接入（2026-10-26）

状态：已接入并通过本轮构建、全量数据审计、21单测＋4项UI验证。待真机体验；未提交、未发布。

## 授权与范围
用户在参数包原型及实时生成速度/一致性验证后授权「好的，接入到app中吧」，并要求「做好记录」。原型记录：TWO-BALL-PARAMETER-BANK-20261026.md。保持166443题、677488条推荐、原推荐顺序、坐标精度和物理/评分口径；只改变资源存储与消费方式。不发布、不改研究源库。

## 实施与验证计划
- 原正式包及相关消费代码备份到 output/two-ball-parameter-consumer-20261026/before/（App包外）。
- 生产参数包增加版本/物理/评分合同；整库逐字段及引用顺序审计后切换。
- 按参数后台生成并核验进袋、库序、袋角、母球安全、碰B及≥85舒适度；以事件顺序判定首次接触后的吃库，保持2mm轨迹压缩。不得虚构离线对拍RMS。
- 当前题保留生成快照；下一题预加载沿用现有流程。旧记录可读，旧版本练习不混入新库。
- 生产路径原138题/578路线回归、单元测试与2D/3D模拟器流程；检查构建包只含参数资源。
- 收尾记录实际大小、测试证据、设备租约、限制和回退方法。

## 回退
将 before/QiuJi/Resources/TwoBallBank 与备份的 TwoBallPractice 消费代码、TwoBallPracticeTests 配套恢复，重新生成工程并构建；不得只回退索引或混用分片。备份属于本任务，完成前不删除。

## 已完成实现

- `TwoBallBankStore`读取生产参数格式；分片SHA/大小、精确布局与网格分类关联、打点/方向/库序/引用校验，两片LRU。
- `TwoBallQuestionPreparer`以已存参数真实模拟，检查资格后生成2mm参考线、舒适度、E；`replayRMSCM`改可选，新的nil与旧记录数值含义明确区分。首次接触和库序按event顺序处理。
- 设置页后台预热索引和只读球杆profile值，后续复用；沿用已有下一题后台准备、排除重复和按指纹隔离机制。没有添加页面/改变布局。
- 新policy将旧练习段保留到历史并要求重新开题；无需SwiftData迁移，当前题及完整实际回放仍按原TB01持久化。

## 数据与构建包实测

|项目|数值|
|---|---:|
|原完整包|367,798,287 B（367.80 MB）|
|现参数gzip|30,612,172 B|
|现索引|840,356 B|
|现合计|31,452,528 B（31.45 MB，29.995 MiB）|
|缩减|91.45%|
|布局／题／推荐／共享参数路线|13,358／166,443／677,488／552,055|
|分片|1,357|

源索引SHA：`6186e5b85eb5afa353cf8e4d746732431ca250871859722363222cf360be875b`。
现索引SHA：`1e18a0ac319027d4db876b9b2d05715d1bc47af88d419c5d01f591272d43bbbe`。
全量两侧SHA、参数、引用及排序审计通过：`output/two-ball-parameter-consumer-20261026/audit.json`。
真实构建产品中的1,358个题库文件逐一SHA通过，只有一个TwoBallBank目录。578参考样本只在测试target的fixture中，不属于App资源：`bundle-and-unit-audit.json`。

## 单元及生产路径回归

受管测试 `output/local-test-runs/ab29bef6fb0c400abf1f97eb2d45ec47/evidence/tests.xcresult`、`test-results.log`：**21 tests，0 failures**（8.581秒）。覆盖参数损坏、物理生成、错库序、碰B、舒适度、输入轴过滤、原记录解码/不能续练、历史/扣额、保存失败、owner迁移和连续出题。

冻结128随机题＋边界样本共138题/578推荐，使用正式store＋materialize路径逐条对拍：停点、2mm点列（含时间）、事件锚点、库序全部精确一致；三个舒适度分项最大差2.32144e-5，85资格和原排序不变；E最大差4.44e-16。两条同时间戳首碰前碰库边界也纳入样本。

App Debug／M5 Pro／iOS26.3.1模拟器已预热后的21次完整选题：中位30.45ms、范围27.89–35.95ms，最大记录payload34745B。仅为该环境的选题测试计时，不含首次预热/场景呈现，不代表真机帧率或冷启动。原型Swift-O独立计时仍见原型任务卡。

## UI验证、收尾与边界

同一受管构建的 `evidence/ui.xcresult`／`ui.log`：**4 tests，0 failures**（145.340秒），分别为 `testComfort85ExecutionOrder2D`、`testComfort85ExecutionOrder3D`、`test2DFreeFlow`、`test3DFreeFlow`。覆盖原推荐升序、≥85、逐条切换，以及自由练习提交、分项详情、重打、回放不重复计杆、下一题和完成摘要。无需重建UI。

真实截图和状态探针已导出到 `output/two-ball-parameter-consumer-20261026/ui-attachments/`。目视2D/3D首路线、2D自由初始、3D自由下一题：三球/袋口/参考线与目标线呈现、进度及操作区正常，未见本轮新增遮挡。全导出索引为manifest.json，核图名单见closure.json。依球桌页局部复核TP22/25/26/29/30/33/35/36回填原检查表。

设备：large-phone `16D968CB-FA14-4E00-B79F-0D675D80179E`（iPhone16ProMax／iOS26.3.1）已Shutdown，实际registry无lease。测试工作区通过local_test_lifecycle complete回收，证据保留，真实可用空间增加1,626,030,080B（约1.63GB）。旧包/消费代码备份保留在App包外，`tested-source-sha256.json`绑定本轮源码与fixture。构建与UI均一次通过；首次附件导出在xcresult尚未关闭时不可读，等待关闭后成功导出，未修改测试期望。

未做真机性能、完整设备矩阵、真实云同步和发布；未声称逐条重放全部677488推荐。UI显示60FPS不是性能验收。参数资格受当前物理/Float环境复核，不能对不同引擎版本承诺绝无路线剔除。

## 复现命令与证据入口

- 打包：`python3 scripts/two-ball-consumer/pack_parameters.py FULL_BANK NEW_BANK PACK_REPORT`
- 审计：`python3 scripts/two-ball-consumer/audit_parameters.py FULL_BANK NEW_BANK AUDIT_REPORT`
- 单测：`python3 scripts/simulator_fleet.py run --role large-phone --task two-ball-parameter-consumer -- make -f scripts/Makefile test TEST_DESTINATION='platform=iOS Simulator,id={udid}' ONLY_TESTING=QiuJiTests/TwoBallPracticeTests`
- UI按上列4方法选择、同受管DerivedData执行test-without-building；实际xcodebuild命令保留于ui.log（通过Makefile生成），禁用并行克隆。普通复现也可用同一Makefile test入口重新构建。
- 数据：[全量审计](../output/two-ball-parameter-consumer-20261026/audit.json)、[构建/单测](../output/two-ball-parameter-consumer-20261026/bundle-and-unit-audit.json)、[收尾](../output/two-ball-parameter-consumer-20261026/closure.json)。
- 总方案：[TWO-BALL-BANK-COMPLETE-SCHEME-20261025.md](TWO-BALL-BANK-COMPLETE-SCHEME-20261025.md) §15；架构决策：[ADR](../docs/ADR-two-ball-parameter-bank.md)。
