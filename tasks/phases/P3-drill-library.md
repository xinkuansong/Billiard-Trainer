# P3 — Drill Library（动作库）

> **目标**：完整的动作库 Tab，包含分类浏览、搜索、Drill 详情（Canvas 动画）、收藏、Freemium 锁定。
> **内容前置**：72 个 Drill JSON 分批生产（每批 10 条，H-11 人工验证后继续）
> **前置 Phase**：P2 通过 QA

---

## T-P3-01 Drill JSON Schema 定稿 + index.json 结构

- **负责角色**：Content Engineer
- **前置依赖**：T-P2-04
- **产出物**：`Resources/Drills/schema.md`（Schema 文档）、`index.json` 最终结构

### DoD

- [ ] Schema 与 `content-engineering` Skill 中定义完全一致
- [ ] `index.json` 包含 category 分组：`{"category": "accuracy", "drills": ["drill_c001", ...]}`
- [ ] `DrillContent` Swift 结构体已定义（可 Codable 解析所有 Schema 字段）
- [ ] 编译通过，解析示例 JSON 无错误

---

## T-P3-02 Drill 内容生产 Batch 1（fundamentals + accuracy，10 条）

- **负责角色**：Content Engineer
- **前置依赖**：T-P3-01
- **产出物**：`Resources/Drills/fundamentals/`（5 条）、`Resources/Drills/accuracy/`（5 条）

### DoD

- [ ] 10 条 Drill JSON 全部符合 Schema（`jsonlint` 验证无错误）
- [ ] 坐标自检通过（母球/目标球在台面范围内，路径终点指向正确袋口）
- [ ] `isPremium` 分布：L0 全为 `false`
- [ ] `index.json` 已更新，包含这 10 条 ID
- [ ] **H-11 标记**：在 `HUMAN-REQUIRED.md` H-11 后追加「Batch 1 待验证」

---

## T-P3-03 Drill 内容生产 Batch 2–7

- **负责角色**：Content Engineer
- **前置依赖**：上一批次 H-11 人工验证通过
- **产出物**：剩余 62 条 Drill JSON

### DoD（每批）

- [ ] 该批次 10 条 JSON 符合 Schema
- [ ] 坐标自检通过
- [ ] `isPremium` 符合 Freemium 比例（L1 约 30%、L2 约 60%、L3 约 80% 付费）
- [ ] `index.json` 更新
- [ ] H-11 标记等待验证，验证通过后进入下一批

---

## T-P3-06 DrillLibrary Tab — 分类列表 UI

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P3-01, T-P2-03
- **产出物**：`Features/DrillLibrary/Views/DrillListView.swift`、`BTDrillCard.swift`

### DoD

- [ ] 按 8 大类分组展示，顶部有球种筛选（中式台球 / 9 球 / 通用）
- [ ] `BTDrillCard` 展示：名称、等级标签（`BTLevelBadge`）、难度、是否付费锁定图标
- [ ] 搜索框可按名称过滤（本地搜索）
- [ ] 空数据时显示 `BTEmptyState`（「内容加载中，请稍候」）
- [ ] 列表使用 `LazyVStack` 或 `List`，滚动流畅
- [ ] Dark Mode 正常

---

## T-P3-07 Drill 详情页

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P3-06, T-P3-08
- **产出物**：`Features/DrillLibrary/Views/DrillDetailView.swift`

### DoD

- [ ] 顶部：`BTBilliardTable` Canvas 动画（路径按步骤播放）
- [ ] 「播放/重放」按钮，可重放动画
- [ ] 教学要点（`coachingPoints`）列表展示
- [ ] 文字说明（`description`）展示
- [ ] 达标标准（`standardCriteria`）高亮展示
- [ ] 收藏按钮（心形）实时切换状态
- [ ] 视频占位区（「视频内容即将上线」提示）
- [ ] 付费内容用 `BTPremiumLock` 遮罩，点击引导订阅

---

## T-P3-08 BTBilliardTable Canvas 组件

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P1-03
- **产出物**：`Core/Components/BTBilliardTable.swift`

### DoD

- [ ] Canvas 绘制：台面底色、库边、6 个袋口
- [ ] 宽高比固定 2:1（`aspectRatio(2.0, contentMode: .fit)`）
- [ ] 支持传入 `DrillAnimation` 数据（母球路径 + 目标球路径）
- [ ] 动画播放：`withAnimation(.easeInOut(duration: 1.2))` 分段播放
- [ ] 支持直线路径与贝塞尔曲线路径
- [ ] `#Preview` 可展示示例动画，Light + Dark 均正常

---

## T-P3-09 球种筛选 + 搜索（F1）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P3-06
- **产出物**：`Features/DrillLibrary/ViewModels/DrillListViewModel.swift` 更新

### DoD

- [ ] 球种筛选：「全部 / 中式台球 / 9 球」，切换后列表立即更新
- [ ] 搜索：实时过滤（去抖 0.3 秒），支持中文名称搜索
- [ ] 无结果时显示 `BTEmptyState`（「没有找到相关训练项目」）

---

## T-P3-10 Drill 收藏（F2）

- **负责角色**：Data Engineer + SwiftUI Developer
- **前置依赖**：T-P2-02, T-P3-07
- **产出物**：`DrillFavoriteRepository` 使用、收藏夹入口

### DoD

- [ ] 详情页收藏按钮点击后立即持久化（SwiftData）
- [ ] 「我的」Tab 下有「收藏夹」入口，展示已收藏 Drill 列表
- [ ] 收藏状态在 App 重启后保持

---

## T-P3-11 Freemium 锁定（BTPremiumLock）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P3-07
- **产出物**：`Core/Components/BTPremiumLock.swift`

### DoD

- [ ] `BTPremiumLock` 覆盖在付费 Drill 详情上，显示「解锁全部内容」按钮
- [ ] 按钮点击触发订阅页（P7 前可 stub）
- [ ] 免费用户无法看到锁定内容正文

---

## QA-P3 P3 验收

- **负责角色**：QA Reviewer

### 验收要点

- [ ] 分类浏览所有 Drill，8 大类均有内容（至少前 3 批 30 条完成）
- [ ] Canvas 动画在首次进入详情时自动播放，重放按钮有效
- [ ] 收藏后重启 App 仍保持收藏状态
- [ ] 付费 Drill 被遮罩，免费 Drill 正常展示
- [ ] 离线状态下（断网）动作库可正常浏览（fallback JSON）
- [ ] 搜索「直线」可找到相关 Drill
- [ ] H-11 至少 Batch 1–3 已通过人工验证

---

## ADR 记录区
