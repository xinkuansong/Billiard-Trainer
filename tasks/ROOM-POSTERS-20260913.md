# 四面墙台球海报 · 2026-09-13

状态：已完成计划/练习卡片原图加独立文字的实现及模拟器复验，待用户视觉反馈；真机未验。

## 当前方向

用户否决纯AI画稿的袋口夹角、缺失球号与老气环境，随后明确改用已有计划和练习卡片图片加文字。旧稿保留在output，不再作为App海报资源。

按用户“多放几张”增加至8幅，每面墙2幅；两张横版保留原烘焙框，六张竖版使用细框。新增X墙海报中心在z=0，Z墙与原画中心间距1.2m，避免杆架与壁灯实体。图片完整按4:3呈现；横版文字在右、竖版在下，原图无重新生成、无改球号、无拉伸。三种房间只改变纸色和框色。

| 墙面主题 | 直接复用资源 | 文字 |
|---|---|---|
| practice | coverPlanFullskill | 每一杆 / 都算数；把练习 / 变成积累 |
| calm | coverPracticeAimingMethods | 稳住 / 再出杆；看清目标 / 做好这一杆 |
| again | coverPracticeBallFeel | 手感，来自重复；再来一次，让动作更熟悉。 |
| next | coverPracticePlanThree | 这一杆，也有下一杆；进球之前，先想好白球停在哪里。 |

| control | coverPracticeSpinAndEnglish | 力量，恰到好处；控制白球，也控制节奏。 |
| enjoy | coverPracticeFreePlay | 热爱，自有回响；认真打好眼前的每一杆。 |
| angle | coverPracticeBankShot | 换个角度，看见可能；多一种思路，多一条路线。 |
| route | coverPracticeDiamond | 心中有数，出杆有度；看清路线，再决定力度。 |

## 原图追溯

- `output/imagegen/cover-prompt-system-v1/20260903/`：已逐文件计数240张，60组各4张；选中四组的候选均1600×1200。index.html为完整图库。
- 最初选定四张卡片PNG均1448×1086，保留后续台呢/球号修正；不能把最初候选冒充当前正式版本。
- 球感、想三杆在`output/cover-number-fix-20260909/generated.json`指向的原始生成PNG与当前Asset Catalog哈希完全相同。
- 海报直接读取Asset Catalog的UIImage；原卡片文件未修改。

## 实现和证据

- `BakedTrainingRoom.makePosters`建立图片Plane、纸色Plane、两段SCNText，保持房间缓存、2D隐藏及四面墙朝内规则。
- 原1.29m横框内衬由1.30×0.65m整幅纸面覆盖，维持2:1外比例，消除露出的旧图白边。
- `card-render`4项测试通过，但实际截图发现文字缺失：SCNText.copy返回string=nil。已显式保留文字/字体属性，并补缓存克隆后文字内容及几何非空断言；最终card-verified四项场景测试通过（0失败），三风格共12张墙面截图已逐张复核。card-build构建、card-gate门禁、card-doc-size文档门禁均通过。
- 此前生成稿corrected-render4场景通过及build通过，仅作为历史证据；不能代替当前卡片方案。
- 未安装手机，未提交；没有赛事袋口精确尺寸认证或真机性能结论。

## 产物

`output/room-posters-20260913/`保留所有候选与日志。旧12张JPEG已移至generated-packaged-candidates，取消正式打包；新的海报无需复制现有卡片图片。

## 八幅版本复验

新增四张直接复用当前卡片PNG。eight-render构建及两项场景/缓存测试通过；12张新增近景（三风格×四张）逐张检查，文字可见、图像完整、画框未遮住壁灯或杆架。eight-gate门禁通过。四墙成对横向视角最终见eight-landscape（2项测试0失败），赛事四墙同框图已检查，无重叠且两幅完整入镜；图库已更新为8幅及四墙搭配入口。真机未验。
