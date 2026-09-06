# 我的设置、关于与照片入口诊断草稿

2026-09-06：新增ProfileNavigationDiagnosticUITests.swift三方法，未编译/运行，仅新文件。无真实账号登录/上传/凭证读取，无意见反馈/好评点击，不进入注销、清缓存，不打开已有照片。

## 方法级selector

前缀 `QiuJiUITests/ProfileNavigationDiagnosticUITests/`。

1. `testGuestAppearanceAndSoundPreferencesRestoreOriginalValues`：实际游客UI→偏好设置；用BTTogglePillGroup的isSelected读取原偏好（不是把当前有效dark当用户选择dark）；声音0/1读取、切换、恢复；实际浅深色环境`settings.content.value`核对并拍图；恢复原选项、声音仍原值，返回。
2. `testAboutShowsFrozenUnpublishedLegalConfigurationWithoutExternalActions`：正常关于与反馈页，断言明确尚未发布文案、无about.terms/about.privacy链接，取景返回。不打开网络链接，不点击反馈或好评。
3. `testPhotoExtractionNormalEntryShowsUnselectedStateAndReturns`：正常练习→打→拍照建球形（forcePremium仅功能前提），无图第一步、选择照片可操作、未出现下一步，返回原卡。**没有打开相册选择器，不读取用户照片**。

## 依据与判断边界

- SettingsView的scrollView有`settings.content`并回显实际SwiftUI colorScheme。外观组由BTTogglePillGroup给精确Label和selected trait；“击球音效”是正常Toggle，无独立identifier，按精确label定位。
- 本套launch故意不传followSystemAppearance/forceLight/forceDark，否则根页会覆盖真实偏好，无法验证用户切换。设置值改变属于专用设备UserDefaults，即便内存SwiftData也持久。完整成功路径恢复原值；中途失败可能保留最后测试偏好，主控需按before截图/原选项证据定向恢复，不能清全部设置。测试不自行吞异常再宣称恢复完成。
- 关于页只在AppConfig两URL都有效时显示链接，否则展示明确缺配置文案。冻结Debug.xcconfig两个LEGAL值为空，因此草稿采用“尚未发布”预期。Release包含Secrets覆盖，未读取其内容；如主控实际Debug产物注入不同配置，先以产物键值存在/有效性核对后调整预期，不能把不同配置当法律页缺陷。本项不验证条款内容、HTTP可达性、法律合规或Release。
- BallExtractionView第一步目前只有PhotosPicker，标题/描述使用“拍摄或选择”，**没有独立相机按钮或相机不可用分支**。本轮不能虚构“点相机→不可用提示”的测试。将文案与实际能力差异作为待产品判断线索，单凭源码不直接判缺陷。
- 不打开照片选择器意味着只覆盖正常入口/无图状态/返回；真实空相册、取消选择、导入、相机权限与不可用反馈仍未覆盖。后续仅可在明确无私人媒体的专用模拟器导入受控合成样本后测试，不能为补覆盖浏览用户已有相册。

## 运行和证据

- 照片入口是Pro门控，此套forcePremium是功能前提，不证明购买或免费门控。每项先用profile.login+游客模式throwing核对，拒绝在实际登录设备继续操作。
- QD_SHOT_DIR/TEST_RUNNER_QD_SHOT_DIR接收截图；每实例UUID+阶段，keepAlways，I/O失败抛出。没有固定主workspace写盘。
- 实际AX仍需运行：selected trait是否映射isSelected、Toggle是否精确label、About静态长文是否合并。失败先导出AX与截图，不删断言换绿。
- 设置方法预期5图、关于1图、照片2图。App实际浅深色还需图像审查；settings.content回显虽比simctl更接近产品环境，也不替代截图。音效Toggle变化不证明真实发声、静音/后台音频行为。
