# 防守轨迹库剔除袋角走位

状态：已完成正式替换；生产加载器、全库事件检查、边界用例及入库反例检查通过。

用户要求：母球或目标球借袋角走位的参考解剔除。范围是防守轨迹参考内容，不把该限制改成用户击球犯规。

## 判据与根因

使用真实expected事件（上一轮已原生核验）。生产TableGeometry的linearCushions 0–5为六段普通直库；之后为角袋jaw、中袋喉壁、深部壁面，circularCushions编号从当前44起。任何球发生cushion且railIndex不在0–5（含缺失/未知编号），整条参考解剔除；不以靠近袋口或轨迹图外观判定。正常直库反弹保留。此前仅统计主库次数，袋角接触未触发限制；此次717个实际命中均为44–55的圆弧事件。

一道题有其他合格解则保留；删光参考则移出轨迹库。自由库球形不受该参考解条件影响。保留的球位、镜像方向、球权、ID及参考payload逐项与原包完全相同；无需对未改动出杆参数重搜或重复物理回放。

|类别|原题数|移出题数|保留题数|
|---|---:|---:|---:|
|单黑八|752|43|709|
|黑八＋对方球|1038|58|980|
|我方球＋黑八|1050|64|986|
|双方各一球＋黑八|1142|40|1102|
|合计|3982|205|3777|

9836参考删除717，保留9119；561道题受影响，356道仍有其他参考。自由58470题SHA不变。

## 准入与发布

- DefenseReferenceRoute按已存事件预筛参考，eventsMatch同时检查真实回放的cushionIndex；两处均覆盖所有球。用户solve/DefenseEffect.failure与计分逻辑未改。
- scripts/defense-bank/pack.py新导出拒绝袋角接触；v3策略参数包audit同样拒绝。历史研究快照保留原代码，不能绕开新正式入库门禁直接发布。
- 新源output/defense-no-pocket-20261105/bank/；report.json、removed-references.json、coverage.json保存每条剔除事件及缺解题清单。before保留原轨迹gzip。
- 同步App轨迹资源SHA/sourceFingerprint/训练指纹/题数断言。历史记录不改。

## 验证范围

pack.audit通过；精确子集重建、自由资源SHA、生产Store真实读取与56个球号/索引边界用例检查见consumer-check/result.txt。Swift预处理器/测试语法检查通过。新增XCTest覆盖准入，但未执行完整XCTest或UI测试；不宣称App整体验收。

附加门禁反例：构造有效SHA/索引但含44号袋角事件的参数包，pack.audit以pocket-contact拒绝。
