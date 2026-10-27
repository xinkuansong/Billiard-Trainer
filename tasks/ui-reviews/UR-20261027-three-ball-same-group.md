# 三球同组抽球修复 · FL-213

2026-10-27：已修复并完成定向验证，未提交/发布，未替换正在运行的用户评审手机。

根因：消费端把同组（全色/花色）误实现为同颜色的全花配对n/n+8，文档及测试也沿用了误解。现改为随机选择组，再在组内无放回取两个不同号码；第三固定黑八。只改ThreeBallBallIdentity及外观政策指纹，不改几何题库/物理/评分/布局。

新字段secondInGroup随题目持久化；缺字段保留旧历史真实号码。外观政策v2沿现有指纹检查结束旧活跃段，提示重新开始，历史成绩保留。

## 验证

- 10项逻辑全部通过：全量111025个消费端题目均同组/不同号/黑八；84种合法有序球号组合逐一编码、解码和阶段推进；1000次随机抽取校验且覆盖两组；旧配对历史解码；原首答/计分/重试/归属回归。
- SE3/iOS26.3上2D、3D两项完整原生流程全部通过：选袋、同袋、提交、自动换杆、退出恢复、重打、回放及两杆结果。球号断言已改为同组不同号，继续核对固定三槽和黑八。
- 导出22张原生截图；重点目视核对初始2D全色4/1/8和3D花色13/14/8，球库和台面一致。旧phone图5/13/8仅作错误身份的before证据，不作为同设备外观对拍。
- 全仓verify-gate、文档体积和git diff --check通过。未做真机/VoiceOver/大字号或全App回归。

证据：`output/local-test-runs/a34d97cd58354264866e4e906832cc25/evidence/tests.xcresult`及test-results.log；`output/three-ball-same-group-20261027/`保存修改前源、最终指纹、门禁、图片清单和收尾证据。

[2D全色原图](../../output/three-ball-same-group-20261027/images/threeBall-await-pocket-false.png) · [3D花色原图](../../output/three-ball-same-group-20261027/images/threeBall-await-pocket-true.png)
