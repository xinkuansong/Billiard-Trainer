# 多球走位第二轮：入口、单选与权益验证

状态：实施及定向验证完成；真机/实际购买边界仍未验。用户本轮授权，具体产品合同见[页面卡](../table-page-adaptation/MULTI-BALL-PRACTICE-20261026.md)。不涉及提交、发布或真实购买。

## 变更与检查范围

- 2D/3D正式入口、标题、固定视图、独立训练设置及显示/布局键；3D临时俯视保留。
- 顺序/中八球数与对手选项直接单选；灰色重打说明移除；2D新增3题/自由训练。
- 非Pro每日3题跨多球玩法共用，成功换入新局才计次；Pro自由训练/3D无限换局，Pro三题轮仍3题。
- 会员入口、直达门控、控制器权限、第三题边界、跨日/重进、同题重开、恢复默认、取消、布局和摆球回归。
- 首轮球库、生产物理、随机删球结果保持；未重跑50,000副生成。

## 构建与规则

受管工作区：`output/local-test-runs/207e367fbd0a4b93843ae675a7da9b3a/`。
首次build.log失败为FreePlayView表达式类型检查超时；拆分原视图修饰链为tablePageBody/pageBody，build-r2.log通过。未削减功能或放宽编译选项。

phone-r1中的11项MultiBallPracticeTests＋11项AngleUsageLimiterTests通过：原20题训练保持、3题共享/持久/跨日、Pro与固定轮次、旧设置兼容、页面身份与布局模式、原球形与裁决。

## 原生轮次与失败保留

- `output/multi-ball-access-r2/phone-r1/`：初次真实UI；ProAccessGate把入口List的AX标识覆盖成pro.authorized，旧测试依赖multiBall.settingsForm在中八向下滚动时找不到。实际可见球数点选已生效；修测试为当前原生CollectionView滚动定位。原始日志和xcresult保留。
- phone-r1共28项执行，22规则＋3UI通过，3UI失败：除List标识外，入口设置取消用例在4球行仅部分露出时点击未选中，改为整行进入可见区域并等待选择值；非Pro用例漏加现有坐标探针参数，导致把普通AX文本当JSON，已补参数。未删断言，原失败包保留。
- build-r3通过；补弱引用SubscriptionManager，避免控制器持有视图状态形成环。phone-r2按最终构建重新完整执行。
- phone-r2：22规则与4UI通过；中八和正常入口的训练设置复查仍失败，实际是测试把位于下方的4球行当作上方行，向下拖触发了系统sheet关闭。改为从当前表单上方向下查找选项所需的向上滑动，保留整行可见与已选值断言。
- phone-r2非Pro额度真实UI已通过：余1进入中八→重开不扣→换局拦截→设置改顺序仍拦截→退出重进仍0；自由训练购买页和3D直达锁定通过。原图41-quota-exhausted已核，当前球形可继续。
- build-r4仅更新测试定位并补显示偏好跨页持久化断言；产品二进制继续build-r3。phone-r3包含多球、既有20题限制、蛇彩规则与合法出杆回放回归。
- phone-r3：49规则＋5UI通过，中八与入口的滚动定位仍失败；Snake真实合法出杆/回放不重复记杆通过。导出的录屏80s/84s表明旧长拖越过4球行，已保留。
- phone-r4：正常入口/9球/重开/设置取消/换局通过；中八定位仍失败。进一步检查录屏93s，确认短拖起点位于原生“玩法”分段控件，实际切到了顺序清台；这不是球数消失。build-r6测试将拖动起点放到可见行左侧列表空隙，避开分段控件，保留选择值及球数断言。仅修改测试，无产品手势补丁。
- phone-r5中八用例通过；phone-r3/r4/r5在同一产品二进制SHA下合并最新结果，49单元＋7UI共56个不同用例全部通过（不把失败重跑次数累加为覆盖数）。
- floor-r1：iPhone SE3／iOS17，2项中八/免费额度UI通过；单选可滚动、15球顶栏与“2D多球走位”标题原图已核。正常退出、源文件不变、设备Shutdown。
- pad-r1：iPad mini6／iOS26，两项正常入口、固定2D、横竖屏、缩窗菜单/重开、全屏回程、固定3D临时俯视/摆球/布局取消通过。05/07/30原图已核，标题/球库/控件可见；设备Shutdown、源码不变。

## 独立边界

模拟器调试权益只验证门控；未进行真实Apple购买、退款或跨账号权益回传。真机、VoiceOver、大字体、温升和用户体验反馈未验；首轮未改变的真实物理/球库证据按页面卡引用，不以本轮UI代替全App回归。

## 检查命令与已知全仓限制

`git diff --check`、`make -f scripts/Makefile verify-doc-size`通过。`verify-gate`内容、同步与术语检查通过，仍在原有route-coverage.csv第87行未声明ControlLayoutLibrary处失败；未将其标记为本轮通过。仅刷新本轮MainTabView、AngleHomeView、FreePlayView、MultiBallPracticeView路由签名，四项与当前源一致；其余已有漂移不重签。

已核当前产品原图：phone-r3/30-light-settings（3D单选），phone-r4/01-rotation-settings（2D三题/自由训练及球数），phone-r5/10-chinese-settings与14-chinese-no-opponents（中八选项与实际4球），phone-r2/41-quota-exhausted（额度及保留当前局），floor-r1/11-chinese-2d（小屏15球）。本轮均为模拟器证据。


## 最终证据与资源

汇总：`output/multi-ball-access-r2/summary.json`。56个不同用例的最新结果全部通过：49单元（11多球、11既有额度、27蛇彩），7UI（6多球、1蛇彩合法出杆回放）。iOS17小屏与iPad额外各2项，不重复计入56。phone-r3/r4/r5/floor-r1/pad-r1产品SHA均为`52195134f41708e8367aa82e337b0a870681bf0f72eaefbd1b5899101172550c`；测试Runner修订分别保存在各run.json中，不伪装成单轮56全过。最终源文件与最后一轮指纹一致。

正文补充：为通过100KB进度门禁，将9月16日两条已交付视频进度原文移入现有tasks/archive/PROGRESS-当前状态-归档.md，原归档链接继续可达；未删历史记录或抬高阈值。

资源收尾已核实：受管工作区207e367fbd0a4b93843ae675a7da9b3a状态reclaimed，work目录不存在，实际可用空间增加1,677,721,600字节。三台设备均已Shutdown并释放本轮租约，日志、结果包与截图保留；未操作用户其他运行设备。
