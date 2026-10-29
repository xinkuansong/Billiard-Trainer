# K球六项反馈修订 · 2026-10-29

状态：六项反馈实现与小屏原生定向复验完成，待用户体验。

|反馈|处理|
|---|---|
|杆速/左右/高低三行不要|删除参考参数信息块，保留右侧可操作杆速尺|
|2库前加要求|显示“要求：一库／两库／三库”，其他训练信息保留|
|中杆中力轨迹缺失|替换保存解法展示，按两球页在首次有效提交前显示中杆2m/s真实基准|
|首答成功率改名|侧栏/总结/历史统一为成功率，统计仍冻结每题首答|
|两个菜单不要|删除查看参考打法与回放本杆入口|
|圈出备注不要|删除“只统计每题首答…”次级段落，主说明与条件注释保留|

根因：首版把参考实现为答题后显式重建已存解法，与用户要求的中杆基准不是同一能力。本轮采用生产三球物理、固定默认输入和自动瞄准；基准不要求完成题目。参数不取存档解法，也不取当前调节输入。首答后隐藏、重试不恢复、换题重新显示；保存失败按真实接受状态处理。

代码：KBallPracticeView/Settings/ViewModel/Record；没有修改KBallBank参数或KBallJudgement。单页差异已回填[页面卡](../table-page-adaptation/K-BALL-20261029.md)。

验证：全仓gate `output/k-ball-feedback-gate-20261029.log` FAIL=0；`git diff --check`通过。冻结快照`1088f7377f86da6160f57ec3e6a513ea973e5cbd2ea468b4aa62edf8de0295d2`，基于私有静止副本，复制前后文件全集/内容/执行位一致，未把共享工作区声明为静止。

远端任务`k-ball-feedback-se-20261029`，iPhoneSE3/iOS26.2，KBallPracticeTests 6项及KBallPracticeUITests 3项。新增实际Scene基准轨迹逐点对比，验证输入调成3m/s和非中杆后，基准仍等于独立2m/s求解且不扣额度；UI核菜单/文案、设置取消、首答/重试/换题、最后免费题及3D。实际6逻辑＋3UI全部通过，0失败/跳过；原始结果及附件在`output/k-ball-feedback-se-20261029/`。

本轮尚未跑iPad、真机、VoiceOver和全App回归；不改变上一轮已验证范围，不发布/推送。模拟器与临时构建资源在回传核验后关闭。


## 原图与收尾

已目视2D未答、精简菜单、3D未答和设置滚动状态：要求/成功率、基准虚线、参数和菜单删除符合反馈，控件槽保持。设置被圈备注删除由源码及AX断言验证，当前设置截图为滚动后状态，不冒称上方说明区已目视。

- [2D新版](../../output/k-ball-feedback-se-20261029/attachments/kBall-2D-before-answer.png)
- [菜单](../../output/k-ball-feedback-se-20261029/attachments/kBall-simplified-menu.png)
- [3D新版](../../output/k-ball-feedback-se-20261029/attachments/kBall-3D-before-answer.png)

远端原生构建与9项执行通过，fetch逐文件核验后complete已关闭任务，临时设备/构建/源码已收尾；本地仅删除本轮私有中转副本，保留冻结快照、原始xcresult与截图、门禁和源码一致性记录。6个本轮产品/测试文件与已测快照一致（`output/k-ball-feedback-source-check-20261029.json`）。文档体积及diff检查通过。没有安装真机或发布。

追加反馈：删除侧栏“入库前K／出库后K”共用Text，要求库次仍显示；上方原图为删除前证据。本次源码/diff检查通过，未另跑构建/模拟器。
