# 动作库序列：当前引擎重录核验（2026-10-14）

用户决定停止压缩并自行用编排台重录；本轮只读检查，不回写任何原序列。未验收的压缩源码与资源已撤回；上一版已验证的蛇彩2轨迹实现保留。

## 核验口径

- 覆盖98条动作库序列、629杆；5条个人测试序列不计。以首杆before作为开局（与App入口相同），每杆另从存档before独立求解；同时从实际停点连续接续，作者主动重摆时按现有SequenceSceneTransition规则恢复下一球形。连续播放一旦不可行则标记后续未运行，独立单杆仍全部检查。
- 全部直接调用当前PositionPlayShotSolver，绕过旧方向与冻结轨迹兼容。保留当前物理和瞄准改进；误差用SceneKit X–Z世界坐标换算毫米，原0.1mm标准不放宽。
- 独立arm64 iOS模拟器引擎程序运行两轮；当前求解器／物理源码原样复制，Debug浮点编译条件。界面资产加载不在该平面引擎路径中，若误入会明确失败。来源哈希、编译参数与逐杆结果见output/sequence-current-engine-audit-20261014/。
- 完整App测试构建被并行修改中的PlanThreeView.swift类型检查错误阻断（audit-r1.log），不代表这些序列已逐一经过界面或真机验证。
- **蛇彩2特例**：当前App已有冻结旧轨迹，能完整回放；表内记录的是绕过兼容后由当前引擎重新计算的结果，供决定是否重录。

## 汇总

- A 播放会中断：6条。
- B 能播完但进球结果不符：11条。
- C 能播完但停点偏差较大（>10mm）：48条。
- D 其余停点或单杆不符：20条。
- E 全部符合：13条。

两轮分类不稳定：0条。部分浮点尾数及首次越界球报告顺序不同，未影响结论；重复终位差异小于0.001mm（见verification.json与run-differences.json）。
优先重录A、B；C按教学走位需要处理。进球结果不同未必更差（部分原存档母球落袋、现在未落袋），重录时先确认教学意图。D仍未满足0.1mm严格复现，但不等于会中断。每条的“首次不符”包含微小走位变化，“中断杆”是播放器准入失败，二者分别列出。

## A 播放会中断

| 动作／球形 | 杆数 | 首次不符 | 中断杆 | 进球异常杆 | 最大停点差 mm | 独立单杆不符 | 原因／备注 |
|---|---:|---:|---:|---|---:|---|---|
| [分离角综合挑战](../content/position_play/sequences/drill_c031__Snipaste_2026_06_19_13_52_32-分离角综合挑战-13杆.json) | 13 | 1 | 1 | — | 未得终位 | 1,2,3,4,5,6,7,8,9,10,11,12,13 | 开局多球与库边相交（两轮首报7／8号），需检查整体摆位 |
| [初级蛇彩走位 · 球形2](../content/position_play/sequences/drill_c042__manual02-初级蛇彩走位%20·%20球形2-5杆.json) | 5 | 1 | 4 | — | 1109.518 | 1,2,3,4,5 | 求解不可行：当前角度无法进袋（切角过大）；没有完整停稳结果；没有轨迹记录；轨迹时长不足；当前App有旧轨迹兼容 |
| [中级蛇彩 · 球形2](../content/position_play/sequences/drill_c069__manual02-中级蛇彩%20·%20球形2-10杆.json) | 10 | 2 | 7 | 6 | 1234.644 | 2,3,4,5,6,7,8,9,10 | 求解不可行：当前角度无法进袋（切角过大）；没有完整停稳结果；没有轨迹记录；轨迹时长不足 |
| [高级蛇彩贴库综合 · 球形2](../content/position_play/sequences/drill_c071__manual02-高级蛇彩贴库综合%20·%20球形2-15杆.json) | 15 | 1 | 6 | — | 1033.600 | 1,2,3,4,5,6,7,8,9,10,11,12,14,15 | 求解不可行：当前角度无法进袋（切角过大）；没有完整停稳结果；没有轨迹记录；轨迹时长不足 |
| [四球走位 · 球形1](../content/position_play/sequences/drill_c079__manual01-四球走位%20·%20球形1-4杆.json) | 4 | 1 | 4 | 3 | 498.209 | 1,2,3,4 | 第3杆母球落袋、目标球未进，第4杆缺少母球 |
| [K球综合挑战 · 球形1](../content/position_play/sequences/drill_c085__manual01-K球综合挑战%20·%20球形1-14杆.json) | 14 | 1 | 1 | — | 未得终位 | 1,2,3,4,5,6,7,8,9,10,11,12,13,14 | 开局多球与库边相交（两轮首报12／11号），需检查整体摆位 |

## B 能播完但进球结果不符

| 动作／球形 | 杆数 | 首次不符 | 中断杆 | 进球异常杆 | 最大停点差 mm | 独立单杆不符 | 原因／备注 |
|---|---:|---:|---:|---|---:|---|---|
| [低杆缩杆回位 · 球形2](../content/position_play/sequences/drill_c004__manual02-低杆缩杆回位%20·%20球形2-4杆.json) | 4 | 2 | — | 2 | 76.824 | 2,3,4 | 进球／母球落袋结果与存档不符；留桌球集合与存档不符 |
| [站位与身体对齐 · 球形1](../content/position_play/sequences/drill_c007__manual01-站位与身体对齐%20·%20球形1-4杆.json) | 4 | 1 | — | 3 | 4.763 | 1,2,3 | 停点误差超过0.1mm |
| [高杆远台跟进 · 球形1](../content/position_play/sequences/drill_c015__manual01-高杆远台跟进%20·%20球形1-8杆.json) | 8 | 6 | — | 6,7,8 | 0.000 | 6,7,8 | 进球／母球落袋结果与存档不符；留桌球集合与存档不符 |
| [五分点瞄准线练习 · 球形1](../content/position_play/sequences/drill_c023__manual01-五分点瞄准线练习%20·%20球形1-8杆.json) | 8 | 1 | — | 3 | 46.449 | 1,2,3,5,6,7,8 | 停点误差超过0.1mm |
| [中台角度球入袋 · 球形1](../content/position_play/sequences/drill_c032__manual01-中台角度球入袋%20·%20球形1-7杆.json) | 7 | 1 | — | 5 | 31.804 | 1,2,3,4,5,6,7 | 停点误差超过0.1mm |
| [两库走位 · 球形1](../content/position_play/sequences/drill_c038__manual01-两库走位%20·%20球形1-12杆.json) | 12 | 1 | — | 7 | 142.886 | 1,2,3,4,5,6,7,8,9,10,11,12 | 停点误差超过0.1mm |
| [强力高杆穿越 · 球形1](../content/position_play/sequences/drill_c047__manual01-强力高杆穿越%20·%20球形1-12杆.json) | 12 | 4 | — | 8,9 | 64.777 | 4,5,6,7,8,9,10,11,12 | 停点误差超过0.1mm |
| [三分点角度入袋 · 球形1](../content/position_play/sequences/drill_c052__manual01-三分点角度入袋%20·%20球形1-7杆.json) | 7 | 1 | — | 6 | 647.803 | 1,2,3,4,5,6,7 | 停点误差超过0.1mm |
| [中袋角度精准 · 球形2](../content/position_play/sequences/drill_c053__manual02-中袋角度精准%20·%20球形2-13杆.json) | 13 | 1 | — | 11 | 219.692 | 1,2,3,4,5,6,7,8,9,10,11,12,13 | 停点误差超过0.1mm |
| [挤偏放大·直球长台 · 球形1](../content/position_play/sequences/drill_c074__manual01-挤偏放大·直球长台%20·%20球形1-6杆.json) | 6 | 2 | — | 2 | 0.000 | 2 | 进球／母球落袋结果与存档不符；留桌球集合与存档不符 |
| [四球同袋叫位 · 球形1](../content/position_play/sequences/drill_c081__manual01-四球同袋叫位%20·%20球形1-4杆.json) | 4 | 1 | — | 4 | 1559.815 | 1,2,3,4 | 停点误差超过0.1mm |

## C 能播完但停点偏差较大（>10mm）

| 动作／球形 | 杆数 | 首次不符 | 中断杆 | 进球异常杆 | 最大停点差 mm | 独立单杆不符 | 原因／备注 |
|---|---:|---:|---:|---|---:|---|---|
| [半台直线球 · 球形1](../content/position_play/sequences/drill_c001__manual01-半台直线球%20·%20球形1-5杆.json) | 5 | 1 | — | — | 32.349 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [斜角入底角袋 · 球形1](../content/position_play/sequences/drill_c002__manual01-斜角入底角袋%20·%20球形1-9杆.json) | 9 | 1 | — | — | 27.888 | 1,2,3,4,5,6,7,8,9 | 停点误差超过0.1mm |
| [低杆缩杆回位 · 球形1](../content/position_play/sequences/drill_c004__manual01-低杆缩杆回位%20·%20球形1-4杆.json) | 4 | 1 | — | — | 378.601 | 1,2,3,4 | 停点误差超过0.1mm |
| [一库走位定点 · 球形1](../content/position_play/sequences/drill_c005__manual01-一库走位定点%20·%20球形1-4杆.json) | 4 | 1 | — | — | 209.741 | 1,2,3,4 | 停点误差超过0.1mm |
| [近台底袋直线球 · 球形1](../content/position_play/sequences/drill_c011__manual01-近台底袋直线球%20·%20球形1-5杆.json) | 5 | 1 | — | — | 58.310 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [底袋小角度入袋 · 球形1](../content/position_play/sequences/drill_c013__manual01-底袋小角度入袋%20·%20球形1-8杆.json) | 8 | 1 | — | — | 76.863 | 1,2,3,4,5,6,7,8 | 停点误差超过0.1mm |
| [低杆远台缩杆 · 球形1](../content/position_play/sequences/drill_c017__manual01-低杆远台缩杆%20·%20球形1-5杆.json) | 5 | 1 | — | — | 58.018 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [加塞一库变线 · 球形1](../content/position_play/sequences/drill_c018__manual01-加塞一库变线%20·%20球形1-9杆.json) | 9 | 1 | — | — | 71.407 | 1,2,3,4,5,6,7,8,9 | 停点误差超过0.1mm |
| [高杆加塞走位 · 球形1](../content/position_play/sequences/drill_c020__manual01-高杆加塞走位%20·%20球形1-16杆.json) | 16 | 1 | — | — | 52.343 | 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16 | 停点误差超过0.1mm |
| [低杆加塞回位 · 球形1](../content/position_play/sequences/drill_c021__manual01-低杆加塞回位%20·%20球形1-12杆.json) | 12 | 1 | — | — | 218.663 | 1,2,3,4,5,6,7,8,9,10,11,12 | 停点误差超过0.1mm |
| [分离角90度规则 · 球形1](../content/position_play/sequences/drill_c024__manual01-分离角90度规则%20·%20球形1-6杆.json) | 6 | 1 | — | — | 27.184 | 1,2,3,4,5,6 | 停点误差超过0.1mm |
| [薄球分离角感知 · 球形1](../content/position_play/sequences/drill_c025__manual01-薄球分离角感知%20·%20球形1-6杆.json) | 6 | 1 | — | — | 525.142 | 1,2,3,4,5,6 | 停点误差超过0.1mm |
| [薄球分离角感知 · 球形2](../content/position_play/sequences/drill_c025__manual02-薄球分离角感知%20·%20球形2-7杆.json) | 7 | 1 | — | — | 1320.191 | 1,2,3,4,5,6,7 | 停点误差超过0.1mm |
| [厚球分离角控制 · 球形2](../content/position_play/sequences/drill_c026__manual02-厚球分离角控制%20·%20球形2-7杆.json) | 7 | 2 | — | — | 616.793 | 2,3,4,5,6,7 | 停点误差超过0.1mm |
| [厚球分离角控制 · 球形3](../content/position_play/sequences/drill_c026__manual03-厚球分离角控制%20·%20球形3-5杆.json) | 5 | 1 | — | — | 17.907 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [远台斜线入角袋 · 球形1](../content/position_play/sequences/drill_c033__manual01-远台斜线入角袋%20·%20球形1-8杆.json) | 8 | 1 | — | — | 168.821 | 1,2,3,4,5,6,7,8 | 停点误差超过0.1mm |
| [不吃库短距离走位 · 球形1](../content/position_play/sequences/drill_c034__manual01-不吃库短距离走位%20·%20球形1-5杆.json) | 5 | 1 | — | — | 11.981 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [高杆一库走位 · 球形1](../content/position_play/sequences/drill_c035__manual01-高杆一库走位%20·%20球形1-8杆.json) | 8 | 1 | — | — | 25.085 | 1,2,3,4,5,6,7,8 | 停点误差超过0.1mm |
| [低杆一库走位 · 球形1](../content/position_play/sequences/drill_c036__manual01-低杆一库走位%20·%20球形1-9杆.json) | 9 | 1 | — | — | 122.396 | 1,2,3,4,5,6,7,8,9 | 停点误差超过0.1mm |
| [直线球组合走位 · 球形1](../content/position_play/sequences/drill_c039__manual01-直线球组合走位%20·%20球形1-8杆.json) | 8 | 1 | — | — | 1704.789 | 1,2,3,4,5,6,8 | 停点误差超过0.1mm |
| [三库走位 · 球形1](../content/position_play/sequences/drill_c040__manual01-三库走位%20·%20球形1-10杆.json) | 10 | 1 | — | — | 50.102 | 1,2,3,4,5,6,7,8,9,10 | 停点误差超过0.1mm |
| [对角走位 · 球形1](../content/position_play/sequences/drill_c041__manual01-对角走位%20·%20球形1-12杆.json) | 12 | 1 | — | — | 232.888 | 1,2,3,4,5,6,7,8,9,10,11,12 | 停点误差超过0.1mm |
| [初级蛇彩走位 · 球形1](../content/position_play/sequences/drill_c042__manual01-初级蛇彩走位%20·%20球形1-8杆.json) | 8 | 1 | — | — | 71.884 | 1,2,3,4,5,6,7,8 | 停点误差超过0.1mm |
| [强力低杆回拉 · 球形1](../content/position_play/sequences/drill_c048__manual01-强力低杆回拉%20·%20球形1-12杆.json) | 12 | 1 | — | — | 100.412 | 1,2,3,4,5,6,7,8,9,10,11,12 | 停点误差超过0.1mm |
| [软打控位 · 球形1](../content/position_play/sequences/drill_c050__manual01-软打控位%20·%20球形1-5杆.json) | 5 | 1 | — | — | 202.847 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [全力度走位综合 · 球形1](../content/position_play/sequences/drill_c051__manual01-全力度走位综合%20·%20球形1-4杆.json) | 4 | 1 | — | — | 100.679 | 1,2,3,4 | 停点误差超过0.1mm |
| [中袋角度精准 · 球形1](../content/position_play/sequences/drill_c053__manual01-中袋角度精准%20·%20球形1-10杆.json) | 10 | 1 | — | — | 108.284 | 1,2,3,4,5,6,7,8,9,10 | 停点误差超过0.1mm |
| [K球不吃库 · 球形3](../content/position_play/sequences/drill_c056__Snipaste_2026_06_19_17_37_37-K球不吃库%20·%20球形3-1杆.json) | 1 | 1 | — | — | 38.048 | 1 | 停点误差超过0.1mm |
| [K球吃库 · 球形1](../content/position_play/sequences/drill_c057__Snipaste_2026_06_19_17_43_31-K球吃库%20·%20球形1-1杆.json) | 1 | 1 | — | — | 47.673 | 1 | 停点误差超过0.1mm |
| [K球吃库 · 球形2](../content/position_play/sequences/drill_c057__Snipaste_2026_06_19_17_45_48-K球吃库%20·%20球形2-1杆.json) | 1 | 1 | — | — | 560.864 | 1 | 停点误差超过0.1mm |
| [K球吃库 · 球形3](../content/position_play/sequences/drill_c057__Snipaste_2026_06_19_17_48_56-K球吃库%20·%20球形3-1杆.json) | 1 | 1 | — | — | 240.728 | 1 | 停点误差超过0.1mm |
| [安全球布置 · 球形1](../content/position_play/sequences/drill_c060__manual01-安全球布置%20·%20球形1-8杆.json) | 8 | 5 | — | — | 48.544 | 5 | 停点误差超过0.1mm |
| [远台中袋直线](../content/position_play/sequences/drill_c062__Snipaste_2026_06_19_17_57_13-远台中袋直线-4杆.json) | 4 | 1 | — | — | 304.566 | 1,2,3,4 | 停点误差超过0.1mm |
| [极薄角度切球](../content/position_play/sequences/drill_c063__Snipaste_2026_06_19_17_58_23-极薄角度切球-2杆.json) | 2 | 1 | — | — | 87.788 | 1,2 | 停点误差超过0.1mm |
| [三球连打](../content/position_play/sequences/drill_c064__Snipaste_2026_06_19_17_59_39-三球连打-3杆.json) | 3 | 1 | — | — | 1128.135 | 1,2,3 | 停点误差超过0.1mm |
| [中级蛇彩 · 球形1](../content/position_play/sequences/drill_c069__manual01-中级蛇彩%20·%20球形1-8杆.json) | 8 | 1 | — | — | 231.516 | 1,2,3,4,5,6,7,8 | 停点误差超过0.1mm |
| [远台直线球极限 · 球形1](../content/position_play/sequences/drill_c072__Snipaste_2026_06_19_18_02_47-远台直线球极限%20·%20球形1-2杆.json) | 2 | 1 | — | — | 80.824 | 1,2 | 停点误差超过0.1mm |
| [挤偏放大·直球长台 · 球形2](../content/position_play/sequences/drill_c074__manual02-挤偏放大·直球长台%20·%20球形2-9杆.json) | 9 | 1 | — | — | 15.995 | 1,2,3,4,5,6,7,8,9 | 停点误差超过0.1mm |
| [塞量阶梯 · 球形1](../content/position_play/sequences/drill_c075__manual01-塞量阶梯%20·%20球形1-7杆.json) | 7 | 1 | — | — | 22.492 | 1,2,3,4,5,7 | 停点误差超过0.1mm |
| [塞量阶梯 · 球形3](../content/position_play/sequences/drill_c075__manual03-塞量阶梯%20·%20球形3-5杆.json) | 5 | 1 | — | — | 28.717 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [小角度带塞进袋 · 球形1](../content/position_play/sequences/drill_c076__manual01-小角度带塞进袋%20·%20球形1-14杆.json) | 14 | 1 | — | — | 39.910 | 1,2,3,4,5,6,7,8,9,10,11,12,13,14 | 停点误差超过0.1mm |
| [小角度带塞进袋 · 球形2](../content/position_play/sequences/drill_c076__manual02-小角度带塞进袋%20·%20球形2-14杆.json) | 14 | 1 | — | — | 88.906 | 1,2,3,4,5,6,7,8,9,10,11,12,13,14 | 停点误差超过0.1mm |
| [中大角度带塞进袋 · 球形1](../content/position_play/sequences/drill_c077__manual01-中大角度带塞进袋%20·%20球形1-5杆.json) | 5 | 1 | — | — | 48.707 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [远台带塞准度 · 球形1](../content/position_play/sequences/drill_c078__manual01-远台带塞准度%20·%20球形1-16杆.json) | 16 | 1 | — | — | 100.184 | 1,2,3,4,5,6,7,9,11,13,15 | 停点误差超过0.1mm |
| [上下半台走位 · 球形1](../content/position_play/sequences/drill_c080__manual01-上下半台走位%20·%20球形1-4杆.json) | 4 | 1 | — | — | 19.664 | 1,2,3,4 | 停点误差超过0.1mm |
| [横向蛇彩围 8 · 球形1](../content/position_play/sequences/drill_c082__manual01-横向蛇彩围%208%20·%20球形1-12杆.json) | 12 | 1 | — | — | 360.550 | 1,2,3,4,5,6,7,8,9,10,11,12 | 停点误差超过0.1mm |
| [吃库分离角 · 球形1](../content/position_play/sequences/drill_c083__manual01-吃库分离角%20·%20球形1-8杆.json) | 8 | 1 | — | — | 96.344 | 1,2,3,4,5,6,7,8 | 停点误差超过0.1mm |
| [不吃库分离角 · 球形1](../content/position_play/sequences/drill_c084__manual01-不吃库分离角%20·%20球形1-8杆.json) | 8 | 1 | — | — | 30.374 | 1,2,3,4,5,6,7,8 | 停点误差超过0.1mm |

## D 其余停点或单杆不符

| 动作／球形 | 杆数 | 首次不符 | 中断杆 | 进球异常杆 | 最大停点差 mm | 独立单杆不符 | 原因／备注 |
|---|---:|---:|---:|---|---:|---|---|
| [高杆跟进走位 · 球形2](../content/position_play/sequences/drill_c003__manual02-高杆跟进走位%20·%20球形2-5杆.json) | 5 | 1 | — | — | 6.555 | 1 | 停点误差超过0.1mm |
| [中杆定杆基础 · 球形1](../content/position_play/sequences/drill_c010__manual01-中杆定杆基础%20·%20球形1-7杆.json) | 7 | 1 | — | — | 6.014 | 1,2,3,4,5,6,7 | 停点误差超过0.1mm |
| [底袋小角度入袋 · 球形2](../content/position_play/sequences/drill_c013__manual02-底袋小角度入袋%20·%20球形2-9杆.json) | 9 | 1 | — | — | 9.782 | 1,2,3,4,5,6,7,8,9 | 停点误差超过0.1mm |
| [中杆定杆基础 · 球形1](../content/position_play/sequences/drill_c014__manual01-中杆定杆基础%20·%20球形1-7杆.json) | 7 | 1 | — | — | 6.387 | 1,2,3,4,5,6,7 | 停点误差超过0.1mm |
| [斯登角度停球 · 球形1](../content/position_play/sequences/drill_c016__manual01-斯登角度停球%20·%20球形1-6杆.json) | 6 | 1 | — | — | 6.550 | 1,2,3,4,5,6 | 停点误差超过0.1mm |
| [厚球分离角控制 · 球形1](../content/position_play/sequences/drill_c026__manual01-厚球分离角控制%20·%20球形1-5杆.json) | 5 | 1 | — | — | 9.411 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [高杆缩小分离角 · 球形1](../content/position_play/sequences/drill_c027__manual01-高杆缩小分离角%20·%20球形1-4杆.json) | 4 | 1 | — | — | 5.504 | 1,2,3,4 | 停点误差超过0.1mm |
| [低杆扩大分离角 · 球形1](../content/position_play/sequences/drill_c028__manual01-低杆扩大分离角%20·%20球形1-4杆.json) | 4 | 1 | — | — | 8.756 | 1,2,3,4 | 停点误差超过0.1mm |
| [定杆分离角精确控制 · 球形1](../content/position_play/sequences/drill_c029__manual01-定杆分离角精确控制%20·%20球形1-6杆.json) | 6 | 1 | — | — | 9.879 | 1,2,3,4,5,6 | 停点误差超过0.1mm |
| [分离角走位应用 · 球形1](../content/position_play/sequences/drill_c030__manual01-分离角走位应用%20·%20球形1-5杆.json) | 5 | 1 | — | — | 8.079 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [入位球基础 · 球形1](../content/position_play/sequences/drill_c037__manual01-入位球基础%20·%20球形1-3杆.json) | 3 | 1 | — | — | 7.406 | 1,2,3 | 停点误差超过0.1mm |
| [轻推定位 · 球形1](../content/position_play/sequences/drill_c044__manual01-轻推定位%20·%20球形1-6杆.json) | 6 | 1 | — | — | 3.541 | 1,2,3,4,5,6 | 停点误差超过0.1mm |
| [控力走位圈](../content/position_play/sequences/drill_c046__Snipaste_2026_06_19_16_49_09-控力走位圈-5杆.json) | 5 | 1 | — | — | 6.399 | 1,2,3,4,5 | 停点误差超过0.1mm |
| [K球不吃库 · 球形1](../content/position_play/sequences/drill_c056__Snipaste_2026_06_19_17_32_46-K球不吃库%20·%20球形1-1杆.json) | 1 | 1 | — | — | 8.926 | 1 | 停点误差超过0.1mm |
| [K球不吃库 · 球形2](../content/position_play/sequences/drill_c056__Snipaste_2026_06_19_17_35_51-K球不吃库%20·%20球形2-1杆.json) | 1 | 1 | — | — | 0.341 | 1 | 停点误差超过0.1mm |
| [贴库球处理 · 球形1](../content/position_play/sequences/drill_c058__Snipaste_2026_06_19_17_50_08-贴库球处理%20·%20球形1-1杆.json) | 1 | 1 | — | — | 2.150 | 1 | 停点误差超过0.1mm |
| [贴库球处理 · 球形2](../content/position_play/sequences/drill_c058__Snipaste_2026_06_19_17_50_48-贴库球处理%20·%20球形2-1杆.json) | 1 | 1 | — | — | 5.323 | 1 | 停点误差超过0.1mm |
| [高级蛇彩贴库综合 · 球形1](../content/position_play/sequences/drill_c071__manual01-高级蛇彩贴库综合%20·%20球形1-8杆.json) | 8 | 1 | — | — | 8.489 | 1,2,3,4,5,6,7,8 | 停点误差超过0.1mm |
| [挤偏认知·直球近台 · 球形2](../content/position_play/sequences/drill_c073__manual02-挤偏认知·直球近台%20·%20球形2-8杆.json) | 8 | 1 | — | — | 2.854 | 1,2,3,4,5,6,7,8 | 停点误差超过0.1mm |
| [塞量阶梯 · 球形2](../content/position_play/sequences/drill_c075__manual02-塞量阶梯%20·%20球形2-5杆.json) | 5 | 1 | — | — | 6.962 | 1,2,3,4,5 | 停点误差超过0.1mm |

## E 全部符合

| 动作／球形 | 杆数 | 首次不符 | 中断杆 | 进球异常杆 | 最大停点差 mm | 独立单杆不符 | 原因／备注 |
|---|---:|---:|---:|---|---:|---|---|
| [高杆跟进走位 · 球形1](../content/position_play/sequences/drill_c003__manual01-高杆跟进走位%20·%20球形1-4杆.json) | 4 | — | — | — | 0.000 | — | 符合 |
| [握杆稳定性练习 · 球形1](../content/position_play/sequences/drill_c006__manual01-握杆稳定性练习%20·%20球形1-0杆.json) | 0 | — | — | — | 未得终位 | — | 符合 |
| [握杆稳定性练习 · 球形2](../content/position_play/sequences/drill_c006__manual02-握杆稳定性练习%20·%20球形2-0杆.json) | 0 | — | — | — | 未得终位 | — | 符合 |
| [直线出杆检验 · 球形1](../content/position_play/sequences/drill_c009__manual01-直线出杆检验%20·%20球形1-7杆.json) | 7 | — | — | — | 0.000 | — | 符合 |
| [中袋直线入袋 · 球形1](../content/position_play/sequences/drill_c012__manual01-中袋直线入袋%20·%20球形1-8杆.json) | 8 | — | — | — | 0.000 | — | 符合 |
| [直线推白球 · 球形A](../content/position_play/sequences/drill_c022__Snipaste_2026_06_02_00_19_36-远台直线出杆%20·%20球形2-1杆.json) | 1 | — | — | — | 0.000 | — | 符合 |
| [直线推白球 · 球形B](../content/position_play/sequences/drill_c022__Snipaste_2026_06_02_00_22_05-远台直线出杆%20·%20球形4-1杆.json) | 1 | — | — | — | 0.000 | — | 符合 |
| [三档力度控制 · 球形1](../content/position_play/sequences/drill_c045__manual01-三档力度控制%20·%20球形1-3杆.json) | 3 | — | — | — | 0.000 | — | 符合 |
| [五档力度阶梯 · 球形1](../content/position_play/sequences/drill_c049__manual01-五档力度阶梯%20·%20球形1-5杆.json) | 5 | — | — | — | 0.000 | — | 符合 |
| [翻袋入底角袋 · 球形1](../content/position_play/sequences/drill_c054__manual01-翻袋入底角袋%20·%20球形1-5杆.json) | 5 | — | — | — | 0.000 | — | 符合 |
| [翻袋入中袋 · 球形1](../content/position_play/sequences/drill_c055__manual01-翻袋入中袋%20·%20球形1-5杆.json) | 5 | — | — | — | 0.000 | — | 符合 |
| [开球训练（中式台球） · 球形1](../content/position_play/sequences/drill_c066__manual01-开球训练（中式台球）%20·%20球形1-0杆.json) | 0 | — | — | — | 未得终位 | — | 符合 |
| [挤偏认知·直球近台 · 球形1](../content/position_play/sequences/drill_c073__manual01-挤偏认知·直球近台%20·%20球形1-7杆.json) | 7 | — | — | — | 0.000 | — | 符合 |

## 证据与边界

- `audit-run-1.json`／`audit-run-2.json`：完整逐杆求解结果、进袋、停点偏差、作者重摆与未运行段。
- `source-baseline.json`／`runner/manifest.json`：原档和实际引擎源码哈希。
- `engine-run-1.log`／`engine-run-2.log`：真实执行日志。
- [CSV重录清单](../output/sequence-current-engine-audit-20261014/重录核验清单.csv)。
- 不把缺失球的偏差记为零：最大停点差只统计实际与期望均留桌的球；落袋或球集合不符单列。
- 数值核验不代替真实球桌或真机视觉体验；未改序列、未安装真机、未提交发布。
