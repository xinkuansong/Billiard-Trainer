# v47 W0 测试写盘盘点

机器清单见 `write-surface-files.txt`，由 `verify_v47_ui_baseline.py` 对 `QiuJiTests/` 与 `QiuJiUITests/` 中的 `.write(`、`FileManager.default.createDirectory`、`pngRepresentation` 扫描生成并做差集门禁。当前共登记 131 个文件；新增写盘测试未登记时 `verify-gate` 失败。

## 分类与处置

| 类型 | 默认执行集 | 允许目录 | 清理 / 污染要求 |
|---|---|---|---|
| 普通单元测试临时文件 | `QiuJi` scheme 的 `QiuJiTests` | `FileManager.default.temporaryDirectory`、测试专属临时目录 | 测试自行删除或由系统回收；不得写仓库真源 |
| 诊断 / evidence renderer | 多数在 `QiuJiTests` 默认执行集 | `build/<task>-*` | 允许覆盖同任务 build 产物；不得写 `QiuJi/Resources` 或 docs 基线 |
| bake / export runner | scheme 内但应由内部 gate 或 `-only-testing` 控制 | 明确的 `build/`；显式发布命令才可写 `QiuJi/Resources` / `content` | 默认全量测试必须证明 runner gate 未开启时不写真源 |
| UI 截图 | `QiuJiUITests`；普通 `QiuJi` scheme 会包含 | `build/<task>-screenshots`、`tmp/` | PNG 写入失败必须让测试失败；不得默认写 `docs/ui-polish` |
| 旧 worktree 绝对路径 | 仍存在于历史测试 | 对应旧 worktree `build/` | 属已知技术债；若路径不存在应写当前仓 `build/` 或显式失败，禁止回退到 docs/Resources |
| 内容录制特例 | `B1_ManualFormationUITests` 等 | `content/position_play/sequences` | 只允许显式 `-only-testing` 的录制流程；不得进入普通 smoke / W15a 默认巡游 |

## 已确认的默认执行关系

- `QiuJi.xcscheme` 的 TestAction 同时包含 `QiuJiTests` 与 `QiuJiUITests`，没有 `.xctestplan`。
- `QiuJiUITour.xcscheme` 只包含 `QiuJiUITests`，用于长巡游；必须配合 `-only-testing`，否则会运行整个 UI target。
- `make test` 当前末尾带 `|| true`，不能作为诚实的全量测试结论；v47 基线和收官一律用直接 `xcodebuild` 并检查退出码。
- `ScreenshotTourUITests` 已改为默认写 `build/v47-screenshots/{light|dark}`，建目录和 PNG 写入不再使用 `try?`；完整设计师巡游按 66 张预期 manifest 做缺图断言。
- v49 的 21 个文案取证测试统一写入仓库忽略目录 `build/v49-screenshots/`；写入失败会触发 `XCTFail`，不会回写 Drill、精讲图或设计基线真源。
- v52 的首页/设置与每日页截图测试通过 `TEST_RUNNER_V52_SHOT_DIR` / `V52_SHOT_DIR` 注入每次运行的 `build/v52-qa/<runtime>/<device>/<appearance>/<size>/` 隔离目录；未提供环境变量时仍只写忽略的 `build/v52-*`，写入失败会让测试失败。
- v53 的 `V53ProfilePreferencesTests` 只在 `FileManager.default.temporaryDirectory` 下创建 UUID 隔离的头像 JPEG 缓存目录，并由每条测试的 `defer` 删除；不写仓库资源、用户真实头像或长期证据目录。
- v54 的迁移测试只在 `FileManager.default.temporaryDirectory` 下创建 UUID 隔离 store 并清理；`V54ScheduleUITests` 只写调用方注入的 `build/ui-reviews/v54/<device>-<appearance>/`，不覆盖设计基线或 Bundle 资源，写入失败直接使测试失败。

## W15a 复核

1. 重跑机器差集，确认写盘文件数与本清单一致。
2. 对所有默认执行的 runner 检查 gate，实际测试前后用 `git status --short` 确认未改 `QiuJi/Resources`、`content/`、`docs/ui-polish/`。
3. 所有 v47 截图只出现在 `build/v47-*` 或 `tmp/`；Stitch 选中截图只进入 `docs/design/v47/stitch/selected/`，且不冒充 App 截图。
