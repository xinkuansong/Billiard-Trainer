# 撤除实验 trajectory · 2026-10-15

状态：实现完成，arm64 模拟器定向回归 18 项通过。

用户要求：不需要 trajectory，基于 before 用当前引擎计算 after。

- 删除 9 个球形/38 杆嵌入 trajectory（源与 Bundle 各一份），以及初级蛇彩 2 独立 5 杆重建轨迹。
- 移除采样 DTO、自动捕获/持久化、回放与导出冻结采样分支和旧引擎轨迹生成工具；保留运行时物理轨迹、辅助线、旧方向兼容及镜头/摆球修复。
- 98 个序列/629 杆按清理前数据验证；只删除 trajectory，其他字段不变。本轮不重算存档 after，不改现有物理/瞄准，也不宣称历史连续序列能复现旧停点。
- 现有选择重录单杆/后续、保存回上一杆语义保持。解码忽略旧 trajectory，重新编码不会保留该未知字段。
- 原冻结轨迹实验测试随功能退役，替换为当前契约测试；历史失败/通过日志仍保留，不修改成新结果。

证据：`output/trajectory-removal-20261015/`。`before.zip` 为修改前压缩备份（含原序列/旧独立轨迹/受影响源码）；`removal.json` 为逐文件删除数、字节数及非轨迹字段等值检查。

验证：
- `tests-r1.log`：arm64 编译和运行成功，18 tests / 0 failures / 80.810 秒。11 项编排重录、3 项引擎持久化、3 项旧方向兼容、1 项录制草稿切视角与保存重载。
- `post-clean-counts.json`：源与 Bundle 各 98 球形/629 杆，trajectory 均为 0；旧独立轨迹不在实际测试 App Bundle 中。
- `verification.json`：196 个源/Bundle JSON 仅删除实验字段；所有其余字段等值。物理公式、求解器、瞄准和场景代码哈希未变；仅运行时录制器/播放器删除冻结轨迹挂接。
- `build.log`：首轮 generic（含 x86_64）构建失败于已有 ATeachingStandardsUITests.swift:632 表达式类型检查。未修改该文件；后续当前主机 arm64 定向构建/测试通过。不能声明全架构全套测试通过。
- `doc-size.log`：文档体积门禁通过。
- `tutorials.log`：全量内容校验仍失败 10 项：8 项旧出片新鲜度，c001/c031 两项源与 Bundle 差异。清理前备份证实两项差异已存在（preexisting-mismatches.json），没有扩大范围覆盖用户版本；未重新出图/视频。
- 原生产资源减少约 80.42 MB。`before.zip` 压缩备份约 8.54 MB，仅位于 output，不参与运行时回放。

未安装用户 iPad 或真机；未发布、提交。
