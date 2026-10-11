# P08b 加塞吃库图谱 · r01

范围见[页面卡](../table-page-adaptation/P08b-CUSHION-ENGLISH-ATLAS.md)。用户要求沿共同模板继续本页，左侧文字只留切角。

## 实施与业务保留

直接使用BTTeachingTablePage/TeachingTableHost，而非复制旧页外观；左列切角→八档→数量，球库15数字槽置顶，深色设置和四相机同源。标题两行13pt“加塞吃库／图谱”。右侧仍可选高低杆：共用每日固定大盘，侧塞锁定，左侧八档按当前高度计算横向打滑弦。未改物理、挤偏补偿、色序、库后切片、去抖及代次丢弃。台面沿用共同角弧/数字/进球线，不显示线名。原教学说明收进设置。

## 失败留存与修复

- before采集旧页面时，旧44pt严格比较因43.99999999999994失败，原生2D/3D图片和日志保留；不是新版回归结论。
- 首构建及24单测通过；首轮UI在固定盘隐藏左右键的AX存在断言失败。旧fixedContent用opacity/allowsHitTesting/accessibilityHidden装饰按键，在当前原生AX树仍暴露；改为锁侧塞时不构建按键、仅保留相同44pt占位，未移除断言。默认不锁侧塞消费者仍构建原方向键。
- 证据：output/table-page-adaptation/P08b/r01/before、checks及原始xcresult/录屏保留；第二轮构建为build-r2；build-r3仅重编测试，App二进制hash未变化，最终矩阵在final，不覆盖首次失败。

- 共用页回归中P08a/AD01通过，每日旧测试仍直接查找页外的cameraMode，未打开C56菜单而失败。只更新该测试的模式/透明度入口为当前原生菜单，不改生产行为或减少四向打点、回中和防穿透断言；原shared.xcresult保留，复测shared-r2。

## 当前状态

构建成功，24项定向单测与6次原生UI执行通过；标准手机、SE、iPad横竖屏覆盖本页八档/高低杆盘/四视角/临时俯视/摆球/网格，P08a、AD01及每日四向打点/回中/防穿透回归通过。生产App二进制在build-r2/r3之间hash一致，r3仅刷新每日旧测试入口。

原图检查：标准手机/SE的八档和底部数量完整、仅切角读数；展开高低杆盘不含左右键、在2D桌内；浅色系统设置仍为深色。iPad横竖的2D/3D与临时俯视图、角度数字可见，球库/左列/右侧工具未裁切。每日默认盘四方向键保留，AD01/P08a原图对照未见新增偏差。

[原生图册](../../output/table-page-adaptation/P08b/r01/index.html)；最终matrix.json为24单测/6次UI的通过证据，matrix-initial.json记录首次共用回归失败。gate/doc-size/diff通过。未装真机、未改Figma、未提交/push或发布；待本轮体验，不把模拟器验证当成真机认可。
