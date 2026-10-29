# K球练习 · 原生专项验收（2026-10-29）

状态：实现、编译、门禁及三尺寸专项通过；最终SE参考栏已复验并目视，待用户体验。不是发布或真机验收。

## 交付范围

正式入口“练习 → 打 → K球练习”，继承两球共享2D/3D球桌，固定三球与A袋，调打点/杆速后提交。独立设置、每日额度、首答成绩、重试、参考、会话恢复和历史。默认中杆2m/s；首答前隐藏参考；参考按保存参数在生产引擎重建。成功只看先碰A、A进指定袋、母球随后碰B，忽略母球落袋和B碰后位置；进A与K的时间可交错。

题库11,458题、4,905球形，gzip参数包1,680,050字节；原始研究JSONL保留不改。按需读取最多两片，入场不批量跑物理。1/2/3库指观察库，入库前与出库后同属该库。详细合同和包审计见[任务卡](../K-BALL-APP-20261029.md)，TP01–36见[页面卡](../table-page-adaptation/K-BALL-20261029.md)。

## 原生证据

共享工作区另有写入者，远端使用单独冻结副本；没有把共享工作区声明为静止，也没有把同期其他页面变更纳入测试快照。均为Mac mini、iOS26.2，fetch哈希核验后complete释放任务资源。

|任务|设备|结果|覆盖|
|---|---|---|---|
|k-ball-ui-phone-r1-20261029|iPhone17Pro|9通过，0失败/跳过|包/事件/参考3逻辑＋会话4逻辑＋2UI|
|k-ball-ui-compact-r2-20261029|iPhoneSE3|8通过，0失败/跳过|会话5逻辑＋3UI；增加实际SwiftData与最后免费题|
|k-ball-ui-compact-r3-20261029|iPhoneSE3|3UI通过，0失败/跳过|首次参考排版修订，全部核心UI再跑|
|k-ball-ui-pad-r3-20261029|未执行|排队取消|用r4替代，非失败或通过|
|k-ball-ui-pad-r4-20261029|iPadAir13M3|3UI通过，0失败/跳过|正常练习卡入口、2D及3D横竖屏、3UI|
|k-ball-ui-compact-r5-20261029|iPhoneSE3|1UI通过，0失败/跳过|参考每行独立单行缩放，正常入口与首答/参考定向UI|

共8个不同逻辑测试覆盖：全量包读取/事件成功边界/六类参考重建，筛选排除与库口径、首答与重试分离、默认输入/参考门控/owner重置、独立偏好布局、真实SwiftData存储与跨owner原子回滚/传输/历史坏载荷。模拟扰动分档不代表真人成功率。

三个UI方法：首答保护→设置取消→提交→重试→参考→换题清除；最后免费题不跳过结果、重试不再扣额、显式总结；同题2D/3D切换→运杆播放→结果后后台往返→重试。未覆盖播放中后台、真实登录切换、所有筛选/偏好/布局/测量操作。

快照SHA：phone-r1 `4def49ffb0e534f758fc7d918ecceb4b089386fe3848561a2c2981b10c0c841d`；compact-r2 `2130498b760b391459097478415650da78a03a6317b082fbe42d2620bf1968bf`；compact-r3 `59eaa507dbf79017de670caafe0a7b1dca39033909e0a6384a5beeee7dd983de`；pad-r4 `a5a2cd400c91e7da97d54a84193f1fd99913d89b1f1f4a768185fb2de2d597fd`；compact-r5 `41400e6af1e4753e76551a148ee2652ff2654024138fdf50a892c6a87c51f0e2`。各原始xcresult、截图manifest及回收回执在对应`output/<任务>/`。

## 视觉复核与修正

- phone-r1设置/2D未答/参考/3D未答原图已审：球桌与角色继承正确，参考长段挤占左栏。
- compact-r3最后免费题、3D未答原图已审：操作槽稳定、结果留存；参考改三行后仍因窄栏换行。r5改为逐行单行缩放，统计区域仍可独立滚动，不移动击球和重试槽。
- 初始化结果标题由“上杆结果”修正为“本杆结果”。参考失败提示修为“参考打法暂不可用”，不沿用中心杆替代提示。历史K坏载荷提示移至独立条件，避免被全局fetch错误条件遮住。
- iPad-r4设置、2D未答/参考、3D横屏未答原图已审：正常入口、导航、安全区与固定角色正确；参考窄栏换行同SE，统一由r5单行修正。未单独再跑iPad最终文字修订。r5最终参考原图已审：杆速/左右/高低各占一行，未再折行，左右操作槽稳定；结果统计仍可在独立信息栏滚动查看。

## 工程与边界

本地最终完整测试目标编译 `output/k-ball-ui-build-r6.log`：TEST BUILD SUCCEEDED。历史坏载荷提示修正晚于远端快照，仅源审查与此最终编译覆盖；r5覆盖最终参考栏及参考错误文案源码，未注入参考错误。此前r1/r2封面类型漏注册已修；r4一次构建受共享工作区FreePlay参数修改影响，未改其代码，r5/r6随后成功。

全仓gate通过（`output/k-ball-ui-gate-final.log`，v47 FAIL=0；包审计11,458题/4,905球形通过）；`verify-doc-size`通过（PROGRESS 99KB，Hub近10条）；`git diff --check`通过。没有真机/VoiceOver/分屏/全外观矩阵/服务器同步往返/完整题库三球物理复算或用户验收证据。共享组件的继承项未一律标绿。未提交、推送或发布，也未替换用户本机评审设备现场。


## 交付原图与资源收尾

- [最终小屏参考打法](../../output/k-ball-ui-compact-r5-20261029/attachments/kBall-2D-reference.png)
- [iPad竖屏2D](../../output/k-ball-ui-pad-r4-20261029/attachments/kBall-2D-before-answer.png)
- [iPad横屏3D](../../output/k-ball-ui-pad-r4-20261029/attachments/kBall-3D-before-answer.png)
- [iPad原生设置](../../output/k-ball-ui-pad-r4-20261029/attachments/kBall-settings-testFirstAnswerRetryReferenceAndSettingsCancel.png)

本轮5个执行任务均fetch核验并complete，另一个排队任务取消后关闭；远端临时source/build/无引用快照回收，租约释放，原有人评设备未动。本地保留各轮xcresult/附件/manifest/回执及最终r5快照，清理自己的旧快照、私有中转源码与DerivedData；回执`output/k-ball-ui-local-cleanup-20261029/receipt.json`。最终历史错误提示相对冻结源码差异单独留`output/k-ball-ui-history-error-note-final.patch`，仅本地最终编译覆盖。
