# B07/B08 接入前代码核查

2026-10-18；仅源代码核查，实施前仍需重读各批完成标准。未启用、未验收。

## B07 规划/求解

- PlanThree、SnookerTactics复用BTTeachingTablePage；BankShot/Diamond通过SolverStageChrome复用同壳。规划工具默认整组planning；自由模式pairedLeftContent为direction，包含原模式入口与回放。不得把自由/求解临时差异当成永久删除能力。
- PlanThree现有busy覆盖计算/击球/开球Runner；需显式纳入落区手势进行中、开球settled确认及父级角色/袋选择和信息层状态。编辑不可调用stopForDismissal。
- Snooker现有busy覆盖计算/击球，目标选择原语义保留。SolverStageChrome已有isSolving/isPlaying传递isAnimating，需覆盖原理浮层并验证微调草稿未被取消。
- 通用宿主已有杆速/打点/相机/临时俯视保护；逐页应核默认/个人的真实模式与动作，不以Silu已通过替代。

## B08 教学

- AngleDynamic没有杆速和打点；左侧是切角/厚度/dR/横移/偏移读数。应采用information组，不与规划按钮组混为同一能力。
- Separation有杆速和禁用打点槽，左侧切角及8档高低杆轨迹选择必须成组保留；并行轨迹计算需传入编辑busy。
- Cushion有杆速和竖向打点控制，左侧塞量/轨迹选择成组保留；计算/持触不能进入编辑。
- 目前BTTeachingTablePage默认leftContent统一标planning，推广前需按语义增加显式组参数；教学参数改变与布局独立。对应模板独立预览需增加真实能力样例，不能给无杆速页面显示可用杆速。

验证位置：AngleDynamicAssistUITests、ATeachingStandardsUITests、S2_ShotPagesLayoutUITests和各规划/求解测试。源代码核查不是运行验证。
