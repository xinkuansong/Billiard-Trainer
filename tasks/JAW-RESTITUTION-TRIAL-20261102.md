# 角袋圆弧恢复系数：0.75正式默认值（2026-11-02）

状态：✅ 用户已明确要求“修改到生产环境吧，并记录”，0.75确认为正式源码默认值，Debug／Release共用。此前0.75 Debug版构建、签名验证、iPhone无线安装与启动成功。⚠️ 正常发布构建的题库重验门禁尚未通过；正式采用不等于发布验收或已上线。

## 用户要求与改动

用户查看乔氏角袋实物参考后，要求把圆弧段恢复系数调大体验。将 `TablePhysics.pocketNoseRestitution` 从 0.70 调到 0.75，仅影响四个角袋的八段鼻尖圆弧。普通库边、jaw 直面仍为 0.94；喉壁为 0.45；圆弧几何、捕获边界与求解筛选本轮不改。

这是单变量对照试用，尚未证明原截图进球由该系数导致。7月历史标定显示0.75可能收紧正常沿库球进袋窗口；现版本的捕获边界已不同，不能把旧速度阈值当作新版本验证结果。

## 验证与交付

- Swift语法解析通过；静态检查确认系数取值与角袋圆弧接线，见 `output/jaw-restitution-trial-20261102/source-check.json`。此检查不是动态物理测试。
- 普通真机构建被题库源码哈希门禁拒绝：首个报错为 `AnalyticShotRollout.swift` 已变化。原始失败保留于 `device-build.log`。本轮系数变更也需要后续题库重新验证，不能只更新哈希放行。
- 为用户体验候选，使用项目已有的 Debug `TRAINING_BANK_REVALIDATION=YES` 实验构建入口。未修改门禁、题库manifest或旧测试断言；该产物不构成普通门禁／发布通过。
- 当前未运行XCTest、原截图精确重放或全题库验证。原 `test_R_railFrozenCornerEntry` 的0.70标定断言保留，尚未作为0.75的有效性证据。
- `device-trial-build.log` 实际输出 `BUILD SUCCEEDED`；`codesign --verify --deep --strict` 退出0。`install.json` 与 `launch.json` 均为 `outcome=success`，目标为用户 iPhone 16 Pro，bundleID为 `com.xinkuan.qiuji`。
- 构建期间已记录的物理源码无漂移，见 `source-drift.json`；产物身份与可执行文件SHA256见 `artifact.json`。本版包含共享工作区的其他会话改动（包括翻袋质量返工），不是与手机旧版严格隔离的单变量A/B；本任务仅改角袋圆弧系数及说明。
- 日志目录：`output/jaw-restitution-trial-20261102/`。

## 正式采用决定与下一步

2026-11-02用户明确采用0.75，撤销“待决定是否保留”的试用状态。正式值直接保留在 `BTPhysicsConstants.swift`，没有Debug专属开关或Release回退到0.70的分支。代码说明同步标注正式默认值；历史0.70速度窗口不再作为当前物理行为承诺。

本轮正式化只调整源码说明与记录，运行时数值与已安装0.75版一致；未再次安装、未提交App Store/TestFlight。正常构建仍需当前物理源码下的题库复验；不得手改manifest哈希假装通过。旧DIAG-R沿库窗口须先实测再判断断言合同，本轮未删改旧断言、未声称动态回归通过。


2026-11-03构建合同更新：按用户“题库是供玩家打的”及修复授权，ADR-P18-12将历史物理资格与摆位完整性分开；普通构建已恢复，旧重验仍未完成也未冒充完成。上文“正常构建必须全库重验”的历史要求由新合同替代。见[修复记录](TRAINING-BANK-BUILD-GATE-20261103.md)。
