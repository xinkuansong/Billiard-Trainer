# UI 审查 — 练习卡片内容类型角标

日期：2026-10-13。DR-387；实现与原生检查完成，用户最终观感待确认，未装真机、未提交发布。

## 范围与分类

36张正式卡片显式分类：阅读11、答题6、击球8、交互11。模拟器专用「批量出片台」额外为交互。

| 类型 | 卡片 |
|---|---|
| 阅读 | 瞄准原理、浅谈球感、母球速度分级、最少加塞原则、反向规划、关键球原理、球团管理、风险报酬决策矩阵、安全球三维度模型、清台5步决策流程、清台速查手册 |
| 答题 | 角度预测、2D角度、3D角度、瞄准点训练、2D瞄准点、3D瞄准点 |
| 击球 | 分离角与走位、自由走位、自由击球、思路训练、打一走二想三、防守、翻袋解球、颗星解球 |
| 交互 | 瞄准方法、瞄准修正、旋转与加塞、角度与瞄准、分离角图谱、加塞吃库图谱、瞄准点对照表、30°法则、90°法则、切线法则、拍照建球形 |

主要行为决定类型，不由侧栏分区推断。理论枚举穷尽switch；新增入口必须指定contentKind。共享其他页面的卡片未修改。

## 原生视觉核对

同一最终Debug包，正常Tab进入练习，中文、默认字号、Debug forcePremium。iOS 26.3，iPhone 17 Pro（402×874pt）与iPhone SE3（375×667pt）。原始截图位于[证据目录](../../output/practice-type-badges-20261013/native/)。

- 标准手机：after-{learn,theory,quiz,play,solve}-{light,dark}.png，共10张，逐图确认实际分组与主题。
- SE：se-{learn,quiz,play}-{light,dark}.png，共6张，逐图确认四种角标、编号及Pro共存。未扩展到iPad/横屏/最大字号。
- before-{learn,quiz,play}-{light,dark}.png为同标准手机改前对照。startup.png只是开机过程，不计证据。HTML预览属于设计稿，不计原生证据。
- 角标24pt高，右/下8pt，图标14pt、文字12pt medium、间距4pt、水平padding7pt、圆角6pt；实际图上无角标文字裁切、错位或与顶部标识相碰。击球复用三球加球杆；其他三类与批准预览一致。
- 底栏覆盖滚动视口内尚未滚出的下方卡片属于现有页面行为；未将首屏截图当作全内容长图。模拟器批量工具副标题的既有省略不在本次变更范围。
- 角标非按钮、允许点击穿透；原生AX标签包含类型且不增加独立点击目标。瞄准原理卡进入内容并返回已执行；首次点击后工具snapshot短暂未稳定，重新snapshot确认进入正文后返回成功。
- 无新增P0/P1/P2视觉问题。仅检查列出的尺寸/主题和可见卡片；完整36卡分类另经源码清单核对。

## 验证与证据

- `make -f scripts/Makefile build SIM_DEVICE=Practice-Badges-Phone-20261013`：BUILD SUCCEEDED。环境没有xcpretty，Makefile自动回退原始构建输出并成功。
- `make -f scripts/Makefile verify-gate`：FAIL=0。
- 分类核对：36正式入口与11/6/8/11计数一致；见[classification.json](../../output/practice-type-badges-20261013/native/classification.json)。
- 原生无障碍及导航取证：[ui-snapshots.json](../../output/practice-type-badges-20261013/native/ui-snapshots.json)。构建及gate日志在同目录。
- 当前仅有局部表现变更，不新增镜像实现的单元测试。文档体积与diff检查结果见同目录日志。
