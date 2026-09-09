# Snapshot004 回放选袋覆层审计

日期：2026-09-08。只读源码与既有录像抽帧；未运行设备、测试或修改业务。建议主控记录产品问题：**上一杆回放期间显示下一杆的目标袋标记，回放提示与当前动画上下文不一致**。建议暂列 P2 展示/教学语义问题，最终优先级由主控裁定；不需要把已观察的现象整个留为待定。修复选择（隐藏标记还是临时显示上一杆选袋）仍可待产品决定，不在本诊断实施。

## 实际图像证据

本审计实际打开 `build/quality-diagnosis/observations/formal-004-repeated-shot-001/review-frames-002/cycle-01-contact.png`。按 manifest 的行优先顺序，格 0–5 是击球，6–10 是回放，11 是重打恢复：原击球黄球趋向左上袋，红色圆标记在左上袋；格 6（回放点击前 0.3 秒）已为下一杆蓝球预测、右中袋红标记；格 7–10 黄球再次出现并移向左上袋、随后离场，红标记仍在右中袋。格 11 重打恢复后红标记回左上袋。这里“左上/右中”仅指截图显示位置，不推导世界坐标或物理误差。

manifest 标明每轮 6 个击球、5 个回放、1 个恢复抽样，并非逐帧审计；视频 SHA256 为 `d8b0717dd463bc23a37b9a4211c0e437d879c84322886daf8cd750703a49b648`（来自 manifest，本审计未重新 hash 录像）。其 humanVerdict 字段仍为 pending，不能把自动提取清单当图审通过。主控已另行审十轮，本独立审计只声明实际目视的 cycle-01，不扩写为本人已复核十轮。

## 冻结源码因果链

以下路径均相对 `archive/quality-diagnosis/snapshot-004/source/`，行号基于本次实读。

| 入口/状态 | 精确文件与行号 | 支持的判断 |
|---|---|---|
| 回放与重打分离 | `QiuJi/Features/PositionPlay/Views/FreePlayView.swift:230–239` | 重打调用 replayCurrent，回放调用 replayLastShot；不能把两者都要求回到上一杆作为判据。 |
| 上杆上下文存在 | `QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift:1084–1085` | play 保存 before、shot、prediction；上一杆参数没有丢失。 |
| 自动下一杆 | 同文件 `1191–1203`、`714–721` | 停稳后自动选下一目标、下一袋并重算；红标记直接根据当前 aimMode 和 selectedPocketIndex 更新。 |
| 回放不切选中态 | 同文件 `1332–1352` | 注释明确回放不改变桌面真相、参数/选中态/序列不动；实际仅清 selectionNodes、自由瞄准覆层和轨迹，重新放 ctx.before 的球。没有隐藏 pocketMarkers，也没有用 ctx.shot 的袋口临时展示。 |
| 真正运动来源 | 同文件 `1359–1373`、`1378–1395` | 出杆和球动画使用 ctx.shot、ctx.prediction.recorder，而非下一杆预测；画面一杆运动/另一杆红标记的混合上下文可由源解释。 |
| 红标记是什么 | `QiuJi/Core/Scene/AngleTrainingScene.swift:1320–1337`、`1349–1356` | 红色材质 pocketMarker 直接挂 rootNode；selected 显示，viable/infeasible 隐藏。它是选中袋，不是回放落袋检测失败标记。 |
| 回放收尾 | VM `1414–1426` | 恢复 after 后才 updatePocketHighlights；与上述回放中残留一致。 |
| 重打才恢复参数 | VM `1299–1327` | restoreShotParams + applyBoard + updatePocketHighlights，解释恢复格为何重新出现左上红标记。 |

## 规格判断与边界

冻结源码 `1332–1333` 明确“不改变当前局面/参数/选中态”，这是持久状态与操作语义；它没有要求播放期间把下一杆的选袋覆层叠在上一杆动画上。保持选中值并临时隐藏覆层也能满足该语义。因此不把该注释解释为对误导展示的产品豁免。

冻结 `docs/research/20260709-翻袋反射页重构方案.md:183` 对相邻共用回放模式描述“重播上杆 prediction，播完回停点”，可辅助理解播放语义，但它是翻袋/反射方案，不能冒称 FreePlay 独立强制验收条款。本次针对冻结 docs 和相关源码的检索未找到明确规定“自由击球回放期间必须隐藏/切换袋口标记”的规格条文；源码提及的布局规范 v2 条 18 / 15.7 和 ADR-P11-04 未在冻结 docs 找到可直接引用原文。因此结论为**有实图及源码支持的 UI 上下文不一致**，不是宣称违反某条已核产品原文。

不据此宣称物理轨迹错、进袋判断错、录像数据错、回放改变规则成绩或丢球。也不能从这几张图证明其他页面都有同缺陷；共享 VM 的消费者只列潜在影响面。既有 `QiuJiTests/PocketMarkerHighlightTests.swift:52–74` 只检验可见性切换及不修改 live material，未覆盖上一杆回放与下一杆选择的组合。此轮未重跑该单测。

建议问题验收口径：保持回放结束后的局面、参数和下一杆选择；回放进行时不显示与正在回放的上一杆不一致的目标袋提示。隐藏全部选袋提示或按上杆上下文临时展示皆可作为后续方案，需以真实动画和回放结束状态一起复核。
