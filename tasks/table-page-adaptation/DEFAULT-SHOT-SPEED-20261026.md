# 默认杆速统一为 2.0（2026-10-26 / DR-440）

用户决定：“把1.5和2.5这种默认的都统一成2.0吧，其他的逻辑不变”。本轮局部参数调整；不采用前轮讨论中的新重置规则。

## 实现与范围

- `ShotTuning.defaultVelocity` 从1.5改为2.0；现有消费者（自由击球/走位/每日/蛇彩/多球共用宿主、准度、分离角图谱、加塞图谱、瞄准修正及控件预览）继续原初始化与恢复时机。
- `SeparationInput` 从出题均值2.5解耦，改取共用默认；分离角/两球的新输入及中杆参考均为2.0，参考图例AX同步。
- 斯诺克战术只读参数初始/清空显示从2.5改为共用默认；求解返回的真实速度不变。
- 跟随上一杆、重打/回放、持久化恢复、打点规则、题库及序列显式杆速不变。不迁移旧记录。
- 保留分离角随机出题均值2.5、教学验证/回放默认3.3、调试夹具/入门动画/物理案例的显式1.5或2.5；它们不是普通击球初始值。

## 局部TP检查

|条款|判定与本轮处理|证据状态|
|---|---|---|
|TP09/10|继承；默认值与参考朗读改2.0，输入范围/手势保持|源码差异与语法检查通过；原生UI/VoiceOver未运行|
|TP11/25/26|继承；打点/重打/回放/持久化逻辑不改|本轮差异未涉及状态机；未重跑设备流程|
|TP29/32/33|按业务调整；默认参考采用2.0，题目分布和教学明确参数保持|题库依赖复核及完整内容校验通过|
|TP35/36|继承；记录构建范围及未验项，同步现行TP10和来源|Debug模拟器构建通过；真机/视觉未验|

没有页面布局/组件样式修改，不机械扩展全设备矩阵；本卡不替代原页面完整检查表。

## 验证与证据

- 修改前文件及HEAD：`output/default-speed-20261026/before.json`、`head.txt`；本任务独立差异：`task.diff`。
- 六个Swift源文件语法解析退出0：`output/default-speed-20261026/syntax-check.log`。
- 首次构建被题库整文件SHA守卫拒绝（exit65），原日志保留：`output/local-test-runs/8ccc439fc8a24927b455798a5cc4c5a9/evidence/build.log`。
- 复核修改前常量文件与题库已认证SHA一致，去注释后唯一可执行差异为UI初始值1.5→2.0；其余所有认证物理源字节不变，且这些源不消费该UI默认值；题库内容SHA不变。证据：`output/default-speed-20261026/bank-source-revalidation.json`。据此只更新manifest对应源SHA；未更改校验脚本/题库/其他SHA，也不冒称重跑物理筛选。
- `verify_grid_bank.py` 通过：782528 layouts / 178 occupied combinations。
- 第二次通过Makefile `_test TEST_ACTION=build`执行generic iOS Simulator Debug编译，`build-r2.log`包含`** BUILD SUCCEEDED **`（命令退出0）；该动作是构建，不是XCTest执行。未运行XCTest、模拟器UI或真机；未安装/提交/发布。
- 实现、语法、题库内容校验及编译完成；原生视觉/手感未验证，等待用户体验反馈。临时构建通过local lifecycle complete收尾，首次失败日志保留。

## 2026-11-15续打复位

用户确认第一批为每日清台、自由击球、蛇彩练习、多球走位、自定义球形练习及分离角与走位。普通击球动画停稳后，下一杆打点回中、杆速回到2.0 m/s。已有的重打、回放继续读取实际出杆时的输入。

|条款|本轮处理|
|---|---|
|TP10/11|六入口沿用共享力度尺与打点盘；在结算回调及下一杆预览前重置草稿，复用`ShotTuning.defaultVelocity`。|
|TP25/26|本杆评分及回放读取出杆快照；重打恢复实际输入；回放结束回到进入回放前的草稿。规划顺延、保存进度使用当前草稿。|
|TP35/36|定向核对一次击球、下一杆草稿、重打及回放；更新统一规范及来源表。|

通过 `FreePlayRulesSession`、`CustomFormationSession` 和练习卡实际使用的 `PositionPlayComposerView` 显式接入；动作库试打、拍照导入、模板编辑及内部内容编排沿各自规则。回归断言覆盖非默认出杆到默认续打、重打恢复真实输入，以及完整/中断回放后保留当前草稿。

验证：Swift 语法解析、差异与文档门禁通过；首轮 iOS Simulator `build-for-testing` 成功。最终轮的练习卡接线通过 arm64 编译，构建继续时在 x86_64 临时目录创建处遇到磁盘写满，未形成最终构建。手机模拟器有保留现场，Mac mini 连接超时，未执行 XCTest 或六页交互。两轮日志保留，独占工作目录已由本地生命周期释放。[构建日志](../../output/local-test-runs/51b055ef9b654e629707fff7bebf191f/evidence/build.log) · [最终轮日志](../../output/local-test-runs/51b055ef9b654e629707fff7bebf191f/evidence/build-final.log)。

同日补验：Mac mini 的 iPhone 17 / iOS 26.2 完整构建通过。六页各以非默认杆速和偏高打点实际出杆，停稳后读取中心球和 2.00 m/s。自定义球形与分离角与走位另核回放返回下一杆草稿、重打恢复本杆实际输入。最终 UI 测试 6/6 通过，两项击球快照与回放/重打的 XCTest 在同生产源码的前轮通过。中间失败保留原记录，最终测试改用打点盘外部关闭，出杆前后原图核对红点确实偏离中心再回中。真机及全 App 回归未执行。[六页原图](../../output/next-shot-screens-20261115/screens) · [最终测试结果](../../output/next-shot-screens-20261115/r7/evidence/test-summary.json) · [出杆前后原图复核](../../output/next-shot-screens-20261115/r7/spin-mini-image-check.json)。
