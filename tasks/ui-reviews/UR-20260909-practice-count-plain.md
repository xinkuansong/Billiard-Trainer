# 动作库已练次数去底色
日期：2026-09-09。SwiftUI Developer → UI Reviewer。

- BTPracticedBadge删除绿色背景/胶囊，使用btTextSecondary；勾选、次数、字体和padding保留。
- `make -f scripts/Makefile build`：BUILD SUCCEEDED，exit0；日志output/practice-count-plain-20260909/build.log。
- 17Pro/iOS26.2原有真实本机次数5/6/2/2/1/1，改前与改后浅色、深色整页原图均已打开目视；卡片尺寸、标题及次数对齐保持，绿色块消失，无新增截断。
- 纯样式变更未新增测试；计数逻辑未变。真机/iPad/完整AX未验，未提交发布。
- [改前](../../output/practice-count-plain-20260909/before.png) · [浅色](../../output/practice-count-plain-20260909/after-light.png) · [深色](../../output/practice-count-plain-20260909/after-dark.png)

## 后续确认：品牌色文字（最终）
- 用户批准勾选/次数使用btPrimary、medium字重；背景继续透明。
- BUILD SUCCEEDED，日志output/practice-count-brand-text-20260909/build.log；17Pro/iOS26.2浅深色整页已打开目视，数字与标题清楚，无新增截断。此版取代前面的灰色特粗文字。
- [最终浅色](../../output/practice-count-brand-text-20260909/after-light.png) · [最终深色](../../output/practice-count-brand-text-20260909/after-dark.png)。未作真机/完整AX验证。
