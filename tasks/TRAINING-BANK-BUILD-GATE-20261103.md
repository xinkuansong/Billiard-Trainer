# 普通构建题库门禁修复（2026-11-03）

状态：✅ 本轮门禁回归与无实验开关的 iOS Debug 编译通过；未安装、未签名发布，未运行 App 交互或新的物理全库重放。

## 根因与决定

题库已采用无存解摆位库，构建脚本仍要求全部物理源码等于历史验证指纹。翻袋碰撞统计、角袋恢复系数0.75及近库瞄准补偿改动使普通构建失败。用户先前明确题库供玩家练习无需处理旧参考杆，本轮授权修复构建。采用 ADR-P18-12。

## 变更

- `verify_grid_bank.py` 默认保留资源SHA、schema、数量、组合结构、无存解及几何兼容性检查。4个几何/布局源保持旧指纹；混合常量文件逐项检查19个原几何表达式，不绑定恢复系数。
- 历史物理源码变化输出note，不能解释为题库不可打或当前物理已经复验。新增 `--require-current-physics` 显式严格检查，当前仍预期失败。
- `project.yml` 和 `project.pbxproj` 均无条件运行完整性检查，移除Debug实验开关的跳过分支。未重生成整个工程，保留其他会话工程改动。
- 题库JSON及manifest均未修改；运行时Swift物理与UI均未修改。

## 真实验证

- `python3 -m unittest discover -s scripts/training-question-bank -p test_verify_grid_bank.py -v`：8项通过。实际资源的临时副本测试：损坏、球径/台面/袋口尺寸变化、几何源漂移、缺绑定均拒绝；纯恢复系数变化允许摆位检查；严格历史检查仍拒绝过期证据。另核工程真源和实际pbxproj脚本一致。
- 普通校验通过：782528摆位、178个非空组合。严格历史检查退出1，列出AnalyticShotRollout、BTPhysicsConstants、ShotPredictor三处过期；该失败为预期负例，不伪造重验。
- 完整编译：`xcodebuild -project QiuJi.xcodeproj -scheme QiuJi -configuration Debug -destination generic/platform=iOS -derivedDataPath <受管目录> CODE_SIGNING_ALLOWED=NO build`，退出0，`BUILD SUCCEEDED`。未传`TRAINING_BANK_REVALIDATION`。这是iPhone目标无签名编译，非真机安装、Release归档或全App验收。
- 受管任务 `c49a1f9e496b486e8e0249051bf84ca1` 已自动回收本轮构建目录；日志保留于 `output/local-test-runs/c49a1f9e496b486e8e0249051bf84ca1/evidence/command.log`。
- 8项测试与正/负门禁日志：`output/training-bank-build-gate-20261103/`。

## 后续边界

几何源码/尺寸变化继续阻断并要求检查布局兼容性。历史中袋参考杆结果不再是普通构建前提；若需要宣称新物理资格，另行真实重放并保存证据。未验证每个摆位在所有玩家打点/力度下可进球。
