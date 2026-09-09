# 收藏三方归属隔离补验

2026-09-08 20:47。`formal-004-favorite-owner-001`：**1/1 方法通过，0.610 秒，make 退出 0**。主控审阅生产仓储及测试后，在新建 iPhone 17 Pro / iOS 26.2 专用设备 `49478864-76E3-49FA-904C-E4D5AF065EE9` 执行；session 66153 已结束。

精确方法：`FavoriteOwnerDiagnosticTests/testSharedAndDistinctFavoritesRemainScopedAcrossGuestABQueriesAndMutations`。使用真实 LocalDrillFavoriteRepository、全新内存 ModelContainer、独立 CurrentOwnerContext 及合成游客/A/B；宿主初始化前使用内存模式，没有真实身份或权益夹具。预期与隔离约束见 [预飞](FAVORITE-OWNER-004-PREFLIGHT.md)。

| 阶段 | 游客 | A | B | 独立 context 总行数 |
|---|---|---|---|---|
| 空库 | 空 | 空 | 空 | 0 |
| 各自新增，重复收藏共享动作 | c001/c009 | c001/c012 | c001/c037 | 6 |
| A 删除共享 c001，再删除自身没有的 c037 | c001/c009 | c012 | c001/c037 | 5 |
| A 重加 c001，游客删 c009，B 删 c001 | c001 | c001/c012 | c037 | 4 |

每阶段切换三个 owner，核精确集合、行数、owner 字段及四个动作的 isFavorited；另一个无 owner 过滤的 context 核全表配对、重复行。A 删除后另外两方原行时间戳保持。主控读取原日志及四阶段 JSON，实际与独立预期一致；没有失败 JSON。

[归档](../../archive/quality-diagnosis/runs/formal-004-favorite-owner-001/) 包含 61 个文件的 SHA 清单、精确 selector、执行配置、测试源码、原日志及 xcresult。四阶段原件在 screenshots/favorite-owner-19A8A33C-FE5F-4360-9D27-506CA91C9378/。

补齐 SC16/SC25 **本地收藏查询和增删的 owner 隔离**。旧迁移测试不能替代此证据；本次也不证明真实登录切换、页面刷新、磁盘重启、跨设备或云收藏同步。未修改业务代码，未新增问题。
