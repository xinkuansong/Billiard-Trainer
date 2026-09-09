# 学习剩余批次独立视觉审查

2026-09-08，UI Reviewer。已读取57规则、swiftui-design-system技能、Colors/Typography/Spacing及docs/05参考。实际使用 view_image 逐张打开9张原始PNG（1206×2622，工具显示缩至942×2048）；没有操作App、运行测试、修改测试或共享台账。按主控授权仅写本文件。

## 证据与外观范围

来源为 snapshot004、scheme QiuJi、专用UDID CB246F30-E917-492B-B0C4-511F473D8C15，两RUN的inputs已核。remainder002的exit.json实际make_exit0、finished 2026-09-08T10:53:17+08:00；主控报告六方法通过，但本文视觉判断来自实际图片，不用绿日志替代。remainder001只审本次指定3图，不替该批失败方法判通过。

图像可见：吃库图谱为黑色工具表面，其他七张为浅色阅读页。本组不是Light/Dark成对矩阵；不能因两种表面都有图便称深色适配完成。标题、返回控件、卡片层级与主要文字均有真实内容，没有整屏空白、错误遮罩或资源占位。未逐控件核实Token调用、44pt命中、Dynamic Type、VoiceOver或对比度数值。

## 逐图记录

### 1. 加塞吃库图谱，隐藏第一条轨迹

- RUN：`formal-004-learning-remainder-001`
- 文件stem：`learning--[LearningTourDiagnosticUITests testLearn07CushionAtlasToggleTrack]-track-hidden-FAC5E968-9B2D-43B4-8B1A-5DCBA924EF09`
- 实际可见：黑色工具表面、完整六袋球桌、30°/力度1.5/中心球/100%可加塞横条可见；左侧第一枚红点图例明显变暗，台面保留其余彩色虚线路径。两排0–15球库清楚，无加载遮罩。
- 边界/观察：顶部已选7/8在屏幕右侧只露一部分；这是横条首视窗观察，未验证横向滚动，不定性不可达。底部说明小且灰，未测对比度。

### 2. 加塞吃库图谱，恢复第一条轨迹

- RUN：`formal-004-learning-remainder-001`
- 文件stem：`learning--[LearningTourDiagnosticUITests testLearn07CushionAtlasToggleTrack]-track-restored-FAC5E968-9B2D-43B4-8B1A-5DCBA924EF09`
- 实际可见：与前图相同盘面、力度和球位置；左上红点图例恢复白底亮态，台面右上新增红色虚线段可辨，顶部已选变为8/8。证明这次图例操作有真实渲染差异。
- 边界/观察：只验证此一条轨迹的显示开关，不证明八条轨迹的物理数值或全部打点/力度组合；右侧计数仍局部露出。

### 3. 浅谈球感，下段训练建议

- RUN：`formal-004-learning-remainder-001`
- 文件stem：`learning--[LearningTourDiagnosticUITests testLearn08BallFeelLowerAdvice]-lower-content-73927E04-55B8-40EF-98E0-FB4D725F68B3`
- 实际可见：白卡内1–5依次为理解原理、几何练习、2D球台、3D视角、实战应用，标题与正文完整换行；下方2D到3D的视角差异和球桌上半部可见。
- 边界/观察：顶部前一节内容被导航渐变模糊、下方球桌超出本截图，符合滚动取样；不据此声称全文已看或后半球桌丢失。

### 4. 瞄准点对照表，下段曲线

- RUN：`formal-004-learning-remainder-002`
- 文件stem：`learning--[LearningTourDiagnosticUITests testLearn09ContactPointSliderAndCurve]-lower-curve-9EB50709-378D-407A-8617-E2027D7C407A`
- 实际可见：表尾40°–90°多列数值清楚，90°行绿色浅底；d/R = 2sin(θ)曲线卡完整，横轴0°–90°、纵轴0–2，金色五点与全球/3⁄4球/半球/1⁄4球/极薄球文字能分辨。
- 边界/观察：表头在视窗上方，不能凭本图认证每列含义；浅灰坐标刻度对比偏弱属于观察。未独立验算曲线或球厚术语。

### 5. 90°法则，下段边界与误区

- RUN：`formal-004-learning-remainder-002`
- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory02NinetyDegreeSliderAndScope]-lower-content-C4BDBAE7-5730-4473-93A7-36D7ACA59408`
- 实际可见：不成立的几处灰卡、三张常见误区浅橙卡及相关页面可见；正文区未见横向裁字，切线法则关联条完整露出。
- 边界/观察：仅下段静态可读性；灰色次级说明较淡，未量测AA对比；未点击相关页面，不证明跳转。

### 6. 切线法则，下段边界与误区

- RUN：`formal-004-learning-remainder-002`
- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory03TangentSliderAndScope]-lower-content-4F2C3AF3-9D3B-40FD-A2A4-D8BA4183E048`
- 实际可见：两个容易混的说法灰卡、三项常见误区均完整，长标题自动换行；相关页面含看切线怎么变成走位、旋转与加塞。
- 边界/观察：导航顶部渐变覆盖前一段正常滚动内容；不将顶部模糊判正文永久不可读。教学中的物理断言未作专家复核。

### 7. 反向规划，下段适用与降级

- RUN：`formal-004-learning-remainder-002`
- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory05BackwardPlanningLowerScope]-lower-content-CF322E6B-D900-4E87-ACF5-485A654C89A2`
- 实际可见：什么时候这样用和什么时候要降级两白卡完整；两颗及以下规划、球团风险等段落可见；下方常见误区露出第一项。
- 边界/观察：此图不包含全部误区；未见正文越过卡片右边界。只验证下段展示，非战略内容正确性认证。

### 8. 关键球原理，下段条件

- RUN：`formal-004-learning-remainder-002`
- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory06KeyBallLowerScope]-lower-content-48818A8A-FAE6-45FB-9270-897D97441AC8`
- 实际可见：上部表格末两行可见，什么时候成立完整白卡含失位后重新评估与三禁忌灰卡；文本完整换行，没有同层叠字。
- 边界/观察：顶部表格列标题不在画面，不根据残表判数据错列；三禁忌字小且偏灰，未量测无障碍。

### 9. 球团管理，下段禁忌与防守价值

- RUN：`formal-004-learning-remainder-002`
- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory07ClustersLowerScope]-lower-content-AB884EA4-3E9E-4751-897F-96641362B74E`
- 实际可见：四禁忌编号1–4完整；什么时候可以松、什么时候别破段落含留作防守资源的说明可读。标题较长但在屏幕宽度内完整显示。
- 边界/观察：最后一段在截图底部继续，不能称全文已审；未见当前可视正文横向裁切。

## 问题裁定与后续边界

本9图未发现足以直接定性的新P0/P1布局或渲染缺陷；这不是所有页面无问题结论。两项保留观察为吃库图谱顶部计数首视窗截断、灰色辅助文字及图轴刻度较淡。前者须结合横向滚动契约/可达证据，后者须独立量测或设备阅读验证，不能仅凭截图编造WCAG失败；本次不新增正式问题编号、不要求修复。

Learn07的两图支持一条轨迹实际隐藏/恢复，与单纯selector值变化不同；不支持真实物理正确性。其他七图支持指定下段内容确已呈现，不支持全文教学、公式、战术或跨设备认证。未审其余entered/returned/teardown图，也未将顶部导航模糊、滚动出屏或画面底部未读完自动当成控件遮挡缺陷。主控可将本9图合入已选方法的视觉证据，功能终态仍以真实RUN日志和断言为准。

## 2026-09-08追加：remainder003（新增6图）

延续同一UI Reviewer规则与边界。RUN为 `formal-004-learning-remainder-003`；本节六图均已实际view_image打开，不以文件存在推定功能通过。先审已落盘五图，主控通知6/6终态make0后补审Theory12，未轮询或操作设备。

### 10. 角度与瞄准：菜单关闭

- 文件stem：`learning--[LearningTourDiagnosticUITests testLearn05MenuDismissesOutsideObservedBoundsAndReturns]-display-menu-dismissed-observed-margin-3662A4C8-0DED-4405-A6FE-FC503FDF10B7`
- 实际可见：更多按钮仍在右上，弹出菜单已不显示；29°、半球、d/R 0.96、横移27.5mm、偏移48%横条以及瞄准线/进球线球桌实际可见，底部球库正常。
- 边界/观察：该图证明采证时菜单处于关闭状态，点击坐标是否正确须结合主控测试/AX证据；本图未拖球，不证明动态几何数值。底部绿色拖动提示偏暗，未量测对比度。

### 11. 风险报酬决策矩阵：下段

- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory08RiskLowerScope]-lower-content-BA51A3A7-92D1-4206-9E37-CE8E38F055C3`
- 实际可见：最后一颗8号球灰色说明、什么时候可以松一点完整白卡、常见误区前两卡均可见；含8球/9球与双方剩余球数分支，文字正常换行。
- 边界/观察：87.5%与10%是实际呈现的教学数字，本次未验证其来源或适用性，不把可读视为正确。

### 12. 最少加塞原则：下段

- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory09MinimumEnglishLowerScope]-lower-content-72DD8236-60CC-4AA8-826F-581C3B936F2F`
- 实际可见：超过半桌重新评估、每次加塞前的四问灰卡，以及什么时候仍要加塞完整显示；30°/90°/切线输入端修正段落可读。
- 边界/观察：正文布局未见横向溢出；灰色四问偏淡，仍仅观察；1%精度和修正主张未作教学认证。

### 13. 安全球三维度模型：下段

- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory10SafetyLowerScope]-lower-content-6B39C0D1-C716-4B57-ACE7-9E735FBF45C5`
- 实际可见：适用条件末段含球种差异/对手水平差/空旷桌面，四条常见误区完整可见，浅橙背景区分明显。
- 边界/观察：页面标题完整，正文和卡片右边界未见裁切；四条误区是否符合全部规则和局面不在本图审范围。

### 14. 清台5步决策流程：下段

- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory11FlowLowerConsequences]-lower-content-6ADEE578-DFD1-43B6-A9C3-EEAC13CC2E40`
- 实际可见：启动/结束说明、跳步会付出什么代价表格完整；五行分别为扫桌、倒推、三问、固定动作、复盘，长结果文案正常换行，下方误区继续。
- 边界/观察：仅审表格显示，未认证每跳一步失败率翻倍的量化说法；画面下端误区未完属于滚动视窗边界。

### 15. 清台速查手册：下段八句

- 文件stem：`learning--[LearningTourDiagnosticUITests testTheory12QuickReferenceLowerLines]-lower-content-B5597AAF-FF6F-4987-A7E0-04ED6C59582D`
- 实际可见：数字速查表末段与“八句能立刻用的话”完整白卡；1–8序号连续，长句第7/8项正常换行且不挤出卡片，下方常见误区第一项继续可见。
- 边界/观察：本图只证明八句确已呈现；约25厘米、31.75厘米、15厘米、87.5%等主张未核独立来源，不作为教学或物理准确性认证。

本追加六图未见明确新P0/P1视觉阻断；菜单已关闭的画面是可用证据，原失败仍保留。理论下段的表格/标题/正文在所审视窗内正常显示；导航渐变后方与底部画面外内容不作永久遮挡推断。至此本文实际图审累计15张（原9+本6），不是15个新增通过测试。
