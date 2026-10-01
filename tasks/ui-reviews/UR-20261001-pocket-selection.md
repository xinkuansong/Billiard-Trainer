# UR-20261001：袋口选择、推荐与反馈

范围：Daily、普通自由击球、共享PositionPlay/试打进袋辅助。真源：tasks/POCKET-SELECTION-UX-20261001.md r2 / DR-345 r3。当前状态：实施完成，三类设备模拟器验收通过；最新方向连续性18项及小屏实际点击交叉复验通过。

## 用户可见结果

点击立即提交意图与模式，固定等1秒后显示既有黄色0.6秒，再恢复当前主题原皮革。重复同袋确认这次点击，原输入不重复求解；新的点击/触摸、拖动、击球、清空、模式与2D/3D切换、退页取消旧反馈。自动初次推荐无触感，接受手动点袋使用系统selection haptic；模拟器不证明真机触感。

黄色只确认收到意图。确定不可直进的点选立即进入临时自由，保留当前方向；重新点可行袋恢复进袋。主动自由偏好不被后续袋口点击抢回。几何不确定保留手动球袋，只预测当前杆；全堵盘面不捏造可行推荐。持续状态复用普通/试打副标题和Daily原44pt标题区，未另加一排压缩球桌。

## 已落实的计算边界

- 同盘候选缓存按完整球位（包含阻挡球）失效，最多8个固定开口/相切候选；不扫描袋角/螺旋搜索或运行完整物理来推荐。
- Daily沿用现行75°舒适档和角度/两段距离联合分数；普通模式沿用可行候选中最近袋排序。手动无舒适档门槛。
- 普通预测只调用当前PlannedShot一次；切自由优先保留最新可见几何预览方向，不能取尚在途的旧球物理预测方向。移除逐球物理重推荐及隐式Bank搜索、后台球袋/打点回写。正常当前杆瞄准补偿与完整物理预测保留，显式复杂求解工具保留。
- 模拟器一轮90个几何候选实测1.161ms（se17-core.log），仅是该盘样例，不作真机性能承诺。
- PredictionCancellation在真实solver入口记录DEBUG调用数；回归断言当前杆预测1、物理重推荐0、Bank搜索0，而非把耗时估计写成性能提升。
- 球/袋/模式事务合并请求；替换整盘球形重新推荐，即使旧球键仍存在。Daily/普通undo与录制预览保存完整选择快照；PlannedShot可选selectionContext保存偏好、来源、请求球袋与临时原因，旧JSON缺省nil仍可解码。

## 验证记录

所有构建/测试经make -f scripts/Makefile test，-jobs 2、-parallel-testing-enabled NO、-enableCodeCoverage NO，使用本轮自建UDID与独立日志；单元与UI串行。

| 设备 / Runtime | 验证 | 结果 / 日志 |
|---|---|---|
| iPhone 17 Pro / iOS 26.3.1 | 状态、贴库、力度、相机、材质核心 | 61项通过；build/pocket-selection-20261001/core-final-r2.log |
| iPhone SE 3 / iOS 17.0 | 含JSON选择上下文的核心回归 | 63项通过；build/pocket-selection-20261001/se17-core.log |
| iPhone 17 Pro / iOS 26.3.1 | 最终默认确认事件、JSON、时序像素 | 13项通过；build/pocket-selection-20261001/ready-core.log |
| iPhone 17 Pro / iOS 26.3.1 | 真正坐标点击普通击球+Daily，不可进→自由→可进恢复、重复同袋、2D/3D；试打往返；①②教学角色 | 3项通过；build/pocket-selection-20261001/native-ready.log |
| iPhone SE 3 / iOS 17.0 | 最新方向连续性、选择偏好、JSON及时序像素 | 18项通过；build/pocket-selection-20261001/final-state.log |
| iPhone SE 3 / iOS 17.0 | 同一原生点击流 / 小屏标题 | 1项通过（含普通/Daily两入口，归一化点击与最新源码）；build/pocket-selection-20261001/se17-ready-ui.log |
| iPad Pro 11 / iOS 26.3.1 | 同一原生点击流 / 平板标题 | 1项通过；build/pocket-selection-20261001/ipad26-ui-r2.log |

首轮core.log中贴库64例误拒及旧层级/旧行为断言失败已保留；FL-096记录根因与修复。加入圆角鼻尖候选后原64例物理进袋断言全部保留并通过（RAIL_REGRESSION physicalPots=64 geometryAccepted=64），没有改物理引擎或袋口资产来迁就推荐。刻意改变的旧“不可进保持进袋/旧袋”断言更新为用户授权的新行为。

时序使用真正SCNRenderer像素，而不是只看计时常数：动作开始后0.99秒与基线像素一致；1.12和1.59秒仍有黄色；1.61秒恢复且无剩余动作。普通/移动渲染分别覆盖2D和3D四种组合，语义target一直保留。原生UI使用DEBUG只读SceneKit投影/材质探针定位真实屏幕点，未直接调用VM替代用户点击。

## 截图审查

- output/pocket-selection-20261001/native-ready：16张PNG及对应AX记录，包含普通/Daily四种状态、试打2D/3D往返、教学角色不同袋/同袋/清除。
- output/pocket-selection-20261001/rendered-26：16张真实SceneKit before/waiting/peak/restored截图（两渲染配置×两视角）。已检查原色、黄色、恢复与自然透视。
- 小屏iOS17原生8张PNG及AX在output/pocket-selection-20261001/se17-ready，已核对普通与Daily标题持续状态、小屏2D/3D和原皮革恢复。
- iPad原生8张PNG及AX在output/pocket-selection-20261001/ipad26-r2；当前系统使用缩放浮窗。首轮测试把本地投影直接加AX原点而误点，失败日志保留；归一化本地坐标到实际viewport后，同一断言/实际点击通过，没有改生产选袋或删断言。浮窗系统左上控件对既有页标题的局部遮挡保留为全局窗口布局问题，不宣称多窗口布局全部合格。
- 已目视普通自由、恢复进袋副标题，Daily自由说明、持续球袋标题及①绿②青同袋角色。文字复用原区域，球桌取景与尺寸保持既有布局。3D观察取景沿用当前独立相机实现，不把其既有覆盖问题纳入本轮视觉通过声明。

## 边界

本轮证明模拟器状态、真实点击、实际渲染及编解码兼容。真机手遮挡、触感、功耗/耗时改善百分比未测；未提交、推送或发布。不是全App全量QA，也没有将旧日志或旧截图当作本轮断言。64张通过轮次截图的尺寸/哈希清单：build/pocket-selection-20261001/evidence-manifest.json；最终14个相关源码/测试文件指纹：tested-source.sha256。日志按设备和轮次分开，最新iOS17的18项核心与1项UI在final-state.log和se17-ready-ui.log；其他通过轮次的源码时刻见表，未将不同轮次合算为独立用例总数。新增写盘登记及历史截图/路由门禁通过（write-surface-gate.log）；完整verify-gate通过（verify-gate.log），文档体积门禁及git diff --check通过。三台专用设备已清理（simulator-cleanup.json），日志与图片保留。
