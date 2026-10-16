# 完成重录后同步生产序列 · 2026-10-15

用户已完成全部重录，授权全部替换到生产资源。当前角色 Content Engineer；按内容真源契约，将编排台保存源完整同步至 App 的 DrillBoards。

## 结果

- 通过 `make -f scripts/Makefile tryout-sync TRYOUT_DRILL_IDS=` 全量同步；98 个球形／629 杆，源与 Bundle 文件名集合和 SHA256 全部相同。
- 相对本轮同步前生产资源，8 个球形／61 杆的存档更新，其他 90 份完全不变；没有增删球形、改变杆数或 initial。更正（后续回放排查）：c042/manual02、c071/manual02、c081/manual01 的中文文件名随新录制更新，原“没有改名”结论不准确；稳定 drill/token 未变。
- 7 个球形的 53 杆 after 更新，46 杆 before 更新；43 杆的打点、杆速或目标袋发生实际变化。c039 仅逐杆 UUID 和保存时间更新，球位／击球参数未变。
- 未重新求解或改写用户录制源；所有 Swift 源码哈希保持不变，物理、瞄准及回放实现未改。全库没有 trajectory 字段。

| 动作 / 球形 | 杆数 | 实际打点／杆速／目标袋变化的杆 |
|---|---:|---|
| drill_c039 直线球组合走位 · 球形1 | 8 | 无，只有录制标识更新 |
| drill_c042 初级蛇彩 · 球形2 | 5 | 1,3,4 |
| drill_c064 三球连打 | 3 | 2 |
| drill_c069 中级蛇彩 · 球形2 | 10 | 1,3,4,5,6,7,8,9 |
| drill_c071 高级蛇彩 · 球形2 | 15 | 1,2,3,4,5,6,7,8,9,10,11,12,13,14 |
| drill_c079 四球走位 · 球形1 | 4 | 1,2,3 |
| drill_c081 四球同袋走位 · 球形1 | 4 | 1,3,4 |
| drill_c082 横向蛇彩围 8 · 球形1 | 12 | 1,2,3,4,5,6,7,8,9,10,11 |

高级蛇彩第12杆同时更新目标袋；所有变化的逐字段旧／新值均保存在 `differences.json`，未遗漏对象球或母球位置。

## 验证

- `native-validation.json`：直接编译当前生产 `PositionPlayModels.swift`，CanvasPoint 定义从当前 DrillContentService 原样提取；原生 Swift JSONDecoder 成功读取 98 个球形／629 杆／1,356 个球面快照／5,126 条球位记录，失败 0。检查逐杆标识唯一性、球身份、坐标与输入有限值。这是读取／数据完整性校验，不宣称重新物理仿真或逐杆 UI 回放。
- `integrity.json`：98 份源／生产按字节一致，源文件及全部 Swift 源码未变。
- `content-check.log`：I8 98通过0违规；C2/C3/C4 及 I5–I13 无新增结构／引用问题。完整 `verify-tutorials` 退出失败：C1 共79份旧出片新鲜度失败；图片和视频尚未按最新序列重做，未声明媒体全链路通过。
- 本次范围是仓库生产资源同步。未构建或安装新 App、未提交推送、未发布 App Store；内容 OTA 尚无生产通路，现有安装包不会自动更新。用户模拟器未重启、重装或导航。

## 备份与证据

`output/final-rerecord-sync-20261015/`：
- `source-before/`：完整编排源（含既有备份子目录）；`bundle-before/`：替换前生产资源。
- `baseline.json`、`preflight.json`、`differences.json`、`integrity.json`：快照、清单、完整差异和一致性。
- `sync.log`、`validator-build.log`、`native-validation.json`、`content-check.log`：实际执行结果。
