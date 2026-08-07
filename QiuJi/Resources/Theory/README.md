# Theory —— 16.billiard_theory 契约快照（vendored）

> 本目录是 **13.billiard_trainer 首次 vendor 16.billiard_theory 的 `contracts/`**（v30 W0）。
> 决策与权衡见 `tasks/phases/P12-content-system-theory.md` § ADR-P12-04。

## 目录内容

| 路径 | 来源（只读） | 说明 |
|---|---|---|
| `contracts/theorem-tags.json` | `16.billiard_theory/contracts/theorem-tags.json` | 10 条定理元数据（`name_zh` / `statement_one_liner` / `key_data` / `common_errors` / `applicable_modules`） |
| `contracts/module-tags.json` | `16.billiard_theory/contracts/module-tags.json` | 6 个固定解模块元数据（M01–M06，本轮不上线模块页，仅备 id 校验） |
| `contracts/run-out-flow.json` | `16.billiard_theory/contracts/run-out-flow.json` | 清台 5 步决策流程状态机 |

`contracts/` 内**只放逐字节快照**：不格式化、不重排、不裁字段。本 README 是 13 侧文档，故放在
`Theory/` 根而非 `contracts/` 内，保证 `contracts/` 目录可与 16 源直接做 `shasum` 比对。

## 源版本

| 项 | 值 |
|---|---|
| 契约 schema 版本 | `schema_version` = **1.1.0**（三个文件一致） |
| 文件内声明的理论版本 | `theory_version` = **v1.0-rc3**（三个文件一致，`generated_on` = 2026-05-05/06） |
| 16 仓库当时的理论版本 | **v1.0-rc4**（`16.billiard_theory/README.md` L147，2026-05-07） |
| 同步日期 | **2026-08-07**（v30 W0） |

⚠️ **事实登记**：16 仓库主线已到 v1.0-rc4，但 `contracts/*.json` 自 rc3（2026-05-06）起未随之重生成，
文件内 `theory_version` 仍写 v1.0-rc3。本快照与 16 磁盘上的 contracts 逐字节一致；
「rc4」只是 16 的理论文本版本，不是本快照的版本。升级理论文本时按下面的通道处理。

## 用途（D-v30-1 裁定：理论正文硬编码 SwiftUI，不走 JSON）

1. **W5 层 2 一句话弹层的数据源**：精讲 chip → 弹 `statement_one_liner`（读本快照）。
2. **`theoremIds` / `theoremRefs` 合法性校验的真源**：drill / 精讲挂接的 id 必须存在于
   `theorem-tags.json.theorems[].id`（W5 加解码校验或测试断言）。
3. **索引页副标题的取材源**：`TheoryCatalog` 的副标题是 `statement_one_liner` 的**连续子串**
   （只截断、不改字），见 `docs/research/20260807-v30理论页组件规范.md`。

⛔ **理论正文不消费本目录**：T01–T10 / 流程 / 速查表的正文是硬编码 SwiftUI 视图（D-v30-1）。
运行时不做 JSON → 正文渲染。

## 版本升级通道

16 修订理论后：

1. 重新 vendor：把 16 的 `contracts/{theorem-tags,module-tags,run-out-flow}.json` 原样覆盖到
   `contracts/`，并更新本 README 的「源版本」表。
2. 逐字段 diff（`git diff` 即可），列出发生变化的 `name_zh` / `statement_one_liner` / `key_data` /
   `common_errors` 条目。
3. **人工修订受影响的硬编码页**：正文写在 Swift 视图里，contracts 变更**不会**自动反映到正文——
   必须改代码并重新发版。这是 D-v30-1 选硬编码的已知代价（ADR-P12-04 权衡记录）。
4. 若 `theorem-tags.json` 删除或重命名了 id：先修 `theoremIds` / `theoremRefs` 挂接与 `TheoryCatalog`，
   再跑合法性校验。

## 打包

`project.yml` 以 **folder reference** 声明（`sources` 下 `type: folder` + `buildPhase: resources`），
故 Bundle 内保留 `Theory/contracts/` 子目录结构，可用
`Bundle.main.url(forResource: "theorem-tags", withExtension: "json", subdirectory: "Theory/contracts")`
解析。新增文件到本目录后**无需**改 `project.yml`，但需重跑 `make xcodegen` 之外的普通构建即可。
