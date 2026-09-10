# 统计 PRO 对齐修正（DR-123）

日期：2026-09-09；当前执行者切换 UI Reviewer 完成原图审查。

## 需求与根因
保留右侧16pt边距，将图标和统计略向左移，标题与PRO顶部对齐，间距8pt。原整栏overlay未留位，且下划线影响垂直居中。改为分段标题行按角标固有宽度留位，顶部对齐；可见角标仍独立于按钮的无障碍节点。

## 功能验证
- 最终 make -f scripts/Makefile build SIM_DEVICE=QiuJi-Onboarding-Pro：exit 0，BUILD SUCCEEDED；build-final.log。xcpretty未安装，Makefile正常回退原始输出。
- CUA实际操作：标准手机记录→统计→历史成功，选中态与角标显隐正确；SE记录→统计成功。
- AX读回：标准手机proBadge/Pro 内容/已解锁；SE proBadge/Pro 内容/未解锁；历史、统计原按钮标签保留。
- git diff --check与verify-doc-size通过。纯布局修正，未新增或运行XCTest。

## 视觉审查
- iOS26.2，标准手机402pt及SE375pt，均large默认字号。
- 已打开完整原图：before.png、after-pro-light.png、after-pro-dark.png、after-se-light.png，均在output/statistics-pro-alignment/。
- 标准手机同数据前后比较：右边距保留，标题左移，PRO上移，图标/文字完整且不重叠；下划线保留分段宽度。浅深与SE未见新增标题裁切。
- SE验证未解锁，标准手机验证DEBUG已解锁；未做真实购买、iPad、真机或完整VoiceOver验收。截图页面为统计空态，未复刻用户已有训练数据，但顶部共用同一布局。
- 下一步：用户真机视觉反馈。未提交。
