# B01 盘点格式与计数口径

日期：2026-10-08；输入 [PLAN](../PLAN.md) 与 [EXECUTION](../EXECUTION.md)。本波仅源码调查，运行导航和现行画面均留 B02。

## 交付

每域写 `inventory/B01-<T|L|P>.md`（可读报告），以及 `output/app-interface-redesign/B01/<T|L|P>/inventory.json`（页级原始记录）。根域由主控写 `B01-SHELL.md` 与 `SHELL/inventory.json`。共享文档由主控统一更新。

JSON 顶层：`batch`, `audited_at`, `source_baseline`（指向 B01/source-baseline.json）, `entries`, `coverage`（检索文件和方法）, `unknowns`。

每条 entry 必填：

- `id`：沿用 Pxx；若页面族拆分，使用 Pxx-01、Pxx-02…；禁止同时把父族和子页都计为独立页面。
- `family_id`, `title`, `kind`：kind 取 screen / modal / dialog / system / shell / component / external / internal。
- `scope`：included / mixed / external / conditional；`owner_batch`：本次唯一盘点所有者。
- `source_status`：located / conditional / unlocated；`runtime_status`：本批全部 unrun。
- `entry_points`：每项 `from`、`trigger`、`presentation`、`condition`、`anchor`（路径:行号）；入口重复可多列，不重复造页。
- `anchors`：每项 `path`（仓库相对路径）、`line`（正整数）、`symbol`；对应源文件须纳入本批 source-baseline 或域内补充 hash 清单。
- `states`：明确代码具备的状态和分支；需求覆盖但当前未实现的状态只列 risks/unknowns，不能编成已有状态。
- `protected_regions`, `shared_consumers`, `risks`：允许空列表但不得省字段。
- `version_evidence`：`design`、`native`、`acceptance` 各记 status/reference/basis；未发现有效设计或原生版本写 unverified，旧图只作 historical_reference。无需为每页重复抄一份通用来源。
- `legacy_v58`：对应旧页面单元/条款与 reference、关系（reuse_candidate / historical_reference / old_owned / no_match）；不伪造旧产物，不关闭旧任务。
- `next_action`：B02 真实入口/具体状态优先级及保护区。

`unknowns` 每项含 id / description / owner / next_action。跨域共用目的页只由唯一域记 entry；消费域用 entry_points 或 shared_consumers 交叉引用。

## 范围

- T：P02–P13（含 P06 共享动作选择器、P09 分享、P11 补记、P12 提醒，其他域只引用）。
- L：P14–P18（含详情/精讲/理论独立子页；专用球桌目的地交界只引用 P37）。
- P：P19–P35（记录/统计＋我的/设置/账号；P38 PhoneLogin 的内容只回报主控，不独立重复登记）。
- SHELL：P01/P36/P37/P38、全局 routes/测试条件、系统级入口。

独立页面、模态内容、确认/错误对话框、系统界面分别计数；Menu/Picker 行内控件作为宿主状态，不当作新页。相同 View 被 push/sheet/多 Tab 重用只算一次。外部球桌页只记边界，内部 UI 不穷尽；系统对话只数 App 明确触发的用户界面，OS 变体留 B02。每项都需要实际源码证据。

## 版本与证据界限

B01 只冻结当前源码范围的盘点分母；随漏项/新增按版本扩充，不能称运行全覆盖或最终设计任务数。最近设计/截图若无法与当前源码对齐，明确待核。禁止从旧截图巡游 PASS 推导生产入口可达。

自定义记分键盘等真实通用控件记 component；internal 专指内部/测试工具，不混淆。系统键盘本身只作宿主状态。

同一正文View的不同宿主包装（例如心得编辑的历史sheet/训练草稿sheet）若确需独立记录标题、保存与取消语义，kind=shell并引用正文唯一ID；不再计成第二个独立screen/modal。OS绘制的授权/照片/购买等界面scope=external，仍属于触发与返回的验证面；App自绘LiveActivity内容scope=included。系统是否一定展示用source_status/condition说明。
