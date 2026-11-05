# 防守练习设置与目标路线反馈验收

来源与逐项合同：[接续任务卡](../table-page-adaptation/DEFENSE-FEEDBACK-20261104.md)。原会话 `01a1a504-b53b-74d0-9503-a1e05212791b` 已批准Q01–Q10；本次接续实施。范围为防守练习，目标／实际线样式与重打清线仅轨迹模式。

## 实现

球形改原生常展开单选；防守方式常展开多选，综合互斥，至少一个选项；旧单选迁移，杆法及距离筛选彻底移除。移除多余设置说明、球桌常驻灰线文字、侧栏详情及菜单中的重复动作；保留定时ⓘ题目／结果提示。轨迹目标统一共享橙黄色虚线、无终点环；实际母球白线、目标球球号色，结果栏显示对应图例。示范位于重打上方，仅有参考的结果态出现；回放仍在侧栏。重打、切视图及恢复存档不复现轨迹模式的旧实际线。

首答、评分、物理、题库参数、共享球桌默认与自由模式原路线行为保持。额外修复集成时暴露的题库DTO兼容：现有19个`pocket_N`事件归一为0–5整数，坏值拒绝；题库文件／哈希不改。交接DTO同步。

## 固定快照验证

App实现自r5保持一致；r7快照`928fc589f82ba38487c2849684dd8bd7be912952df51533db11d2ea863c884f8`已完成15逻辑及四项UI。r8仅收敛测试查询，快照`272b3196618c0f9aa33c570f9ced6d54f96edcab6f49cb71ccf4481f754d40e7`；均基于commit `2e2fb385` 的未提交工作区。

| 覆盖 | 状态 |
|---|---|
| Foundation全库解码与往返 | 4340题／10467参考／19入袋事件通过，两种编号格式及非法编号拒绝通过 |
| SE3／iOS17逻辑 | 15项零失败，含迁移、多选筛题、隐藏条件移除、首答、重打切视图与重进、题库兼容 |
| SE3／iOS17原生UI | r7四项通过；r8按自由→筛选原顺序补跑两项均通过，失败用例已闭环（分轮证据） |
| iPad mini／iOS26.2原生UI | r8两项通过，2D／3D横竖、结果栏、示范停止／播完、设置多选及取消 |
| iPhone17 Pro／iOS26.2原生UI | r8两项通过，2D／3D横屏、结果栏、示范停止／播完、设置多选／取消 |

所有通过项需实际命中选择器、无失败／跳过；测试计数和截图只对对应冻结快照有效。真机、VoiceOver、全App回归和用户体验未验。

## 返工与证据边界

r1及r3-phone为旧题库升级测试写入只读指纹而编译失败；改为构造旧指纹Prepared，原断言保留。r4构建通过但全量题库的字符串袋口编号使轨迹模式读取失败；自由模式两项UI通过，整轮仍记录失败。上述失败原件保留；r2-pad、r3-pad、r4-pad、r4-phone均执行前取消，不计测试。r4仅验证设置外观及自由模式，不作为最终轨迹验收。

证据根目录：`output/defense-feedback-20261104/`。每轮原始xcresult／日志由队列回传并核验SHA；截图从临时xcresult副本导出，不触碰收据绑定原件。`before/`保留修改前文件，`sources-r1/r3/r4/`保留相关失败版本，`dto-check/`保留全库Swift解码程序与结果。

SE最终App版本的24张原图已逐张联系表复核，2D／3D结果及重打清线另看原图，示范位置与颜色无裁切问题。iPad r8最终19张原图已逐张联系表复核，另打开2D／3D竖屏结果原图，横竖结果、图例和示范均无裁切；SE r8补验9张原图亦已复核。全部早期失败／取消作业已关闭，诊断设备仅按本任务精确UDID回收；r8三个作业全部回传、核验并完成资源释放。

补充溯源：r5／r7筛选UI中的进程退出，触发栈为XCTAutomationSupport日志回调及系统高日志量隔离分支，不能归为业务恢复默认崩溃。r8使用控件类型查询、到达滚动目标即退出、轻量诊断；保留操作／断言、日志和运行时检查。r7结果态切视图的测试已按真实支持流程改为重打后切换，完整轨迹UI通过。详任务卡及两份ips。

## 原图对照

- 用户修改前：[训练设置](../../output/defense-feedback-20261104/before/user-settings-before.png)、[球桌](../../output/defense-feedback-20261104/before/user-table-before.png)。
- 常展开多选：[iPad设置](../../output/defense-feedback-20261104/screens-r8-pad/49DF44B9-30BF-4AC9-AF58-7B9D6CA210EB.png)。
- SE结果与清线：[2D结果](../../output/defense-feedback-20261104/screens-r7-se/AECFED6A-8481-4604-8096-8B9D29F44B9A.png)、[3D结果](../../output/defense-feedback-20261104/screens-r7-se/DC4D17A0-A67B-49E4-9737-2A84769E8316.png)、[重打清线](../../output/defense-feedback-20261104/screens-r7-se/10EAC326-7F70-49EC-9BC7-B9B3FF0C6C6D.png)。
- iPad结果：[2D竖屏](../../output/defense-feedback-20261104/screens-r8-pad/0EBBD87D-66C3-4622-82A6-8A6AAA6494F1.png)、[3D竖屏](../../output/defense-feedback-20261104/screens-r8-pad/CE073EE8-7EE3-4672-926E-A1B35F6A2971.png)、[2D横屏](../../output/defense-feedback-20261104/screens-r8-pad/CC41DAB4-DEF3-463A-9E92-29B02863BD87.png)、[3D横屏](../../output/defense-feedback-20261104/screens-r8-pad/15C2AEF2-0823-473E-80B0-07E9C7F6AF92.png)。

- 标准iPhone：[2D结果](../../output/defense-feedback-20261104/screens-r8-phone/A677233C-D8AC-4921-B563-8E2BBCCC6DE0.png)、[3D结果](../../output/defense-feedback-20261104/screens-r8-phone/2096A23A-C4D1-4ABA-AB22-2E49526219D8.png)、[方式多选](../../output/defense-feedback-20261104/screens-r8-phone/2987655F-122A-4639-8582-54988A2A6D49.png)。

## 收尾

标准iPhone最终15张原图逐张联系表核对，2D／3D结果另开原图确认；与SE r7的24张、SE r8的9张、iPad r8的19张合计67张最终实现原图完成复核。所有r8作业均2项通过、零失败／零跳过，回传SHA验证通过，临时构建与设备按队列生命周期回收。r7整轮仍为19通过／1失败，失败用例由r8分轮补验闭环，不冒充同轮全过。

最终工作区4320个快照文件与r8一致，11个任务源文件逐一SHA匹配；证据为`workspace-snapshot-audit.json`与`current-source-manifest.json`。`sources-r8/`及各轮manifest保留，可重复核对；仅移除本任务可重建的完整临时快照副本，原始测试证据、截图、失败日志和ips保留。任务实现及定向验收完成，待用户体验复验；真机、VoiceOver、全App回归未执行。
