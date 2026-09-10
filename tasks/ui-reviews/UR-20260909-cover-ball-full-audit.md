# 中八计划与练习封面：48张逐图检查

日期：2026-09-09。当前角色：UI Reviewer。范围：12张官方计划、36张练习入口；不含12张自定义计划模板、动作库教学图和运行时3D球。检查现用Asset Catalog，不把前轮4张候选当作已安装修复。

## 结果

|处置分组|数量|含义|
|---|---:|---|
|修正|19|可见缺号、不可确认的球身份、裁切或母球异常，进入修正清单|
|复核|18|号码失焦、尺度跨度、红点质感或角标安全区需要进一步处理；不等同已确认错色|
|保留|11|本轮未发现明确的球号/球色硬问题；不等同全设备视觉验收通过|

- 16张至少有32颗目标球没有可辨认的号码面（可见面观察，不断言背面没有号码）。
- 明确边界裁切：拍照建球形的蓝2、防守的右缘红球、关键球原理的母球。
- 重点母球异常：风险报酬决策矩阵的红点过密/中央额外淡红斑；球团管理红点布局也需核对。多个近景存在凹陷/凸起印刷感。
- 浅谈球感远球的号形疑似8，但失焦，不能确证为“橙色8”；它仍不能作为合格球面，需重明确身份。
- 没有把模糊数字猜成正确，也没有将暖光下的黄1直接定为橙5。可读数字中未确认传统配色对调。
- 基本功封面的红白花11可辨且正确；其后绿球太虚、侧向，无法确认6/14。其余多数封面仅用全色球，不应为了“有花色”擅自增球。

## 统一检查标准

1黄、2蓝、3红、4紫、5橙、6绿、7栗红；8黑；9–15为白底对应黄/蓝/红/紫/橙/绿/栗红色带。母球白色六点红、无号码。采用本会话锁定的传统中八配色。

球径制作约束为项目57.15mm。单张生成图没有相机/深度真值，不能据像素大小断言真实尺寸错误；同平面俯拍尤其不应出现随意大小球。侧视近大远小保留，但整体卡片主体尺度需要统一。

只看到3或4个红点不代表总数错误；黑球上母球的红白倒影不等于黑球多了红点。所有图中母球可见面均未发现号码；背面与准确六点空间分布无法全部由单张图验证。

## 证据边界

48张均已单独打开原图目视检查；报告按图列出球组、号码颜色、比例/材质和构图。manifest.json记录逐图SHA256，originals保留本轮48张证据快照。不是OCR自动验收，也没有对未知号强行补结论。

角标项为根据原图位置和既有用户截图标记的风险，尚未逐张叠加真实PRO/编号渲染；没有新跑48张App截图/真机/iPad。现有全图缩略拼图只作整套尺度观察。代码整图缩放，不会单独改变球大小或数字。

本轮仅检查，不改正式图片、不生成新候选、不构建。全部问题暂按视觉/内容P2记录，不作功能阻断判断。建议优先处理19张修正项，再处理18张复核项；不要重做11张没有明确硬问题的图。

## 逐图记录

### 01 准度Ⅰ·近中台 — 复核

- 资源：`coverPlanAccuracy`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanAccuracy.png)
- 球组：母球+黑8+远黄1+远绿（似6，模糊）。
- 号码/颜色/花色：黑8正确；黄1偏橙暖，绿号须清晰化。
- 母球/球径/材质：母球无号，红点有凹凸/高光感；近远尺度差大但非物理错误证明。
- 构图与处理：右上远球接近角标区域。

### 02 准度Ⅲ·带塞 — 修正

- 资源：`coverPlanAccuracy3`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanAccuracy3.png)
- 球组：母球+黑8+黄/蓝/红无可见号。
- 号码/颜色/花色：三颗彩球均无可见号码面；应锁定1/2/3。
- 母球/球径/材质：球径组内接近，主体整体偏小。
- 构图与处理：前轮四样板之一，现用仍原图。

### 03 特殊球 — 修正

- 资源：`coverPlanAdvanced`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanAdvanced.png)
- 球组：母球+黑8+蓝2+无号黄球。
- 号码/颜色/花色：8/2正确；黄球须露1号面并校正偏橙。
- 母球/球径/材质：大小随纵深渐变；母球三红点可见。
- 构图与处理：黑8前景易读。

### 04 基本功 — 复核

- 资源：`coverPlanBeginner`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanBeginner.png)
- 球组：母球+红白花11+黑8+模糊绿球。
- 号码/颜色/花色：11红花/8黑正确；绿球侧面号不可确认。
- 母球/球径/材质：母球4个红点可见不等于总数错误；后球失焦。
- 构图与处理：保留白底；绿球需明确6或14及相应花色。

### 05 杆法Ⅰ·高低杆 — 复核

- 资源：`coverPlanCueball`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanCueball.png)
- 球组：母球+远黄球（似1）。
- 号码/颜色/花色：号码圆存在但失焦；不可当已核准数字。
- 母球/球径/材质：母球微距，近远尺度跨度大，顶部红点似凹陷；杆头贴近球。
- 构图与处理：应优化景深/球面标记。

### 06 杆法Ⅱ·加塞挤偏 — 复核

- 资源：`coverPlanEnglish`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanEnglish.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8正确但较虚。
- 母球/球径/材质：母球微距，杆头贴球；近远差不直接定错。
- 构图与处理：保留摄影深度，复核缩略图。

### 07 力度 — 复核

- 资源：`coverPlanForce`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanForce.png)
- 球组：母球+黄1+黑8。
- 号码/颜色/花色：1/8正确。
- 母球/球径/材质：纵深很长，远8很小；母球红点需统一平面印刷感。
- 构图与处理：黑8处右上角标风险。

### 08 全能精选 — 复核

- 资源：`coverPlanFullskill`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanFullskill.png)
- 球组：母球+黑8/红3/黄1/蓝2/紫4/绿6。
- 号码/颜色/花色：六颗号码与全色正确，远端6/4较虚。
- 母球/球径/材质：母球明显大于紧邻黑8，需降低夸张近景；不能仅凭图确认物理直径。
- 构图与处理：可用作完整全色配色参考，勿误报缺号。

### 09 准度Ⅱ·远台切角 — 复核

- 资源：`coverPlanIntermediate`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanIntermediate.png)
- 球组：母球+模糊黑球+远黄球。
- 号码/颜色/花色：黑球号似8但不能确证；黄球不可辨号。
- 母球/球径/材质：强浅景深，主球与远球尺度落差大。
- 构图与处理：两颗目标球需提高可读性。

### 10 走位Ⅰ·短距到一库 — 复核

- 资源：`coverPlanPositioning`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanPositioning.png)
- 球组：母球+黄1+黑8。
- 号码/颜色/花色：1/8正确，8较虚。
- 母球/球径/材质：近远缩放趋势合理；红点印刷质感需统一。
- 构图与处理：右上8被PRO遮挡风险，用户截图已显示。

### 11 走位Ⅱ·多库与蛇彩 — 修正

- 资源：`coverPlanPositioning2`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanPositioning2.png)
- 球组：母球+黄/绿/紫/红四球。
- 号码/颜色/花色：四颗无可见号码面；应明确1/6/4/3。
- 母球/球径/材质：近远差存在但不能全判物理错误。
- 构图与处理：前轮有候选，原图仍在用。

### 12 分离角 — 修正

- 资源：`coverPlanSeparation`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPlanSeparation.png)
- 球组：母球+黑8+黄/红球。
- 号码/颜色/花色：黄红无可见号；应锁定1/3。
- 母球/球径/材质：俯拍彩球显著小于白黑，须统一。
- 构图与处理：前轮有v4候选，原图仍在用。

### 13 瞄准点训练 — 保留

- 资源：`coverPracticeAimPoint`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeAimPoint.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8清晰正确。
- 母球/球径/材质：两球直径视觉接近；黑球侧面红白影像为母球反射，不算错色/多号码。
- 构图与处理：主球特写较其他模板大，属构图层问题。

### 14 2D 瞄准点训练 — 保留

- 资源：`coverPracticeAimPoint2D`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeAimPoint2D.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8正确；母球无号。
- 母球/球径/材质：两球大小接近，红点3个可见。
- 构图与处理：主体偏小，若统一近景可整体放大。

### 15 3D 瞄准点训练 — 复核

- 资源：`coverPracticeAimPoint3D`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeAimPoint3D.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8清楚正确。
- 母球/球径/材质：微距母球偏大；顶部红点似凹面；杆头接近球不据此判穿模。
- 构图与处理：黑8处上方，需查角标覆盖。

### 16 瞄准修正 — 修正

- 资源：`coverPracticeAimingCorrection`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeAimingCorrection.png)
- 球组：母球+无号红球。
- 号码/颜色/花色：红球无可见号；按中八应明确红3。
- 母球/球径/材质：红球失焦，母球红点凹面感。
- 构图与处理：补号同时适度增加景深。

### 17 瞄准方法 — 复核

- 资源：`coverPracticeAimingMethods`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeAimingMethods.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8正确。
- 母球/球径/材质：母球约为后8近两倍，属强微距；顶部红点高光似凹面。
- 构图与处理：号码可读，优化材质和比例。

### 18 瞄准原理 — 保留

- 资源：`coverPracticeAimingPrinciple`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeAimingPrinciple.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8清楚正确。
- 母球/球径/材质：母球略大、透视趋势合理；黑8号面偏侧但可读。
- 构图与处理：号码/球色未见明确错误。

### 19 角度与瞄准 — 保留

- 资源：`coverPracticeAngleDynamic`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeAngleDynamic.png)
- 球组：母球+黄1+黑8。
- 号码/颜色/花色：1/8正确。
- 母球/球径/材质：三球大小接近；号码面清晰。
- 构图与处理：灰底主体偏下，无明显边缘遮挡。

### 20 拍照建球形 — 修正

- 资源：`coverPracticeBallExtraction`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeBallExtraction.png)
- 球组：母球+黄1/蓝2/红3/黑8。
- 号码/颜色/花色：四号配色正确。
- 母球/球径/材质：球径接近；蓝2被左边界截掉一部分。
- 构图与处理：应移入安全区；右上黑8需看角标。

### 21 浅谈球感 — 修正

- 资源：`coverPracticeBallFeel`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeBallFeel.png)
- 球组：母球+远橙黄球。
- 号码/颜色/花色：远球号码疑似8但失焦，不能确证；无可见花带。
- 母球/球径/材质：若8为错色；若1应黄、若5应橙，必须重明确身份。
- 构图与处理：右上球模糊且在角标附近。

### 22 翻袋解球器 — 保留

- 资源：`coverPracticeBankShot`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeBankShot.png)
- 球组：母球+红3。
- 号码/颜色/花色：3红正确，号清晰。
- 母球/球径/材质：大小变化较温和，三红点可见；球杆无明显穿球。
- 构图与处理：球桌/杆为主题，不要求球占满。

### 23 自由走位 — 保留

- 资源：`coverPracticeComposer`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeComposer.png)
- 球组：母球+黄1/蓝2/红3/黑8。
- 号码/颜色/花色：四号配色正确。
- 母球/球径/材质：球径小且接近，号面偏下但完整。
- 构图与处理：小卡球号偏小，可整体调整构图。

### 24 瞄准点对照表 — 复核

- 资源：`coverPracticeContactPoint`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeContactPoint.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8正确但略糊。
- 母球/球径/材质：两球大小接近；母球偏黄、红点高光凹凸感。
- 构图与处理：提高号码清晰度及印刷质感。

### 25 加塞吃库图谱 — 修正

- 资源：`coverPracticeCushionEnglish`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeCushionEnglish.png)
- 球组：母球+无号黄球。
- 号码/颜色/花色：远黄球无可见号。
- 母球/球径/材质：母球贴库关系可见，远球失焦。
- 构图与处理：黄球靠上沿/编号区，补号并移出安全区。

### 26 反射解球器 — 修正

- 资源：`coverPracticeDiamond`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeDiamond.png)
- 球组：母球+黑8+无号黄球。
- 号码/颜色/花色：8正确；黄球无可见号。
- 母球/球径/材质：局部大范围球桌，主体球很小。
- 构图与处理：黄球补1；远景类别保留但小卡可读性弱。

### 27 清台 5 步决策流程 — 修正

- 资源：`coverPracticeFlow`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeFlow.png)
- 球组：母球+红/黄橙/蓝/紫+黑8。
- 号码/颜色/花色：四彩球无可见号；明确3/1或5/2/4。
- 母球/球径/材质：球列近远渐变，不能直接判直径错。
- 构图与处理：将黄1与橙5身份钉死，不凭色温随意编号。

### 28 自由击球 — 复核

- 资源：`coverPracticeFreePlay`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeFreePlay.png)
- 球组：母球+黄1/红3/紫4/黑8/远绿（似6）。
- 号码/颜色/花色：近端1/3/4/8可辨；远绿号无法可靠确认。
- 母球/球径/材质：母球更大、景深强；远绿未见花带。
- 构图与处理：杆端黑套形态与常见白先角不同，器材外观复核。

### 29 角度预测 — 保留

- 资源：`coverPracticeGeometricQuiz`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeGeometricQuiz.png)
- 球组：母球+黄1+黑8。
- 号码/颜色/花色：1/8正确。
- 母球/球径/材质：俯拍三球接近等大；母球黄斑可能为黄球反射，不定为错误印刷。
- 构图与处理：号码可读，母球反射可弱化。

### 30 打一走二想三 — 修正

- 资源：`coverPracticePlanThree`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticePlanThree.png)
- 球组：母球+红/黄/紫+远黑8。
- 号码/颜色/花色：三彩球无可见号；应明确3/1/4，远8模糊。
- 母球/球径/材质：母球与红球近景大，后球梯度收缩。
- 构图与处理：补号码，远8改善清晰度。

### 31 清台速查手册 — 保留

- 资源：`coverPracticeQuickRef`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeQuickRef.png)
- 球组：母球+黄1/红3/黑8。
- 号码/颜色/花色：三号配色正确且清晰。
- 母球/球径/材质：球径差较小，母球与后球透视可解释。
- 构图与处理：黄球偏暖但与黄1身份一致。

### 32 2D 角度训练 — 保留

- 资源：`coverPracticeSceneAiming2D`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeSceneAiming2D.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8正确。
- 母球/球径/材质：俯拍大小接近，号面在球下缘较侧向。
- 构图与处理：无需新增球号；小卡旋正号码面可优化。

### 33 3D 角度训练 — 复核

- 资源：`coverPracticeSceneAiming3D`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeSceneAiming3D.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8清晰正确。
- 母球/球径/材质：近母球比黑球大，顶部红点凹面感；杆端皮头不清。
- 构图与处理：统一母球印刷和镜头尺度。

### 34 分离角图谱 — 复核

- 资源：`coverPracticeSeparationAtlas`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeSeparationAtlas.png)
- 球组：母球+黄1+黑8。
- 号码/颜色/花色：1/8正确。
- 母球/球径/材质：黄球略小于下方两球，俯拍需收敛；白黑接近等大。
- 构图与处理：右上黄1处角标风险。

### 35 分离角与走位 — 修正

- 资源：`coverPracticeShotSim`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeShotSim.png)
- 球组：母球+黑8+无号黄球。
- 号码/颜色/花色：8正确；黄球无可见号。
- 母球/球径/材质：前白黑大小接近、接触关系清楚，黑球红点为反射。
- 构图与处理：补黄1号面，保持前景两球。

### 36 防守 — 修正

- 资源：`coverPracticeSnooker`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeSnooker.png)
- 球组：母球+黑8+无号蓝球+右缘无号红球。
- 号码/颜色/花色：蓝球应明确2、红球明确3；8正确。
- 母球/球径/材质：前景三球近似同径，后红球被右边界裁切。
- 构图与处理：Snooker为做球障碍语义，不能按斯诺克无号球豁免。

### 37 思路训练 — 修正

- 资源：`coverPracticeSolver`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeSolver.png)
- 球组：母球+黑8+无号黄/红球。
- 号码/颜色/花色：黄红无可见号，应明确1/3。
- 母球/球径/材质：母球偏大，透视待优化。
- 构图与处理：前轮已有候选，当前资源仍原图。

### 38 旋转与加塞 — 复核

- 资源：`coverPracticeSpinAndEnglish`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeSpinAndEnglish.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8正确但失焦。
- 母球/球径/材质：母球巨大微距，红点明显凹面感。
- 构图与处理：号码可读性与主球尺度需统一。

### 39 30° 法则 — 保留

- 资源：`coverPracticeT01`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT01.png)
- 球组：母球+黄1+黑8。
- 号码/颜色/花色：1/8正确。
- 母球/球径/材质：三球接近同径，白黑近接；母球顶部红点有高光。
- 构图与处理：原图号面可读。

### 40 90° 法则 — 修正

- 资源：`coverPracticeT02`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT02.png)
- 球组：母球+黑8+无号黄/蓝球。
- 号码/颜色/花色：黄蓝无可见号，应明确1/2。
- 母球/球径/材质：俯拍球径相近但整体很小。
- 构图与处理：黄球靠左上编号区域，补号与构图一起修。

### 41 切线法则 — 保留

- 资源：`coverPracticeT03`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT03.png)
- 球组：母球+黑8。
- 号码/颜色/花色：8正确。
- 母球/球径/材质：白黑接近等大，母球4个红点可见不据此定总数错。
- 构图与处理：无明显缺号。

### 42 母球速度分级 — 修正

- 资源：`coverPracticeT04`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT04.png)
- 球组：母球+黄/蓝/红。
- 号码/颜色/花色：三球无可见号，应明确1/2/3。
- 母球/球径/材质：母球与最远红球尺度跨度很大。
- 构图与处理：后球过小，需同时改主体比例。

### 43 反向规划 — 复核

- 资源：`coverPracticeT05`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT05.png)
- 球组：母球+黄1+黑8。
- 号码/颜色/花色：1/8正确。
- 母球/球径/材质：母球较大、8较虚；杆端白色圆面外观可疑但非球号问题。
- 构图与处理：上方8与左编号安全区需复核。

### 44 关键球原理 — 修正

- 资源：`coverPracticeT06`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT06.png)
- 球组：母球+无号黄球+黑8。
- 号码/颜色/花色：8正确；黄球无可见号。
- 母球/球径/材质：主角黄球清楚但缺号；母球失焦且被下边缘裁切。
- 构图与处理：补1并修构图，不能仅补字。

### 45 球团管理 — 复核

- 资源：`coverPracticeT07`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT07.png)
- 球组：母球+黄1/蓝2/红3/黑8。
- 号码/颜色/花色：四号配色正确。
- 母球/球径/材质：五球大小接近；母球可见红点多且分布需核对六点参考。
- 构图与处理：检查红点是否过密，不强行从遮挡面数总数。

### 46 风险报酬决策矩阵 — 修正

- 资源：`coverPracticeT08`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT08.png)
- 球组：母球+蓝2/红3/黑8。
- 号码/颜色/花色：三号配色正确。
- 母球/球径/材质：母球可见红点分布异常密集，并有中央淡红额外斑；球体很小。
- 构图与处理：重点重做母球六点布局，避免把高光当成新红点。

### 47 最少加塞原则 — 修正

- 资源：`coverPracticeT09`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT09.png)
- 球组：母球+无号远红球。
- 号码/颜色/花色：红球无可见号，应明确3。
- 母球/球径/材质：红球重度失焦，母球红点凹凸感。
- 构图与处理：右上红球靠角标区，补号/景深/位置。

### 48 安全球三维度模型 — 复核

- 资源：`coverPracticeT10`；[原图快照](/Users/song/projects/13.billiard_trainer/output/cover-ball-audit-20260909/originals/coverPracticeT10.png)
- 球组：母球+红3/黑8/远黄1。
- 号码/颜色/花色：三个号码与颜色正确。
- 母球/球径/材质：前景红黑大小相近；母球被遮挡属场景关系，不算缺球；黄1较虚。
- 构图与处理：右上黄1需查PRO覆盖。
