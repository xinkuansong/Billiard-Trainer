# 多球“上一步”完整返回复核

合同：[DR-442 r3 页面卡](../table-page-adaptation/MULTI-BALL-BACK-20261030.md)。首杆前及停稳后均允许返回第一球/袋口；中八合法己方球可重选，追分保持号码规则。上一杆评分与已停稳球位不因改选变化；重打仍恢复真实上一杆。

## 证据归属

r5业务验证为 Mac mini job `multi-ball-back-r5-20261030`、snapshot `966f5805969f61548c5e4c73ac3b7470715fd3077853120a4883f28d48cf53b0`，Xcode 26.2、SE3/iOS 26.2。证据目录 `output/multi-ball-back-20261030/`。四份修改源码哈希已与冻结版本核对；4271文件完整源码归档逐文件核验。原始xcresult不修改，分析使用副本。

## 验证范围

- 30项多球逻辑及1项合并检查点通过：完整返回、原②/③重选为①、当前球再次确认、停稳后改球/袋、旧锁档解除、最后一球、成绩冻结、存档恢复与真实重打。
- 原生UI：2D/3D首杆返回并重选、中八原②改①、实际击球及失败后重打。r5四项均通过。
- 成功停稳后改球/袋由宿主集成逻辑测试覆盖；本轮UI击球流程若进入失败分支，不计为成功进球后的返回验证。
- 首轮r2的35项中34通过、1失败（同一用例2处断言）：保存发生在宿主计算未结束时；测试补充等待计算完成和保存错误断言，原有恢复选择/成绩断言保留，r5已通过。

## 原图与边界

r2七张及r5九张返回/重选/重打原图均已打开核对。r5截图发现原②改①后顶部仍保留②标记，与桌上蓝圈不同；r6把角色值提前在父视图计算后传入按钮标签，新增球库角色断言，三项相关UI复验全部通过。布局、字体、HUD未修改。本轮不覆盖真机、iPad、VoiceOver或完整App回归；未安装手机、未提交/推送、未发布，用户体验待反馈。

最终显示修正：r6 snapshot `c99f87883a9e622139ee9866cf15c14c592abf9ec3556e80869757bcc561e803`，只有FreePlayView的角色值捕获与UI断言两文件改变；控制器及31项逻辑/检查点源码保持r5哈希。

## 最终结果与原图

r5 35 passed／0 failed／0 skipped；r6 3 passed／0 failed／0 skipped。r6七张原图已实际打开核对；新第一球在球库与桌面均显示天蓝①，旧①清除，返回第一球时上一步禁用，改选后进入第二球。未发现新增截断/错位。

|状态|2D|3D|
|---|---|---|
|返回第一袋|[原图](../../output/multi-ball-back-20261030/delivery-screens/opening-back-pocket-false.png)|[原图](../../output/multi-ball-back-20261030/delivery-screens/opening-back-pocket-true.png)|
|返回第一球|[原图](../../output/multi-ball-back-20261030/delivery-screens/opening-back-ball-false.png)|[原图](../../output/multi-ball-back-20261030/delivery-screens/opening-back-ball-true.png)|
|重新选定球袋|[原图](../../output/multi-ball-back-20261030/delivery-screens/opening-reselected-false.png)|[原图](../../output/multi-ball-back-20261030/delivery-screens/opening-reselected-true.png)|

[原②改为①的最终原图](../../output/multi-ball-back-20261030/delivery-screens/planning-chinese-reassign-first.png)。本地gate、文档容量、源码哈希与diff检查通过；r2/r5/r6远端工作目录与临时设备已按协议收尾，原始证据保留。
