# 十设备评审的键盘基线

2026-10-13 / APP-I034。名称输入测试以屏幕键盘为基线；不改变 App 的真实外接键盘行为。

- 每台 Simulator 的 `I/O → Keyboard → Connect Hardware Keyboard` 应关闭。经菜单配置后，`com.apple.iphonesimulator` 的 `DevicePreferences[UDID].ConnectHardwareKeyboard` 应为布尔 `false`。
- `Toggle Software Keyboard` 只切换显示，不能替代上述连接策略。不要在每次切页时盲目 toggle，否则可能把已经显示的键盘关掉。
- `preview.py status` 只读报告策略；`start/restart/open-page` 在任何启动之前检查整组选中设备。设备覆盖优先于全局值；缺省、异常值、读取失败均不猜测为安全配置。发现漂移由主控核对菜单并恢复，不把未准备好的环境交给用户。
- 配置正确仅表示 `SOFTWARE_INPUT`，不代表键盘已经出现。进入输入框、失焦重入后的真实键盘仍需单独核验。`onscreen=NOT_CHECKED` 是有意保留的证据边界。
- 更换设备 UDID、Simulator 偏好重置或主动测试外接键盘后，应重新建立该设备基线。不要删除整份 Simulator 偏好、重启全部设备或覆盖无关窗口设置。
- 当前模版使用内存存储；创建后不要通过 `open-page/restart` 验证其他动作，应正常导航保留模版。

验证证据：`output/app-live-review/LIVE-20261012-R1/L02/template-dark/keyboard-policy/`。十台持久值读回为 false；03脚本重新启动页面、浅色重入、切回深色重入，以及07 iPad深色重入已观察键盘与全选。未重启整个Simulator，也未由这些结果推导真机已通过。
