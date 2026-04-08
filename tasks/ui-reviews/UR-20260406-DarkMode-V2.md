## UI 截图审查报告（V2 Delta）— Dark Mode 全局
日期：2026-04-06

审查类型：V2 增量比对（对照 V1 报告 UR-20260406-DarkMode-Screenshot.md）
截图来源：E-01-01 ~ E-01-06（V2 实机截图，共 6 张）
设计参考：E-01 stitch_task_e_01 / frame2 / frame4_02 / frame5（screen.png + code.html）

---

### V1 问题回归状态

| 编号 | 严重程度 | 问题摘要 | V2 状态 | 说明 |
|------|---------|---------|---------|------|
| S-01 | P0 | ProfileView 下半部分渲染为 Light Mode | ✅ 已修复 | 整页（登录卡片、菜单列表、设置组、Tab Bar）均已正确使用 Dark Mode Token |
| S-02 | P1 | 训练首页筛选 Chip 选中态未使用 #F2F2F7 浅底 + 黑字 | ✅ 已修复 | 选中「全部」Chip 现为浅色填充 + 黑色文字，与未选中 Chip 对比显著 |
| S-03 | P1 | 动作库筛选 Chip 选中态（同 S-02） | ✅ 已修复 | 同 S-02，BTTogglePillGroup 统一修复生效 |
| S-04 | P1 | 统计页周/月/年 Chip 选中态 | ⚠️ 无法验证 | E-01-04 统计页被 Pro 锁定遮罩完全覆盖，周/月/年 Chip 不可见；需提供解锁状态截图验证 |
| S-05 | P2 | 角度训练页卡片背景色偏灰 | ✅ 已修复 | 三张入口卡片背景色与其他页面卡片一致，视觉上为 btBGSecondary (#1C1C1E) |
| S-06 | P2 | 统计页 Pro 锁定遮罩缺少半透明暗色叠层 | ✅ 已修复 | 现有半透明遮罩覆盖图表区域，图表内容模糊可见，锁图标居中，「解锁 Pro」按钮在上方 |
| S-07 | P2 | 训练首页卡片圆角与设计稿差异 | ✅ 关闭 | V2 卡片圆角视觉一致，符合 BTRadius.lg (16pt) 规范 |

---

### S-01 详细验证（P0 回归 — 最高优先级）

V1 现象：E-01-06 个人中心从「解锁球迹 Pro」以下全部渲染为 Light Mode（白色卡片背景、浅灰分组间距、白色 Tab Bar）。

V2 截图 E-01-06 逐区域检查：

| 区域 | V1 | V2 | 判定 |
|------|-----|-----|------|
| 登录卡片（「点击登录 / 游客模式」） | 暗色 ✓ | 暗色 ✓ | — |
| 游客模式警告横幅 | 暗色 ✓ | 暗色（黄色调暗底） ✓ | — |
| 「解锁球迹 Pro」卡片 | 暗色 ✓ | 暗色（金色星标） ✓ | — |
| 菜单列表（我的收藏/个人信息/训练目标/订阅管理） | ❌ 白色卡片 | ✅ 暗色卡片（btBGSecondary） | **已修复** |
| 设置组（偏好设置/隐私政策） | ❌ 白色卡片 | ✅ 暗色卡片（btBGSecondary） | **已修复** |
| 分组间距背景 | ❌ 浅灰 | ✅ btBG #000000 纯黑 | **已修复** |
| Tab Bar | ❌ 白色/浅色 | ✅ 暗色背景 | **已修复** |

**结论：S-01 完全修复。** ProfileView 所有可见区域均在 Dark Mode 下正确渲染。

---

### S-02 / S-03 详细验证（P1 — Chip 选中态）

V1 现象：选中 Chip 使用深色填充 + 白色文字，与未选中 Chip 几乎无法区分。

V2 验证：
- **E-01-01 训练首页**：选中「全部」Chip 现为浅色填充（≈ #F2F2F7）+ 黑色文字 + semibold 字重，与未选中 Chip（暗色底 + 白字 + 描边）形成强烈对比。✅
- **E-01-02 动作库**：选中「全部」Chip 同样为浅色填充 + 黑色文字。✅
- **BTTogglePillGroup.swift 代码确认**：选中态 `fillColor` = `Color(red: 0.95, green: 0.95, blue: 0.97)` ≈ #F2F2F8（接近设计稿 #F2F2F7），`textColor` = `.black`，符合设计规范。

**结论：S-02、S-03 完全修复。**

---

### 新发现问题

### N-01 BTTogglePillGroup 未选中态 Token 与设计稿存在细微偏差
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：全局 — 训练首页 / 动作库 / 统计页等所有使用 BTTogglePillGroup 的页面
- **现状**：`BTTogglePillGroup.swift` 中未选中 Pill 使用 `btBGTertiary`（Dark #2C2C2E）作为填充色，`btBGQuaternary`（Dark #3A3A3C）作为描边色
- **预期**：设计稿 code.html §6.3 指定未选中 Chip: `bg-[#1C1C1E]`（= btBGSecondary）+ `border-[#38383A]`（= btSeparator）
- **差异**：填充色偏亮一档（#2C2C2E vs #1C1C1E），描边色偏亮一档（#3A3A3C vs #38383A）
- **影响**：视觉差异很小（ΔL ≈ 4%），截图中难以肉眼分辨，不影响功能
- **修复方向**：将 `fillColor` 未选中分支由 `btBGTertiary` 改为 `btBGSecondary`，`borderColor` 由 `btBGQuaternary` 改为 `btSeparator`
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTTogglePillGroup.swift` 第 16 行、第 32 行

---

### 各页面 Dark Mode 逐项确认

#### E-01-01 训练首页
| 检查项 | 状态 |
|--------|------|
| 页面底色 btBG #000000 | ✅ |
| 今日安排卡片 btBGSecondary #1C1C1E | ✅ |
| 完成勾选图标 btPrimary 绿 | ✅ |
| 「今日训练已完成」横幅 Dark Mode 适配 | ✅ |
| 「官方计划 / 自定义模版」分段选中态 btPrimary 绿 | ✅ |
| Chip 选中态浅底 + 黑字 | ✅ |
| 计划卡片 btBGSecondary | ✅ |
| 「开始训练」按钮 btPrimary 填充 | ✅ |
| Tab Bar 暗色 + btPrimary 选中态 | ✅ |

#### E-01-02 动作库
| 检查项 | 状态 |
|--------|------|
| 搜索栏 Dark Mode 底色 | ✅ |
| Chip 选中态浅底 + 黑字 | ✅ |
| 左侧分类列表暗色背景 | ✅ |
| Drill 卡片 btBGSecondary | ✅ |
| 球台缩略图 btTableFelt 深绿 | ✅ |
| 等级标签配色（L0 绿/L1 蓝/L2 琥珀） | ✅ |
| PRO 标签 btAccent 金色 | ✅ |
| 收藏图标 | ✅ |

#### E-01-03 角度训练
| 检查项 | 状态 |
|--------|------|
| 入口卡片 btBGSecondary（V1 偏灰问题已修复） | ✅ |
| 绿色靶心图标 btPrimary | ✅ |
| 「今日剩余 20 题」btPrimary 绿 | ✅ |
| 副标题文字 btTextSecondary | ✅ |
| chevron 箭头 btTextSecondary | ✅ |

#### E-01-04 统计（Pro 锁定）
| 检查项 | 状态 |
|--------|------|
| 「历史 / 统计」分段标签暗色底 + btPrimary 下划线 | ✅ |
| Pro 锁定遮罩半透明叠层（V1 缺失，已修复） | ✅ |
| 遮罩下图表内容模糊可见 | ✅ |
| 锁图标 btAccent 金色 | ✅ |
| 「解锁 Pro」按钮 btAccent 填充 | ✅ |
| 说明文字 btText / btTextSecondary | ✅ |

#### E-01-05 历史日历
| 检查项 | 状态 |
|--------|------|
| 页面底色 btBG | ✅ |
| 日历卡片 btBGSecondary | ✅ |
| 星期表头 btTextSecondary | ✅ |
| 日期数字 btText 白色 | ✅ |
| 当日日期 btPrimary 圆形高亮 | ✅ |
| 非当月日期 btTextTertiary 低透明度 | ✅ |
| 训练记录卡片 btBGSecondary | ✅ |
| 绿色活动指示点 btPrimary | ✅ |

#### E-01-06 个人中心
| 检查项 | 状态 |
|--------|------|
| 全页 Dark Mode（V1 P0 问题已修复） | ✅ |
| 登录卡片 btBGSecondary | ✅ |
| 游客模式警告横幅 暗色底 + 黄色调 | ✅ |
| 「解锁球迹 Pro」btBGSecondary + btAccent 星标 | ✅ |
| 菜单列表行 btBGSecondary | ✅ |
| 图标色彩正确（❤️红/👤蓝/◎绿/👑金） | ✅ |
| 设置组 btBGSecondary | ✅ |
| 分组间距 btBG #000000 | ✅ |
| Tab Bar 暗色 | ✅ |

---

### 审查总结

- **截图审查范围**：6 张 V2 Dark Mode 实机截图，对照 V1 报告 7 项问题
- **V1 问题修复情况**：
  - ✅ 已修复：5 项（S-01 P0, S-02 P1, S-03 P1, S-05 P2, S-06 P2）
  - ✅ 关闭：1 项（S-07 P2）
  - ⚠️ 无法验证：1 项（S-04 P1 — 统计页 Chip 被 Pro 锁遮挡）
- **新发现问题**：1 项（N-01 P2 — BTTogglePillGroup 未选中态 Token 偏差）
- **总体评价**：Dark Mode 实现质量显著提升。V1 唯一的 P0 阻断问题（ProfileView Light Mode 回归）已完全修复；三处 P1 Chip 选中态问题已通过 BTTogglePillGroup 组件统一修复（验证到 2/3，剩余 1 项被 Pro 锁遮挡）。6 个核心页面 Dark Mode Token 使用正确，页面底色、卡片层级、文字颜色、Tab Bar、球台缩略图等关键元素均与设计规范一致。
- **建议下一步**：
  1. 提供统计页**解锁状态**截图以验证 S-04（周/月/年 Chip）
  2. N-01 作为后续打磨项处理，优先级低
  3. Dark Mode 整体已达发布标准，可进入下一阶段验收
