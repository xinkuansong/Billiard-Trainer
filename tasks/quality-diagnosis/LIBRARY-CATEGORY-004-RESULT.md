# 动作库分类及查询重置诊断

2026-09-08，SC16，冻结 snapshot-004；只诊断，未改业务实现。

`formal-004-library-category-001`：1 方法通过，147.732 秒，runner/recorder 均退出 0。专用新 iPhone17Pro/iOS26.2，UDID `174D84C2-1031-4AEA-8117-4DE497B1DEDE`；普通磁盘游客，仅语言启动参数，无内存、身份、Pro 夹具。

正常进入动作库，点击走位，逐屏完整可见卡片累计得到独立预期 24 项（14 主分类、10 次分类），无额外或遗漏。保持分类搜索“直线”，只有 c039；点击侧栏“全部”后查询保持，恢复 c001/c009/c012/c022/c039/c072 六项。

预期由主控独立读取冻结索引及 74 份 JSON 重算，与预飞一致，详 `observations/library-category-root-golden.json`。结果列仅定位含 drillCard 的唯一 ScrollView；全分类 step0–8，搜索交集 step0–2，重置查询 step0–3，均在两次前向手势无进展后验证完整精确集合。不是读取实际 contentSize 的证明。

主控已审 5 张完整 PNG：分类底部 step6/8、交集 step2、重置查询 step0/3。最后中级/高级蛇彩卡完整露出且底部稳定；交集只有直线球组合走位；重置后非走位内容恢复且末卡可达。完整图与 AX、动作日志相互支持。本轮没有新增产品缺陷。

运行和 xcresult 151 文件，加 6 个 observer 文件及独立预期/图审两文件，共 159 文件按 SHA 归档在 `archive/quality-diagnosis/runs/formal-004-library-category-001/`。xcresult：`Test-QiuJi-2026.09.08_20-08-49-+0800.xcresult`。测试源保存在 tested-sources；19 张 PNG/AX 均保留，5 张关键图主控目视，未声称逐帧检查整段录像。

20:13:10 再核原 5350 个冻结输入，改变/缺失均 0；见 `build/quality-diagnosis/observations/source-recheck-library-category001.json`。仅一个类别及判别性查询，不代表全 74 项 UI 遍历、所有筛选组合或真实账号跨设备行为；SC16 整体仍 partial，原 38 场景范围不变。

下一步：正常自由击球开球玩法观察及实际交付链；Release 运行、每日清台余项和最终证据审计仍待。
