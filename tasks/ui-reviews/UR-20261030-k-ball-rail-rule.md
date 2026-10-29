# K球库次提示与判题 · 2026-10-30

## 问题与决定

用户提供原生图并指出初进题无库次提示、成功裁定没有验证库次。旧源码确实仅检查进A与K到B；截图自身不能证明图示那杆库次错误。用户再次确认第N库入库前与出库后都算N库，侧栏入/出库标签继续隐藏。

## 实现

- 入题提示与常驻侧栏共用requirementText；提示在球桌挂载后启动既有3秒生命周期。
- 正式提交KBallShot使用真实事件和碰B前速度计算观察库次。入库前=已吃主库+1，出库后=已吃主库且上一库同墙；第一A到第一B之间计数，袋角、其他球、区间外事件排除。缺精确事实不判成功。
- 场景、求解器与物理源码/题库指纹未修改。B先被其他球碰过的罕见路径，现有首次碰撞快照无法证明后续母球K时方向，返回“无法确认K球库次”；未声称支持全碰撞历史。
- 新记录judgementVersion=2，旧历史可读且不重算，旧活动档不续练。首答统计不变；重试成功与成功率0%可以同时成立。

## 验证与源身份

Mac mini受管队列，iPhone SE3 / iOS26.2，冻结快照`bc2dd017d7ffbdff805e22ae1900d1659dc749e2312abca5f32153146a4a5d0f`。任务`k-ball-rail-rule-se-r2-20261030`，已完成：16项通过、0失败、0跳过。

选定6项KBallBankTests（包括真实六类保存打法重建、六库面入/出方向、事件边界及缺事实），7项KBallPracticeTests（包括真正KBallShot正确/错误库次与旧档往返），3项KBallPracticeUITests（入题提示、2D/3D、首答/重试、菜单/设置、最后免费题）。上述13项逻辑＋3项UI全部通过；日志及xcresult回传哈希验证完成。入题截图和2D/3D原图已目视，要求文本完整，入/出库标签保持隐藏。提示按3秒消失后侧栏要求仍可见；保留共享透明提示样式，本轮没有调整其与球位的避让策略。

本机Swift语法解析、全仓verify-gate、verify-doc-size、git diff --check通过。route签名只更新已审查的KBallPracticeView行。r1曾尝试扩充只读碰撞记录，构建前受题库物理指纹保护拦截；已恢复原文件字节，复用原生首次碰撞事实，无指纹豁免或题库重新发布。r1失败证据回传并关闭，保留于output/k-ball-rail-rule-se-r1-20261030。

## 未验

本轮未测真机、iPad、VoiceOver、全部11,458题物理回放与所有极端碰撞。此前三尺寸首版证据不替代本轮；待用户体验，不自动发布/推送。

## 最终证据与收尾

- [入题原图](../../output/k-ball-rail-rule-review-20261030/kBall-entry-required-rail.png)、[2D准备态](../../output/k-ball-rail-rule-review-20261030/kBall-2D-before-answer.png)、[3D准备态](../../output/k-ball-rail-rule-review-20261030/kBall-3D-before-answer.png)；用户before保留在同目录user-before.png。
- `output/k-ball-rail-rule-se-r2-20261030/evidence/test-summary.json`：passedTests=16, failedTests=0, skippedTests=0；6项库测试含六类真实物理重建，非整库重算。
- `fetch-verification.json`及`cleanup-receipt.json`：两轮远端任务已回传并关闭；临时设备/构建已由受管流程收尾，本地保留最终冻结快照及原始证据。
- K模块、两份逻辑测试及UI测试与实际被测快照逐字节一致；TrajectoryRecorder与题库记录指纹一致。未改全局物理或发布题库。
- 当前可交付用户复验；未安装到用户真机、未提交/推送。
