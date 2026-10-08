# UR-20261008｜全App通用界面B02 r4基线审查

对象：改造前原生基线，非设计稿验收。页面执行gpt-6.1-sol；独立逐图审查gpt-6-astra；主控抽看原图并独立复算包、资源与文档证据。46张源PNG、37张计入其实际状态覆盖；失败/未命中仍保留。最终结论以[独立终审](../../output/app-interface-redesign/B02/r4/review/review.md)与[收口卡](../app-interface-redesign/batches/B02-CLOSEOUT.md)为准。

| 设计输入 | 原图/源码证据 | 归属 |
|---|---|---|
| 系统大字下搜索图标放大，卡片正文保持固定，系统菜单另一种放大 | R4-D001/D002；BTLibrarySearchBar未给icon设font、TextField用btCallout、44pt固定外框 | B03-B字体/搜索容器契约 |
| 休息中最小化后外部胶囊仍为绿色播放0:00，恢复后回休息卡 | R4-T001→T002→T003；不是橙色倒计时胶囊 | B03-B、R05状态表达 |
| 长文聚焦隐藏完成/跳过，收键后再显示；小屏表单另有IME组合态 | R4-T006/T007、SE002/SE003 | B03-B、R06输入与键盘契约 |
| iPad使用顶部五Tab，大图两列和宽列表的信息密度需比较 | PAD-P001–005、成功PAD-L006–010、S001/R001 | B03-A宽屏方向与样板选择 |
| 精讲和理论阅读有不同真实页尾，不应套同一种CTA | L001无CTA；L003/L005/L008分别阅读入口/选择器 | R04/R09；球相关内容保护 |
| 账号和订阅仅验证本地fixture的外壳 | A001–006 | R10/R12，真实服务与正常商品仍独立待验 |

## 返工与限制

- FL-135：横屏首五张被临时标签误报为根页，实际停在Pro sheet；主控已向用户纠正，旧图保留，正确五Tab另拍且独立逐张审读。关闭需最终metadata与覆盖一致，不靠文件名。
- 窄窗尝试未成功。W001全屏、W002只有竖屏方向回程；真实window/page及双向变化仍是后续可调窗口契约的前置。
- r1未知逐图几何继续未知；只复用导航/内容结构与历史外观。跨尺寸布局使用r2/r3/r4实测代表，窗口安全区不等同sheet内部或键盘区域。
- 46图绑定固定r4安装包；FreePlay构建期间附近漂移与后续workspace UI状态变化另记，球相关新鲜度不由本包认证。
- 图册浏览器复验因工具禁止file://未执行，未尝试绕行；文件/链接检查另记。原PNG已由审查者逐张打开，HTML准备入口不是Figma候选。

详细逐图记录见[astra笔记](../../output/app-interface-redesign/B02/r4/review/visual-notes.md)、[主控抽图与纠正记录](../../output/app-interface-redesign/B02/r4/root-visual-notes.md)。本轮未改App/Figma、未跑全功能XCTest或真机验收。


## 最终裁定

B02设计前基线已完成，进入B03-A；FL-135过程返工关闭。46正式PNG＋4 raw由astra实际逐图，710不可变输入校验通过；主控另复算117个ID、原图/AX/sidecar、构建/安装与资源。后续功能QA、真实窄窗、正常商品及三个未采普通容器仍按所属批次执行。详见[主控裁定](../../output/app-interface-redesign/B02/r4/root-review.md)。
