# W12 — 自由走位编辑与3D观看验收

状态：✅ 2026-09-13 本地批次验收；不代表全部v63完成。

真源：问题集合_v63.md §8 W12，按页面实际已有能力核对。

| 范围 | 证据 |
|---|---|
| 2D/3D入口与观察 | DR-256复用试打页面已有布局、ShotPlayCamera，composer/tryout标识分域；SE改名/观察往返44.755s及4张原图通过 |
| 摆球、选球、移除 | iPad新摆9号→选中→3D→2D保留球形/目标；DR-257按手指松开点接收球库，iPad35.252s/SE34.395s，原图均确认9号移除且其他球保留 |
| 当前草稿与参数 | ShotSimulationCameraTests.testViewSwitchAndOrbitPreserveShotAndBoard，实际拖动编辑、选球/选袋、速度/打点设置后3次观察往返，位置/预测/方向/选择保持，14.080s通过 |
| 重命名 | 实页保存名称，往返与击球重打后重新打开命名框回读一致。仅当前内存名称，源码renameSequence不写持久库，不宣称跨启动保存 |
| 击球、重打 | 标准58.030s、iPad59.173s完整操作通过，观察/停稳/重打/返回原图已核，恢复击球前球形与视角 |
| 清空、取消/确认重来、返回 | iPad生命周期r2/session7665终态0，54.391s；取消后空桌、确认后三颗默认球恢复，原图5A822C39/31E8FF60已核；紧凑r1/session82094终态0，52.650s，确认重来原图87745BAC已核 |
| 目标区与录制 | 页面没有目标区编辑或startRecording/stopRecording调用。模型录制另用真实SCNView一杆及3次往返比较完整排序JSON，recorded-draft-r2为14.775s；不把模型能力冒充页面入口 |

变更：PositionPlayComposerView共用3D入口；AngleSceneView的外部放下终点使用手指位置，台面拖球偏移保留。未修改击球规则或新增编辑功能。

失败证据保留：旧球库测试自动化绿但图上移除错误球；r2/r3偏移侵蚀球库命中；iPad确认弹窗无取消按钮导致生命周期r1失败，已按实际PopoverDismissRegion取消。详W12-working.md。

验证边界：drop-fix-gate/session10282终态0、diff/doc-size通过；真机手势、完整辅助功能/平台矩阵仍属于W16，其他共享球库消费页随后续批次验证。全目标仍未完成。

DR-258复验：compact-edit-lifecycle-r2/session71463终态0，52.481s，空桌—°断言通过；3D/2D空桌原图98F42AF6/93508879与默认球形62687135均已查看。edit-lifecycle-gate/session4966终态0。本次仅清除派生角度读数，无新增物理行为。
