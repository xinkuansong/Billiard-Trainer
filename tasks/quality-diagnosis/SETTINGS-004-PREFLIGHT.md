# Settings 004 最小持久化补验预飞

2026-09-08；Test Engineer；只准备独立诊断源码，未注册、构建、运行或操作设备。`swiftc -frontend -parse` 退出 0 仅证明语法解析，不证明类型检查或 UI 通过。

## 已有证据与本次增量

`ProfileNavigationDiagnosticUITests.testGuestAppearanceAndSoundPreferencesRestoreOriginalValues` 已有切换音效再恢复、浅深色与返回草稿；`testAboutShowsFrozenUnpublishedLegalConfigurationWithoutExternalActions` 已有未发布法律说明草稿。`PROFILE-NAVIGATION-REVIEW.md` 明确未编译/运行；检索当前 README、COVERAGE-STATUS、结果文档及准备记录，未找到这两个方法正式通过证据，不能按已注册推定已验。P8 旧测试有设置/关于入口及外观冷重启方法，不能替代声音改变值的磁盘重启。

本次单方法 `QiuJiUITests/SettingsBoundaryDiagnosticUITests/testOrdinaryGuestSoundPersistsAcrossRestartAndAboutShowsInstalledVersion`：全新磁盘游客普通启动 → 正常跳过首次介绍 → 我的 → 偏好设置，实测声音初始 0/1（独立源码预期 true，故若非 1 保留失败）→ 切换为 0 → 返回重入仍 0 → terminate 并确认 notRunning → 无测试业务参数正常重启 → 游客/声音仍 0 → 关于页核对安装包版本与未发布说明 → 正常返回。保留更改后的偏好，绝不清库或恢复覆盖持久化证据。

## 运行前置（由主控执行）

- 新专用普通字号设备，磁盘及 Keychain 初始空，未登录真实账号；不能复用已导入身份或设置的设备。声明授权不是空库物证，应保存主控创建设备、安装记录；方法另外要求真实首次 onboarding 和游客身份。方法不直接读写数据库。
- `QD_SETTINGS_AUTHORIZATION=NEW_DEDICATED_EMPTY_DISK_GUEST_DEVICE`。
- `QD_EXPECTED_DEVICE_UDID` 合法 UUID，等于实际 `SIMULATOR_UDID`，支持 direct / `TEST_RUNNER_` 前缀。
- `QD_SHOT_DIR` 绝对路径；其内自动建唯一 `settings-boundary-<UUID>` 子目录，输出路径写日志，不覆盖原件。
- `QD_SETTINGS_EXPECTED_VERSION_DISPLAY` 由主控从**实际安装 App** 的 Info.plist 两版本字段独立读取得到，例如 `版本 1.0.0（1）`；不能取 runner 的 Bundle.main 或从本次 UI 反填预期。
- 两次 launch 都只有中文语言/locale 参数；无 inMemory、hasCompletedOnboarding、数据、身份、forcePremium/NonPremium、外观、深链参数，launchEnvironment 为空。主控应核对冻结包 API/法律配置仍未发布；不采用虚拟账号或认证网络调用。普通启动系统/内容服务本身的行为不被这条 UI 测试冒称为“整 App 零网络”。

## 真源、定位与边界

冻结根为 `build/quality-diagnosis/snapshot-004/QiuJi/`。

| 环节 | 真源与预期 | 定位证据与未知项 |
|---|---|---|
| 首次介绍 | `Features/Profile/Views/OnboardingView.swift:45–49` 正常跳过 | `onboarding.skip`；不写 onboarding 偏好 |
| 我的入口 | `ProfileView.swift:371–390` NavigationLink 指向 settings/about | `我的` Tab、`profile.login` 游客且无 accountHeader；行无业务 ID，按源码精确文字唯一匹配，不声称当前新设备已观察 |
| 设置 | `SettingsView.swift:40–44,128–137` 实际 ScrollView、音效 Toggle | `settings.content`、switch `击球音效`；与旧诊断语义一致。严格 0/1，不容错猜值 |
| 持久化 | `Data/Services/UserPreferences.swift:103–104,160` didSet 写标准 UserDefaults、初始化缺键默认 true | UI 返回/重启读回，不用测试进程 UserDefaults 冒充 App 磁盘；不证明真实声音 |
| 关于 | `AboutView.swift:45,115–143` 版本及缺 URL 分支；`Core/AppMetadata.swift:4–8` | 实际版本精确文字；完整未发布文案；about.terms/privacy 必须不存在。版本/说明分开滚到完整可见后拍图 |
| 返回 | 复用近期诊断真实 `BackButton` 语义 | 只点当前标题导航栏唯一 BackButton，校验页消失、我的 Tab 返回且游客身份。若系统变体 ID 不同就原地失败，不回退猜首按钮 |

滚动仅在唯一实际 ScrollView 内短幅手势，依据目标真实上下边界选方向；正文须完整位于导航栏以下、TabBar 以上，不仅 isHittable。若当前新设备 AX 不暴露唯一滚动容器或精确文字，先保留 PNG/AX，由主控根据真实输出再作有限测试适配。

所有 capture 先全屏 PNG 再完整 app.debugDescription AX，均附 xcresult；正常阶段包含默认、切换、重入、重启、版本、法律及返回。失败 catch 在终止前取证，teardown 也保留终态并仅 terminate，不删除沙盒。原始运行日志须保留 notRunning 与时间记录；首次介绍完成后第二次不可重新出现。

不点击意见反馈、给个好评、法律外链、清缓存、注销、开发者开关。QD020 音频缺素材、正式法律发布及真实音频体验不因本方法通过而核销；本条只证明指定冻结包/设备的偏好 UI 持久化及关于展示返回。


## 实测后的前提修订

2026-09-08 settings001实际失败20.406秒，make2/recorder0，1403文件与observer归档。失败发生于未出现onboarding.skip；完整PNG/AX为正常空训练首页，RootView普通分支直接MainTabView、Onboarding仅-intro.preview。无设置交互、不能计声音/关于通过。002只调整已证实首屏前提，保留默认声音1、改变0、重入/重启0、版本及法律断言，另新设备；不以UI前提失配立产品缺陷，也不宣称普通首次介绍已验。
