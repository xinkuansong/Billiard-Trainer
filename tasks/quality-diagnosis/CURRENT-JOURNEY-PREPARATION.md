# 当前正常训练保存与重启旅程准备

2026-09-07。`CurrentTrainingJourneyUITests.swift` 只有一个方法：

`QiuJiUITests/CurrentTrainingJourneyUITests/testNormalFirstGroupInputAndNumberedNoteSurviveProcessRestart`

状态：**草稿，未注册、未编译、未运行**。只读 snapshot-003 的训练/输入/心得/历史实际实现及旧 Quality 旅程，未操作设备、创建数据或修改业务。

## 测试范围

专用空游客设备正常磁盘启动 → 个人页确认游客入口 → 历史确认空态 → 训练 Tab 自由训练 → 正常选择中袋直线出杆 → 单项视图 → 第 1 组进球输入 5，核对总球 15 → 自定义数字键盘收起并实际完成第一组 → 结束确认 → 分条训练心得 → 完成/保存 → 返回训练首页 → 真正 terminate/launch → 历史详情读回本次完整唯一心得。

这是输入、保存成功和磁盘重启后心得恢复证据，不是完整成绩语义验收。QD012 已有当前模型失败证据，本用例不要求错误 8 组/120 通过，也不重复以组数缺陷阻塞磁盘读回。若通过，仅可称本条局部旅程通过。

## 当前 API/控件适配

- 数字控件是 UIKit TextField：现有 AX label `第1组进球`、`第1组总球`；自定义键盘现有 ID `setNumberKeyboard.5` / `setNumberKeyboard.完成`。实际点击数字按钮后先读回值 5，再收起。
- `SetNumberField.confirm` → `onConfirm` → completeSet，键盘完成本身已标记第一组完成；不得沿用旧脚本再点“标记完成”，否则会多完成一组或撤销状态。仅在实际休息面板出现时点“完成休息”，不操控 fixture 或改默认时长。
- 使用所有尺寸共有的 `activeTraining.more` 正常菜单结束，核对“结束训练？”弹窗及“结束”。不能把未开始“退出训练？”当同一成功路径。
- session 心得位于 `trainingNote.editor`（UITextView）；开始自动 `1. `，实际 Return 后生成 `2. `。输入唯一 UUID marker 与第二条 `restart-check`，完整值必须等于 `1. <marker>\n2. restart-check`。通过现有 `trainingNote.dismissKeyboard` 收起，再点正常“完成”和“保存训练”。不使用跳过，以免清掉 session.note。
- 历史 noteSection 为独立 Text(note)，使用完整多行 StaticText 精确匹配。未使用宽泛 label CONTAINS marker 冒充完整读回。

## 执行前提与首跑取证

主控为单独空设备完成 UDID/磁盘/游客预飞，并传 `TEST_RUNNER_QD_CURRENT_JOURNEY_AUTH=DEDICATED_EMPTY_GUEST_SIMULATOR`。该字符串只是外部预飞声明，测试还在 UI 检查游客入口和空历史；不自清旧数据。若失败已写入样本，不得原设备直接重跑本空态用例并把缺少空态认定为产品故障，须保留样本、换专用设备或定义明确新 run 的恢复步骤。

launchClean 仅中文/地区、跳过 onboarding、resetDebugPremium；追加 forceNonPremium/followSystemAppearance。**没有 inMemoryStore、数据深链、预种训练、登录、购买或清除用户历史。** 跳过引导意味着不覆盖首次 onboarding。所有证据为 xcresult 原生截图/AX附件，没有固定路径写文件。

首次运行需重点检查以下实际 AX/图像，而不是为了通过猜坐标：

1. c012 选择入口“添加中袋直线出杆”“完成(1)”是否仍按源代码暴露；第 1 组进球/总球是否为 TextField 且目标 15。
2. 数字键盘实际命中后输入 5、收起后“已完成”与休息遮罩状态；若 AX 命中异常，保存失败树再判断控件/测试问题，不直接使用未验证的屏幕坐标。
3. 更多菜单与结束确认的当前类型/可见性；仅现有 ID 查询，无全树重复 descendant 扫描。滚动最多 4 次，只为显露实际控件。
4. 新 UITextView 首次聚焦 `1. ` 的实际值、首次系统键盘介绍是否出现、Return 是否逐条编号。系统介绍若挡住输入须先依据截图/树补明确系统步骤，不把“点 Continue”硬塞进常规路径。
5. 完成按钮在键盘消失后的类型、保存后首页返回、重启后精确多行 note 的 AX 类型。当前预期 Text(note) 为 StaticText，需要首跑确认；不得降级成只看页面标题。

每个关键阶段保留截图+一次 AX 树，避免每次 wait 都扫描全元素。现有 helper 的正常启动最多两次重试会写入日志，不能把启动稳定性据此宣称完全通过。这个方法不打开相册、不分享到系统、不删改既有记录；结束后自己的诊断记录留在专用设备供独立核查。
