# 解球参考路线与K球提示 · 2026-11-01

实施与定向验证完成，待真机体验。仅修改解球参考/重打路线；K球生产提示已是短文案，本轮补回归确认。

## 功能证据

本机iPhone SE3／iOS17.0，本轮10:06修订版实际构建。最终`final.xcresult`为5 passed / 0 failed / 0 skipped：2项宿主逻辑＋3项原生UI。首次`tests.xcresult`同样5项通过；随后补保存过大被拒时恢复基准的分支与断言，最终完整复验，不能累计报成10项独立用例。

- 生产物理逐点对照：完整母球轨迹、中杆/默认2m/s、初始及最新用户杆向一致；打点/速度不改基准。
- 真实提交、直击拦截、首答冻结、重打实际母球线、无目标球重置连线；未接受的超大记录恢复默认参考。
- 原生2D调向／设置取消／重打／下一题；3D实际动画／后台恢复／重打／测量；K球入题整条提示无“末库可选”，可选末块及关闭库色保留。

原始结果：[最终测试包](../../output/local-test-runs/9f5f2056f34345cb8feee06bfc032da9/evidence/final.xcresult)、[摘要](../../output/kick-reference-20261101/final-summary.json)、[源码身份](../../output/kick-reference-20261101/final-source-hashes.json)。日志与初轮结果同目录保留。

## 原生视觉审查

六张最终原图逐张打开：2D初始灰参考、2D白色上一杆、下一题重新灰参考、3D灰参考／白色重打、K球入题短文案及完整四边虚线。无本轮新增布局／字号／控件尺寸变更，白瞄准线与灰参考沿现有配色。3D沿原杆向视角，未强制全桌。

![解球默认中杆中力](/Users/song/projects/13.billiard_trainer/output/kick-reference-20261101/final-images/kick-neutral-baseline-2D.png)

![重打显示上一杆路线](/Users/song/projects/13.billiard_trainer/output/kick-reference-20261101/final-images/kick-previous-route-retry-2D.png)

![K球简短提示及虚线框](/Users/song/projects/13.billiard_trainer/output/kick-reference-20261101/final-images/kBall-entry-required-rail.png)

## 边界与收尾

真机、iPad本轮新增行为、全App回归、VoiceOver及性能未验；无提交／发布。既有iPad布局证据不充作本轮行为验收。唯一下一步为用户体验反馈。

最终XCTest退出0并报告TEST SUCCEEDED。外层脚本重复shutdown已处于Shutdown的设备，得到405错误／进程149；它发生在测试完成之后，原日志保留。已独立读取实时状态确认SE为Shutdown，租约已退出；不是App测试失败。临时构建通过受管complete回收，实际结果见`output/kick-reference-20261101/cleanup.log`。


测试后共享工作区变化（10:11）：另一项判罚修改更新KickQuestionPreparer、KickPracticeRecord（judgementVersion=4）及KickPracticeTests的规则用例。本轮ViewModel、UI测试与K球提示源码哈希仍匹配受测版，本轮新增断言也保留。5项通过与截图只证明10:06修订／10:09完成测试的版本，未对10:11之后合并的判罚版本重新构建；不得当成完整当前工作区验收。对方修改原样保留，当前身份补记`output/kick-reference-20261101/post-test-workspace.json`。
