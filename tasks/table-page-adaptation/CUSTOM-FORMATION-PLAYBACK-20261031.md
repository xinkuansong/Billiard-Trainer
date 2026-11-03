# 自定义球形：重打下方增加回放

日期：2026-10-31。状态：已实施，标准/紧凑手机定向原生验证通过；用户体验待反馈。DR-405 v1.13。

## 当前合同

用户要求“自定义球形的重打下面加上回放按键”。练习页（个人模板及内置4443/L型、2D/3D）左下恢复标准“重打／回放”双动作，回放使用既有`dailyCompactAction`、`vm.replayLastShot()`及`shot.replay`布局身份；保留菜单已有入口。无上杆记录、播放中及临时俯视时禁用。正常窗口上下排列，极低高窗口沿共享Foundation既有容量回退，不新增字体/按钮尺寸/球桌大小规则。

根因：`FreePlayView.dailyLeftControls`显式排除了自定义练习的第二动作，同时将动作槽缩为一颗按钮；`FreeControlCatalog`也缺少该键。已去除三处排除并登记回放；其余消费者及球形编辑模式保持。当前工作区原有多球等改动保留，不归入本任务。

## 球桌条款局部复核

完整36项沿[已有页面卡](CUSTOM-FORMATION-UNIQUE-20261028.md)。本轮仅影响：

|条款|判定与验证|
|---|---|
|TP07/08/09|继承共享次动作槽、HUD样式及44pt命中；iPhone13/SE3两尺寸2D/3D位置、窗内及44pt断言通过，10张after原图已审|
|TP25/26|继承原回放/重打快照行为；两尺寸2D/3D新增按钮触发、播放禁重入、播放后球位恢复及重打回退均通过，不修改练习存储|
|TP28|按业务补齐`shot.replay`注册，个人已保存布局不重置|
|TP34|按用户最新要求覆盖“回放仅进菜单”的页面决定，菜单入口仍保留|
|TP35/36|源码/基线/结果见`output/formation-playback-button-20261031/`，原生通过和用户认可分别记录|

## 验证记录

- before：iPhone13 / iOS26.3.1，`testPracticeReview4443Screenshots` 1项通过，2D/3D原图已审。原xcresult位于`output/local-test-runs/2b3e9651c02a4c81ba7efec0a056e71c/evidence/`。测试结束后Xcode附加`simctl diagnose`长时间收集，停止该次附加诊断后主测试正常退出0并导出原图；未中断测试断言。
- after：定向UI检查新入口可见、无记录禁用、重打下方/窗内/44pt、两模式真实出杆→回放禁重入→恢复球位→重打恢复。另复验4443页面及上轮L型几何断言。iPhone13 / iOS26.3.1：1单元＋2UI通过；SE3 / iOS26.3.1：同一产品test-without-building，1UI通过（含2D/3D），共4项after测试，零断言失败。结果包分别为`after-phone.xcresult`与`after-small-r2.xcresult`。
- 真机、VoiceOver、iPad旋转及完整App回归未纳入本次定向范围；未提交/发布。

- 小屏首次运行`after-small.xcresult`：SpringBoard以Busy拒绝测试程序启动，零测试开始；经`simctl bootstatus -b`等待完全启动后串行重跑通过，未修改代码或放宽断言。失败证据保留。
- `swiftc -frontend -parse`、定向`git diff --check`及完整`verify-gate`通过（双端FAIL 0 / WARN 0、文案与v47 UI基线通过）。未运行本类全套UI测试。
- 原图审查见[本轮报告](../ui-reviews/UR-20261031-formation-playback.md)。两台核心模拟器通过fleet租借与释放，保留既有保护与数据；最终清单中iPhone13已有其他任务租约，两台均处于Booted，未擅自关机。临时构建已由local-test-lifecycle回收约1.54GB，结果与截图保留。
