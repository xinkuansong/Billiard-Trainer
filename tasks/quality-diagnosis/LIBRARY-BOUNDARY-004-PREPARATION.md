# SC16 球种筛选与收藏磁盘边界准备

2026-09-08，独立Test Engineer准备。**草稿未注册、未编译、未运行，没有新增通过结果。** 仅新增 `LibraryBoundaryDiagnosticUITests.swift` 与本文；不改业务/快照/共享台账，不操作设备。

精确候选：`QiuJiUITests/LibraryBoundaryDiagnosticUITests/testBallFilterResetAndFavoriteAddRemoveSurviveProcessRestarts`，1个同步方法。正常球种筛选与重置→收藏本次c012→进程重启后仍收藏→取消本次c012→再次进程重启仍未收藏；不称跨owner或全筛选矩阵。

## 现有证据与独立预期

`LIBRARY-004-RESULT.md`记录001实际1/1、60.959s：空搜索恢复、c012收藏、两次收藏页重入，**内存同进程**。不重复制空搜索流程；本候选补球种的真实结果集合以及收藏增删的真实进程层。

已读frozen `DrillListView/DrillListViewModel`、`DrillDetailView`、`FavoriteDrillsView`、`BTLibrarySearchBar`，既有 `SystemBoundaryDiagnosticUITests`，以及 `LocalDrillFavoriteRepositoryTests`（内存增/删/去重，不是正常页面或磁盘重启）、`DrillListViewModelTests`球种方法（部分只有数量>0、旧74上界，不能代替精确集合）。仅阅读这些旧测试，没有重跑或扩大其历史结论。

本次只读Python枚举冻结Drills JSON，筛选中文名含“直线”并核字段，发现更小稳定查询 **“直线出杆”** 恰好两个：

| 源ID | 中文名 | ballType | “9球”筛选预期 |
|---|---|---|---|
| drill_c009 | 底袋直线出杆 | universal | 保留 |
| drill_c012 | 中袋直线出杆 | chinese8 | 排除 |

这是冻结内容字段推导出的独立预期，不调用被测ViewModel生成expected。当前逻辑“9球”命中nineBall或universal，全部恢复两个。候选要求两个实际`drillCard_<id>`节点的集合完全相等且完整可见，不将懒加载全库的当前可见数量当全部数量。若实际无法暴露完整两卡或存在额外卡，抛错留PNG/AX，不放宽为只找其中一张。

真实搜索字段为 `textFields["librarySearchField"]`，不是UIKit searchFields。球种菜单 `badgeFilterMenu`，选项 `ballTypeMenu_9球`；启用后label“筛选，已选1项”（源码含空格，草稿按实际源码原样匹配），菜单“清除筛选”只清球种/精讲，不清搜索、等级或分类。此处不碰后两者，重置后要求搜索仍为“直线出杆”、结果重新是两ID、菜单“筛选球种与精讲”。不把该重置称全部筛选清空。

## 隔离与记录

- 必须主控新建专用磁盘游客iPhone、保存初始环境证据，再传 `QD_LIBRARY_BOUNDARY=NEW_DEDICATED_DISK_GUEST_SIMULATOR`、`QD_LIBRARY_DEVICE_UDID=<新UDID>`、绝对 `QD_SHOT_DIR`，支持TEST_RUNNER前缀。比对Runner `SIMULATOR_UDID`，缺失/不符抛错，不在未知设备继续。授权变量不独立证明设备新建，主控仍核实际设备来源。
- 普通磁盘启动，不传inMemory/reset/清库/虚拟账号/深链；使用正常游客、forceNonPremium，跳过引导，仅进入本地Bundle内容、详情与收藏。不登录真实服务、不删除已有收藏；初始收藏页必须“还没有收藏”，否则停下保留旧数据。
- 每次launch先核“我的”`profile.login`真实游客、无accountHeader。收藏/取消都在c012详情正常点“收藏/取消收藏”，不是直接写仓储或clear。收藏页隐藏TabBar，因此每次核收藏结果后正常返回再切Tab，避免旧根页假设。
- 两次均显式terminate→等待notRunning→同磁盘launch；终止前已有正常返回和收藏页读回，但不额外伪造context.save。若原生产autosave行为未可靠持久化，应保留失败，不靠固定长等或测试写库掩盖。主控运行后可从真实日志核PID变化，独立只读SQLite计数作为补强；本草稿本身不打印伪PID，也不称SQL已验证。
- 所有检查throw中止，不首错后继续success。teardown先保存terminal-unclassified PNG/AX再终止本App；阶段图名只描述观察，唯一最终verified附件与日志位于所有必要断言之后。运行原件按004协议归档，数据保留，不清沙盒。

## 剩余边界

本候选不证明分类主副分类并集、等级/精讲组合、全库结果、跨owner、同步或磁盘写入失败恢复。仅两次正常进程重启证明本次游客c012增删可重读；收藏页以内容去重，若要证明底层没有重复或孤立记录仍需独立P层读库，不能从一张卡推出数据库恰一行。

控件类型与矩阵尚未现场核对：普通iPhone底部TabBar、两卡完整露出、菜单选项AX、首次键盘引导。草稿仅对已存在的“Speed up your typing”→“Continue”做明确处理，其他系统引导不猜点。Profile滚动选实际纵向ScrollView、短幅手势，无法唯一识别或充分露出即停。运行若遇首错先看PNG/AX再做有界适配，不把控件定位失配说成收藏或筛选缺陷。

交付前只读再次枚举冻结JSON的精确“直线出杆”查询，结果确为上表两项；`xcrun swiftc -frontend -parse`退出0。后者仅语法解析，不是类型检查、构建或运行通过。
