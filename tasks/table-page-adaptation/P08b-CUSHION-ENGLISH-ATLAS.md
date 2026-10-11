# P08b 加塞吃库图谱 · r01

2026-10-08。用户指定：“下面进行加塞吃库图谱的吧，左边文字标注也只保留切角，继续吧”。继承P08a共同布局，r01已实施并完成本轮原生验证，待体验。

## 当前契约

| 能力 | 接入与业务差异 |
|---|---|
| 舞台、安全区、背景、球库、状态 | 直接用BTTeachingTablePage/DailyLayoutMetrics、常驻地毯、15数字槽、真实时间电量FPS；手机横屏、iPad横竖；母球不可撤 |
| 标题与左列 | 两行13pt semibold“加塞吃库／图谱”；左侧仅切角读数，八档左右塞紧凑全显无滚动，数量在列表下方 |
| 相机 | TeachingTableHost接入每日生产CameraRig和四按钮；调速/改高低杆/开关轨迹不抢相机；选球袋更新相机上下文；临时俯视刷新与恢复 |
| 杆速与高低杆 | 保留ShotTuning量程；右侧共用BTShotInstrumentColumn；大盘用每日BTSceneSpinPadOverlay及DailyLayoutMetrics.SpinPad，锁定左右塞，仅选择高低杆；八档横向塞量仍按该高度的打滑圆弦长计算 |
| 设置 | 同源深色菜单的2D/3D和台面网格；原教学说明收纳到菜单。本页原无透明度偏好/瞄准模式/特写，不新增独立偏好，八档仍负责轨迹显隐 |
| 线角 | 保留原进球线/瞄准线与假想球，接入已验证共享角弧和角度数值，不显示线名；使用各渲染层实际投影 |
| 物理与摆球 | 原八路simulateFree、挤偏补偿、碰前/首库后切片、去抖代次、色序及至少一档规则不变；点/拖球库、台面拖球、选球选袋保留 |
| 不适用 | 无击球/重打/回放/开球/规则成绩生命周期；不移植每日专属玩法 |

对应DC01–06/08–09/12–14/18/22–25/27–28适用；DC10保留竖轴锁定差异；DC07/11/15–17/19–21/26按上表业务范围处理。世界坐标X–Z台面、Y上、米，屏幕及安全区pt；只使用现有Foundation与几何真源。

## 源码与证据

- 页面/VM：CushionEnglishAtlasView、CushionEnglishAtlasViewModel；共同层BTTeachingTablePage、TeachingTableHost；打点组件BTSceneSpinPadOverlay。
- 改前源码/hash及原生图：output/table-page-adaptation/P08b/r01/before。原页面为竖屏旧布局，和新版横屏不作同尺寸像素等价比较。
- 改前UI采集在44pt与43.99999999999994直接比较时失败，截图及原日志保留；这是原测试浮点断言问题，不把before标成完整通过。新版共用紧凑八档契约与数值精度边界，不继续使用旧44pt行高断言。

## DoD / 当前下一步

- [x] 盘点真实能力并保存before/source身份
- [x] 接入共用布局、相机，左列切角，保留高低杆与物理
- [x] 构建与24项物理/相机/轨迹定向单测通过（final/unit）
- [x] 手机/SE/iPad横竖、打点/八档/相机/摆球原生UI，共用页回归，共6次执行
- [x] 原图目视、图册、gate/doc-size/diff检查与文档交付

构建成功，24项定向单测与6次原生UI执行通过；标准手机、SE、iPad横竖屏覆盖本页八档/高低杆盘/四视角/临时俯视/摆球/网格，P08a、AD01及每日四向打点/回中/防穿透回归通过。生产App二进制在build-r2/r3之间hash一致，r3仅刷新每日旧测试入口。

原图已目视；证据与图册：output/table-page-adaptation/P08b/r01/，最终矩阵final/matrix.json、源码身份identity-r3.json；历史失败保留。未改Figma、未安装真机、未提交或push；唯一下一步：交付r01供用户体验，其他页不扩展。
