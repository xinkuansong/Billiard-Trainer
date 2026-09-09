# 半遮挡独立数值诊断结果

2026-09-08，formal-004-half-occlusion-001：1方法、3对照通过，0.011秒，make0，52文件及xcresult归档。主控已读三行原JSON，失败列表为空。

新专用47BE1C4D-19C6-4320-8E39-07C17259F9CE，iPhone17Pro/iOS26.2。QiuJiDiagnosticMemoryHost在App初始化前传-v50.inMemoryStore，无身份或权益fixture。唯一selector：HalfOcclusionDiagnosticTests/testSameTargetFullHalfAndClearAngularCoverageMatchesIndependentIntervals。session61516终态0。

同一目标、单障碍的全挡/半挡/全见对照，独立角区间比例1、0.5、0。生产single/multi/defense的余量约+3.287013、−3.276239、−18.985670度，身份_9和全挡分类一致；目标半张角保持3.2762389183度。生产没有fraction字段，比例来自独立数学计算，不以blocked=false替代半挡证明。

主控执行前另用Python复算切线三角形golden，见archive/quality-diagnosis/observations/half-occlusion-root-golden.json。字面球半径0.028575米的硬前提通过。Double独立区间与Float生产结果的误差在1e-4度以内。

原件在archive/quality-diagnosis/runs/formal-004-half-occlusion-001：Test-QiuJiDiagnosticMemoryHost-2026.09.08_20-00-47-+0800.xcresult，以及screenshots/half-occlusion-58FBC30B-C702-4AEF-8EBD-BC08F97181A5/three-interval-comparison.json。

补齐SC22全/半遮挡的独立数值缺口。仅证明接触射线角区间，不是像素比例、多障碍并集、角度环绕、贴球或真实球桌精度。U层没有UI或录屏声明。其他工具边界沿SOLVER-BOUNDARY-CLOSURE-004-AUDIT保留；完整合法思路/三球零候选未验如实列，不新增每模式必空数组要求。未改生产几何，无新增问题。
