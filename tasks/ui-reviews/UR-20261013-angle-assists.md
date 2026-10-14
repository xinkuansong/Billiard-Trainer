# 角度与瞄准：立体假想球与管道显示

用户授权：先分析后实施；2026-10-13明确“2D样式不动”指既有平面假想球圆环，不是仅保护2D机位。三个独立选项默认关闭、分别持久化，适用于本页2D/3D观察。其它页面不新增选项。

## 实现边界

- `AngleDynamicAssistOverlay`复用现有V022/V023磨砂球shader与接触阴影；不复制视频中的隐藏/改色圆环和额外footprint操作。
- 白色瞄准管道C→G、黑色进球管道G→有效袋口点，宽2R、透明填充0.20、边线半宽0.5mm，在G处共用斜接边界；经既有台呢面裁切接口生成。短线段先扩展后按端面裁切，避免折叠多边形。
- 数据来自本页已有计算，不另求解；切换开关只改新增渲染层。无目标/无选袋/越界选袋/不可行/随机摆球动画期间隐藏，正常更新后恢复。临时俯视副场景沿现有镜像契约复制。
- USDZ、TableModelLoader、AngleTrainingScene圆环、全局样式、物理参数和其它页面VM无本任务修改。共享页面只新增默认空的显示菜单参数；原工作区其它未提交改动保留。

## 验证记录

输出根：`output/angle-assists-20261013/`。改前真实页面：`before/page.png`（E03标准手机，页面启动后拍摄）；更早一张训练首页已被真正目标页图覆盖，不计证据。

- 第一轮6项单测通过，离屏截图确认立体球与原圆环共存（`unit.log`、`first-render/`）。
- 扩展短段护栏时第二轮宽度扫描发现原裁切端面与源边重合，Float符号扰动在近乎平行的端面边上生成内点；保留`validation.log`失败，不放宽断言。改为源端面始终超出裁切面一球半径后，7项同源测试通过（`final-standard.log`）。
- 最终7项单测通过：8种组合/双视图保留圆环节点、几何、材质与显隐；球位/指标不变；拖球/失效/重置/随机摆球、独立持久化、临时副场景；12个方向×35个切角宽度/共用斜接，另5切角×3短距离凸性与端面护栏。
- 第一轮原生UI2项通过，实际设置全开/关闭、3D与2D返回、其它教学页无新增项；`first-ui/`已导出并目视查看菜单和3D全开图。最终代码重新采集进行中。
- 最终标准手机2UI、独立SE2UI全部通过：三个菜单项可达、选中反馈、指标不变、2D→3D→2D保持选择、全关恢复，以及分离角图谱没有新增项。标准机`final-standard.log`结尾TEST SUCCEEDED；SE `final-small.log`结尾TEST EXECUTE SUCCEEDED。
- `final-standard/`、`final-small/`为最终XCTest附件导出（manifest包含设备与测试方法）。已逐图打开标准/SE全开菜单及3D画面、标准2D开关前后、分离角设置：文字完整、原白色圆环仍在、立体球/两条带宽正确显示、关闭后回到原图。标准机沿用用户蓝台呢，独立SE为默认绿台呢，非同外观逐像素对照。
- `verify-gate`与`verify-doc-size`通过；后者首次因进度文件超100KB失败，按项目规则归档最旧一条状态后通过。最终`git diff --check`通过。用户视觉认可、真机、性能温升、提交与发布未执行。

## 设备与结果范围

- 标准手机：E03-Profile-Standard-20261009 / F2BE90C4-370D-46AB-B3E8-8F0060424B2D。
- 小屏：本任务新建Angle-Assists-SE-20261013 / D43C7C3F-5539-4E15-91C0-018DD6939372，测试后关闭保留，未操作其它评审设备。
- 功能/原生视觉已验证，用户实际观感与真机体验待复验。没有改动或重新验收其它会话的已有脏文件。

## 真机交付（2026-10-13）

用户要求安装后体验。重新发现iPhone16Pro连接正常；通过`make -f scripts/Makefile build-device-profile BUILD_DIR=build/angle-assists-device-20261013`完成Debug优化真机构建，BUILD SUCCEEDED。本功能4源文件构建前后哈希一致，包ID为com.xinkuan.qiuji。devicectl覆盖安装与正常启动均成功，无卸载/清数据/强制显示开关。回执见`output/angle-assists-20261013/device/`中的build-verification.json、install.json、launch.json。用户观感待反馈，安装/启动不代替视觉验收。

## 同日追加：瞄准线与进球线可选

用户要求两条线默认开启、各自可选。设置使用页专属持久化键；关闭瞄准线包含虚线延长段，各自文字随线显隐，角度数字、平面假想球圆环、立体球、管道独立保留。共享场景新增参数默认true，其它调用者不传参时保持原样；线名使用固定语义索引，支持仅进球线（索引2），缓存包含两条线的选择状态。静止表面只在显隐状态变化时请求刷新。

新证据目录：`output/angle-lines-20261013/`。首轮及刷新补丁轮的10单测均通过，UI在隐藏文字检查失败。保留`standard.log`、`final-standard.log`、`diagnostic-ui.log`：实际原图`diagnostic-ui/lines-pot-only.png`已确认瞄准线和文字均隐藏；XCTest的exists仅代表对象仍在层级中，不表示可见，已改为检查可交互可见性并保留单测的UILabel.isHidden断言。最终重跑被其它会话正在编辑的PlanThreeViewModel阻断：isAdjustingSolution及adjustmentScheduler已有引用、尚无声明；未改该页绕过错误。`verified-standard.log`和`device/verified-build.log`保留构建错误。现有10单测通过不冒充最终源码构建通过，最终UI/SE与本次真机覆盖安装待此构建阻塞解除；手机仍是此前三项辅助显示版。verify-gate（FAIL 0 / WARN 0）、文档体积和diff检查通过。
