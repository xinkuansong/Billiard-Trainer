# 思路下一解、真实击球及恢复结果

2026-09-08 思路训练矩形正例下一解→实打→上一杆→再下一解补验1/1通过61.355秒，runner0/recorder0，1265运行文件及6观察文件归档。实际解2/5低杆3.5一库，终态黄1离台、母球停在原落区内；上一杆恢复两球中心/尺寸≤2pt、矩形/轨迹/3.5杆法，未重求解直接下一解得到3/5，证实缓存索引恢复。主控4张完整PNG已审；见SILU-SHOT-004-RESULT.md。

正常练习→解→思路训练，原实测401DEA72-01DD-46C2-B774-86B7D58BC06C/iPhone17Pro26.2，Light/large读回；inMemory/forcePremium只隔离和访问，没有球形/物理结果注入。唯一selector SiluShotDiagnosticUITests/testObservedRectangleNextSolutionStrikeAndUndoRestoresBoardAndSolutionIndex。session30421终态0；xcresult Test-QiuJi-2026.09.08_19-39-57-+0800.xcresult。

主控完整图审4–7：第二解5选2，黄球左上袋轨迹、矩形；实打后黄球回库、台上仅母球，无scratch，旧约束清除，上一杆/回放可用而击球/下一解禁用；恢复后两球、矩形和杆法/预测与第二解一致；再下一解显示3/5低杆5.2二库，无再次求解。摆球工具选中是源码restore将activeTool复位.none的行为，不要求恢复绘制工具激活态。

终态母球AX框(187.0,390.3,18.9,18.2)完整包含于当次已画矩形(105,310)–(295,640)，独立包含计算与PNG一致。只是屏幕落区一致性，不证明厘米余量、全物理精度、碰撞过程或袋口进球逐帧；连续视频已归档，未逐帧审。保持对原真正空解、三球默认扇形满足等缺口的独立判定，SC22不整项改passed。

运行源/日志/xcresult/PNG：archive/quality-diagnosis/runs/formal-004-silu-shot-001；录像与PID/RSS：archive/quality-diagnosis/observations/formal-004-silu-shot-001；图审SHA与包含计算：silu-shot001-review.json。此次没有新增产品缺陷。
