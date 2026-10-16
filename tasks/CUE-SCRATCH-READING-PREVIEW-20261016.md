# 母球掉袋阅读页 · 交互样稿

2026-10-16。用户授权先做「不吃库／吃一库」两类效果，格式不必严格沿用动作库精讲。本轮交付独立 HTML 阅读预览，确认后再接 App；不改 App 源码、物理或原图。

## Direction contract

THESIS：用真实球形识别掉袋路线，图片与简短解释组成连续阅读，不套动作课章节。

OWN-WORLD：沿用球迹系统字体、绿色强调、浅灰底和白色阅读面，提供深色模式。完整原图，不在台面叠加新信息框。

STORY：切两类 → 看图与具体讲解 → 放大核路线 → 回读另一类。

FIRST VIEWPORT：固定导航与两段分类，短导语和图例后直接进入首张大图；手机纵向阅读，宽窗口图文并列。

FORM：已确认的两 Tab 阅读结构，直接扩展现有语言；不执行概念抽签。重点交互为类别独立滚动记忆和图片查看；遵循减弱动态效果。

FINISH：unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## 素材与事实边界

- 不吃库：M067、M007、M033；一库：M203、M224、M265。均已逐张查看无文字框 `-scene.png`。
- 原图直接复制，六张来源及 SHA 见 `output/cue-scratch-reading-preview-20261016/review/sources.json`。不改像素、不使用封面统计决定案例数量。
- 事实源：两组 `topdown` 文件夹的 cases.json、fixture.swift、REPORT.md。实际导出 manifest/verification 另核参数。球形独立，不能推导单变量规律。
- 固定竖图坐标：世界 XZ 米制、Y 上，屏幕上=+X、右=+Z；袋口中文按竖图映射。只读取已有事件/几何，不新增模拟。
- 六例中心打点、不加塞来自原导出 fixture 的 spinX=0/spinY=0。杆速为示例输入，不提供未验证的避让打法或通用力度阈值。
- 本轮独立专题不套动作库训练剂量、下一杆目标、逐杆 params 模板；采用文案技能的事实与自然表达原则。尚未进行 App 集成、原生验证或用户视觉验收。

## 状态

**⏸ 用户主动暂停（2026-10-16）**：用户原话「算了，记录下吧，先不做了」。保留选题、两类交互样稿、原图及检查证据；不继续设计、扩充球形或接入App。当前样稿未获用户视觉验收，独立审查的ship仅为历史预览交付结论，不代表批准实施。用户明确要求重启后再确认方向。

样稿已制作。入口：`output/cue-scratch-reading-preview-20261016/r1/index.html`；本地浏览地址 `http://127.0.0.1:8766/`（仅绑定127.0.0.1）。

2026-10-16浏览器验证：320/390/768/1440宽度检查；320/768/1440 DOM无横向溢出、三图均加载；默认1280宽也无溢出。两类完整长页、浅深首屏、放大查看、入口均截图。实际指针点击从不吃库1344px切出再返回1344px；大图放大产生可滚动区域、Esc关闭；入口往返、键盘Home切分类已核，console error为空。来源复制6/6 SHA一致；导出manifest确认六例spin=[0,0]和页面杆速匹配。JS语法与doc-size通过。

独立终审首轮发现 phone-direct.png 捕获于选中背景过渡中，正文和白底选中表象不一致；已在DOM确认选中后重采稳定首屏，不把该截图问题归为持续功能缺陷。检查细节与最终结论见 `output/cue-scratch-reading-preview-20261016/review/`。

边界：Playwright独立截图脚本因本机缺Chromium未运行，已改用Codex内置浏览器完成上述实际验证；该失败脚本保留作诊断，不作为通过证据。impeccable启动器权限拒绝，自动设计检测未跑；通用独立审查角色代替未暴露的专用reviewer。未做动态大字号、原生App、真机、用户验收、提交或发布。

独立终审最终结论：ship（仅独立HTML预览交付范围）。稳定首屏与其余九图纳入最终审查；DESIGN.md / REVIEW.md 已写于 review 目录，不作为App已验收证明。

下一步：保持暂停，等待用户明确要求继续；恢复时从本记录与保留样稿开始，不默认沿用当前设计为已批准方案。
