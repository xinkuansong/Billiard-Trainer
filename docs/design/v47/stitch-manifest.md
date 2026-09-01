# v47 Stitch 资产清单

状态：W1a 历史冻结（2026-08-30）。专用项目、原 `DESIGN.md` 1.0 上传实例与移动端 Design System 均已核验；v47.4 保留整体设计目标，但取消 Stitch Gate A/B 和后续生成，本表只保留审计证据，不再作为实施依赖。

## 项目与 Design System

| 字段 | 值 |
|---|---|
| 项目标题 | `QiuJi v47 Full UI Redesign` |
| Project ID | `2158977091089927282` |
| DESIGN.md 上传 Instance ID | `4540407438676713064` |
| DESIGN.md 上传 Source Screen | `projects/2158977091089927282/screens/4540407438676713064` |
| Design System 名称 | `球迹 v47 Precision Instrument` |
| Design System Asset ID | `90dcaae24c10404595ac1d9286b232ff` |
| DESIGN.md 版本 | 1.0 |
| DESIGN.md SHA-256 | `2ea19b2f7a30d44963a54036838f98b83399722bfd3cb9b00f9ca1052a486255` |
| 旧项目隔离 | `projects/10326441648877520041` 只读，不更新、不 apply |

## 提示词版本

| ID | 批次 | 页面族 | 外观 | Prompt SHA-256 | 状态 |
|---|---|---|---|---|---|
| `v47-gatea-training-light-v1` | 原 W1b | 训练根页母版 | Light | `297256e90f1ef684a85ff05ddf1cea1e900305be6debb4ed1b46bfc563d8acd1` | 历史冻结；不再生成 |
| `v47-gatea-training-light-variants-v1` | 原 W1b | 训练根页变体 | Light | `efdf6bf9b4d4ea50c3f1d7294ef1eb02d5cfc55bfe4f1dee2e504deb37f186af` | 历史冻结；不再生成 |
| `v47-gatea-history-light-v1` | 原 W1b | 历史/统计母版 | Light | `4e6b48c5cc79aaf75e3f588407a9ea023fa230d91346de19189e6b36796257f7` | 历史冻结；不再生成 |
| `v47-gatea-history-light-variants-v1` | 原 W1b | 历史/统计变体 | Light | `6296e817110a277af314a37a7f0a8402182e3242b9a7f5660c4505820885fb98` | 历史冻结；不再生成 |

提示词原件位于 `docs/design/v47/stitch/prompts/`，仅供审计；v47.3 不再调用 Stitch。

## Screen 清单

| 页面族 | 外观 | 候选 | Screen ID | Instance ID | 选择状态 | 理由 / 淘汰原因 |
|---|---|---|---|---|---|---|
| 训练根页 | Light | 未生成 | — | — | v47.4 已取消工具批 | 改为直接审计真实 App |
| 历史/统计 | Light | 未生成 | — | — | v47.4 已取消工具批 | 改为直接审计真实 App |

原 Gate A/B 已由 v47.4 撤销。若未来另立设计探索任务，必须新建决策，不得把本表的未生成项恢复为当前批次。
