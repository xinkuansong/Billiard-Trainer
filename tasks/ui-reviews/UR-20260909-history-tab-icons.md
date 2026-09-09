# 记录页历史/统计图标审查

日期：2026-09-09；DR-122。

历史使用 BTIcon.clockHistory，统计使用 BTIcon.chartBar；共用原 btCallout / medium / 选中绿色与未选中次级色，图文间距4pt。可选 systemImage 默认为nil，其他分段入口继续显示纯文字。

## 功能验证
- make -f scripts/Makefile build SIM_DEVICE=QiuJi-Onboarding-Pro：exit 0，BUILD SUCCEEDED。xcpretty 缺失后 Makefile 自动使用原始构建输出，见 output/history-tab-icons/build.log。
- iOS26.2 标准 iPhone 模拟器：实际点击记录→统计→历史；页面与选中状态切换正常，按钮无障碍标签仍为历史/统计。
- diff检查通过。纯图标变更，无新增逻辑测试。

## 视觉审查
- 当前执行者切换 UI Reviewer，已目视完整浅色/深色历史与统计截图：图标在文字左侧，字号与颜色一致，未见标题错位、截断或与Pro角标重叠。共享训练分段保持纯文字。
- 证据：output/history-tab-icons/before.png、after-history.png、after-statistics.png、after-history-dark.png、after-statistics-dark.png。
- 改前来自已运行诊断模拟器，改后使用独立标准手机避免覆盖诊断安装；日期/字号/外观一致，记录数据不同，故仅用于页签局部对比，不声明整页数据对比。
- 范围：标准手机默认large字号；小屏/iPad/真机/完整VoiceOver未验证。模拟器外观已恢复浅色。
