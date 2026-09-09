# 千条历史诊断恢复审查

2026-09-07；Test Engineer；只读核对 snapshot-003，未运行构建、播种或 UI，未改业务与测试草稿。历史 snapshot-002 结果不代表当前通过。主控独立执行及验收。

## 结论

现有 `ThousandHistoryFixtureTests.swift` 与 `ThousandHistoryUIDiagnosticUITests.swift` 未发现需要预先修改的当前代码失配，可以在主控当前 probe 通过、确认专用空库与身份后继续。运行中的 AX 实际结构、数据持久性和呈现仍待证据；本审查不是测试通过。

## 代码路径核对

- snapshot-003 `SubscriptionManager.swift:93` 的 `allowsPremiumSession` 明确允许从未认证过的 DEBUG 进程通过显式 `-forcePremium` 渲染 Pro；普通游客不凭持久开关自动获得该例外。UI 草稿每次 launch 显式带此参数，且不带虚构登录/fixture。`StatisticsView.swift:43` 的统计门控只查 `isPremium`，不存在额外的必须登录条件。故不要为此测试加入假账号；它也不能证明真实购买或游客正式权益。
- `ModelContainerFactory.swift` 当前仍使用 `QiuJiSchemaV5` 与 `QiuJiMigrationPlan`。seed 从该真源建立默认 disk 配置；宿主必须预先以内存参数启动，避免宿主与 seed 同时持有 disk 容器。UI 随后的普通启动会经过正常 factory 的迁移/normalize，不能把 seed 保存计数当作正常 App 读回计数。
- `HistoryViewModel.swift:356` 历史 drill 行取 entry 的名称快照；当前列表按日期降序。seed 的单项名称“半台直线球”、2 分钟、毫秒排序与测试选行规则相符。`TrainingDetailView.swift:350` 仍显示无空格的 `8/10`；session note 在详情呈现，leading toolbar 仍是 dismiss 按钮。第一 navigation bar button 的真实 AX 命中仍须运行验证，不能凭代码断定无歧义。
- 当前 `StatisticsView` / `StatisticsViewModel` 保留概况 2000 分钟、1000 组、1 天及单分类 `80%`、`8000/10000 球`、`1000 组` 的预期文本。只播 drill、一场一组、同分类同单位，不涉及跨单位合并。默认滚动周包含当日；seed 与 UI 均拒绝本地日期变化。

## 沙盒和证据护栏

当前 Swift 草稿已采用 `THOUSAND-EXECUTION-PREPARATION.md` 最后修订段的方案 B；其早期绝对路径参数说明仅为历史，实际 seed 输入为 `QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH`。

seed 的外部相对路径仅用于比较，数据库目标仍来自真实 `ModelConfiguration.url`。它拒绝绝对路径、空组件、`.`、`..`，解析符号链接后要求 store 与固定 manifest 在实际 home 内，并核对固定 bundle、已有 guest defaults、CurrentOwnerContext 与外部指定 owner 一致。store/wal/shm/manifest 任一存在即失败，不删除重置。保存后要求三类各 1000、全部 session owner 一致、同步队列 0；manifest 不覆盖。

UI runner 的 manifest 参数校验仅证明输入自洽，无法独立证明 App 当前沙盒；主控需保留专用 UDID、probe→seed 实际 manifest→当前容器路径的外部链条。若 UI 安装造成沙盒根变化，保留原 manifest 的历史绝对路径，另记重定位观察；不得篡改真实 manifest 假装没有变化，也不应凭 UUID 改变认定数据丢失。guest、默认相对路径及正常 UI 内容必须持续一致。该流程不读 Keychain；无真实凭据来自新建专用设备流程，不能由 guest 字符串证明。

## 实际覆盖及待运行

1. 主控当前只读 probe 有效通过后，核准相对路径、owner、日期及空库事实，再精确执行 seed 单方法。seed 未生成有效 manifest 时禁止进入 UI。
2. 结束宿主后正常 disk UI 启动，抽取两条带不同 QD-1000 序号的历史详情，滚动后要求后者更旧；再核对统计总量并返回历史。并非遍历 1000 条或验证绝对第 999/0 条。
3. 导出并独立审阅截图与 AX，尤其“1 / 天”等独立值的所属概况卡、关闭按钮、历史滚动位置。失败先区分环境/选择器/产品，保留原断言及失败证据。
4. 不覆盖真实用户逐条创建、混合训练类型、旧版本迁移、云端同步恢复、删除编辑、帧率/峰值内存或重复冷启动性能。一次通过不能宣称全部数据领域或性能 SC 完成。

本次仅新增本审查文档；未操作模拟器、登录或购买，未复制注册 snapshot 测试。续接状态由主控统一回写 README/PROGRESS，避免共享文件冲突。
