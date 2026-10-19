# B02：固定区域排布与真实宿主

日期：2026-10-18。状态：✅ B02 技术验收完成；正式编辑与持久化消费从 B03 开始。真源：[方案 B02](../TABLE-CONTROL-LAYOUT-PLAN-20261017.md#b02-固定区域排布与两个宿主验证)。

## 实现边界

- `ControlLayoutPlacement` 接收页面逻辑 pt、原 Foundation 左右列及实际控件边界。球桌/投影/尺长不消费个人布局。
- `ControlLayoutHost` 在原生控件上测量与平移，保留 ViewModel、SceneKit 实例、业务闭包和内部控件结构。方向、仪表、主动作、回放、规划工具及相机分别有边界；小屏横排回放测量实际宽度，不能用外层 60pt 包装框代替。
- B02 仅向每日、自由、思路三个身份注入测量上下文，以 DEBUG 环境 `CONTROL_LAYOUT_PROBE` 提供 default/swap/order/offset/invalid 测试意图。尚无正式编辑/保存入口，不将此批说成可用产品闭环。
- 非法非有限值、越界/保护框碰撞和整组容量失败退回整页默认，原意图不写回。默认本身不足仍沿用宿主可返回的空间不足处理。
- 当前尺长仍由默认 Foundation 决定；未证明合法的非默认尺寸档位不能开放。普通组左右交换统一验证两侧；相机按最终仪表位置重算桌缘槽位，再检查碰撞。
- 原生展开锚点跟随实际控件。新增真实控件保护框供瞄准特写避让；相机区分 FreePlay 仅纵向跟随的默认锚点和教学壳嵌套仪表锚点，避免重复位移。

## 已完成证据

- `output/table-control-layout-20261017/B02/r01/swift-test.log`：生产存储与纯排布源文件的 macOS XCTest 共 17 项、0 失败；覆盖默认完全一致、独立位移、顺序与左右交换、相机、无效值、碰撞、边界夹紧和缩窗恢复。
- `r01/ios-build.log`、`r01/ios-ui-final-build.log`：iOS App / 测试目标编译成功。后续交互测试修订的构建为 `r01/ios-interaction-build.log`。
- 同期源码基线重新编译并冻结 `r01/before-app.app`；手机两个宿主 18 态采集完成。iPad 横屏 18 态完成；该运行器误把 `landscape,portrait` 当作一个参数，实际窗口 JSON 为 1210×834，只算横屏证据，保留原目录/日志。竖屏另行单独采集，不将标签当方向证明。
- 新运行时位于 `r02/layout-app.app`，与原 App 使用不同 bundle ID；原有模拟器 App 数据保留，设备通过共享生命周期工具显式借用。

## 完成标准核验

| 项目 | 实证 |
|---|---|
| 默认位置、尺长、球桌区域一致 | r07/default-comparison.json，手机/Pad横/Pad竖×两宿主×2D/3D共12组，全部在B00事前0.5pt容差内 |
| 两宿主真实组独立移动 | r07/drag-phone、drag-pad；主动作及direction/planning分别移动，另一组与场景框/杆速保持，重叠落点拒绝 |
| 排序、容量、回退与恢复 | ControlLayoutPlacementTests 8项；固定Foundation的120/144pt档位不变，未经证明的额外尺寸不开放 |
| 换侧后真实事件及展开 | r07/swap-phone、swap-pad；2D/3D杆速滑动数值变化、打点展开关闭、真实击球禁用态断言通过 |
| 手机与Pad原生证据 | r07共90图；3份contact及Pad竖屏3D原图已审阅，未见新增控件遮挡；r07/review.html可逐张查看 |
| 构建与定向测试 | r07/build-retry2.log、unit-rebuild.log；r08/unit-test.log共47项0失败，匹配重建的App及测试bundle |
| 门禁 | r08/verify-gate.log FAIL 0，verify-doc-size通过，相关文件diff --check通过 |

r07作为完成矩阵保留；r08另冻结完整源码并补充复验。Pad横竖拖动、换侧和默认共60图全部通过，8组默认几何对拍无超差；手机拖动4图通过，换侧例在思路3D真实击球后的即时禁用断言失败，默认例因此未执行。日志反复出现60秒动画空闲等待，可能错过击球忙碌窗口，但这一推断不能当作通过。保留r08/swap-phone日志与xcresult，后续业务动作验证应检查可持续的动作结果。两版间核心placement/host/Teaching及UI测试指纹相同，FreePlay和自定义球形有同期修改。原始截图保持设备方向；contact仅转正方便审阅。拖放拒绝图与接受图相同是“不改变有效位置”的预期。

下一批B03：每日清台正式编辑及计时闭环。此处不代表用户视觉验收、真机验收或18页产品完成。

## 迭代证据

- r02 换侧测试：自由页 2D 点击/滑动和打点通过检查点，3D 因相机测到原偏移前包装框而误触发回退；保留首次 xcresult。修复为在原生 CameraLane 偏移内测量真实按钮，并在 2D 明确停用相机框。
- r03：自由页 2D/3D 换侧、杆速实际数值变化、打点展开/关闭和真实击球已走通；思路开球态换侧和杆速变化已到达，随后证据 JSON 对某个 AX 空/无限矩形序列化失败，整例仍记失败。原图确认左侧仪表与主动作、右侧方向尺；未将半例写成通过。记录器改为显式记录 nonfinite，真正被测试的主动作/杆速位置断言仍保留。
- 纯排布补充未编辑组保留原横向对齐、宽回放超出许可列时整体拒绝，累计 18 项 XCTest 零失败（r03/swift-test.log）。

- r04 手机换侧完整例通过（8图），手机默认18态完整例通过；四组常态窗口/AX框对拍，无超过预定0.5pt容差的差异。iPad横竖换侧完整例通过（各8图）。r04后新增球库实际点击区域（含两行黑球翼）保护，最终证据改从r05产物重跑，r04不充当最终构建全量验收。
- r05 iOS原生单测共47项通过：ControlLayoutStoreTests 10、ControlLayoutPlacementTests 8、DailyLayoutMetricsTests 29。生命周期包装器的evidence参数误传xcresult目录，子进程测试exit0但租约证据验证失败；47项结果不撤回，包装器整体不记成功。已核进程退出/设备Shutdown，经recover恢复租约，保留日志和xcresult；后续evidence必须传非空文件。Shutdown返回405因设备已经关闭，属于幂等状态。
- verify-gate 首次在本轮新增UI测试写盘面未登记处失败，补登记真实输出/清理边界后第二次全门禁通过（r04/verify-gate-r2.log），未放宽扫描器。

- r06/r07补齐固定教学信息真实可见框保护、教学壳基础布局容量不足时的返回入口。FreePlay沿用原空间不足覆盖，避免重复提示。DEBUG限定的真实组拖放探针用于验证有限移动/非法落点拒绝和业务数值不变；不作为正式编辑器开放。
- r07构建曾被同期自定义球形模块中间态阻断：缺失pocketPositions调用已由同期代码修正；另一处FormationNumericField.title读取MainActor状态，补一行@MainActor以恢复构建，未改变球形业务。首次与后续失败日志均保留。
