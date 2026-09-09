# Release004 最小运行补验准备

2026-09-08，只读包/源码/日志及 `RELEASE-004-RESULT.md`、`PERFORMANCE-004-RESULT.md`；只写本文。未启动App/测试、未调用simctl交互或xcodebuild。目标补SC37普通优化包运行与测试开关边界，**不重复Release构建或5次Debug启动/10轮回放**。

## 已存在且本次实际核验的包

优先从下列已核归档包复制到新诊断安装暂存目录，不在原包上签名/修改：

- `/Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-release-001/球迹.app`
- 同内容构建原包 `/Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-release-001/DerivedData/Build/Products/Release-iphonesimulator/球迹.app`

本次 `/usr/bin/python3` 逐项重算两包对 `archive/.../formal-004-release-001/package-sha256.json`：各984项、mismatch0。最初Homebrew Python因plistlib/pyexpat系统libexpat符号不兼容未执行成功，改用系统Python完成只读核验；不是包损坏。主可执行 SHA `c4bc0d171173fc7d62b8849f109c4b42d3866bff3ec6bb295b946b4cc79a42cf`。

实际Info.plist：bundle `com.xinkuan.qiuji`、executable `球迹`、1.0.0(1)、最低iOS17.0、CFBundleSupportedPlatforms=[iPhoneSimulator]。原构建记录是 Release、-O、无DEBUG、arm64+x86_64、CODE_SIGNING_ALLOWED=NO；不是IPA/真机签名分发包。984文件约393.2MiB已有，不再当商店下载大小。Info.plist API_BASE_URL和两个法律URL为空的形态审计已有QD021；APIClient回退行为意味着空值不能当“全App无网络”保障。

## 静态已能回答的开关隔离

源码路径以下相对 `archive/quality-diagnosis/snapshot-004/source/`。

| 范围 | 实际证据 | 合理结论 |
|---|---|---|
| Pro强制/持久Debug解锁 | `QiuJi/Data/Services/SubscriptionManager.swift:73–80,95–104,194–239` 的相关定义、初始化与guest绕过受 `#if DEBUG`；现Release主二进制精确forcePremium/forceNonPremium/resetDebugPremium串未命中（原包审计）。 | 这组实现的编译隔离有源+包证据；不能由一次普通Free画面反推所有测试开关都剔除。普通运行无需带这些参数。 |
| 预览与部分fixture | `QiuJi/App/RootView.swift:58–70` 的intro.preview/subscription.preview/v57.practiceCountFixture在DEBUG块内。 | 仅这些分支受保护；不能将这段保护扩展到其后全部深链。 |
| 残留测试深链 | RootView `:72–88` 等后续 `-deeplink.settings`/freePlay/silu在DEBUG块外；RootView body优先选择uiTestDeepLink。Release精确 `-deeplink.settings`串存在。 | 测试参数未全部编译剔除是已证实静态事实；普通无参启动不会因此自动绕过首页。是否真实运行可进入设置还缺一条有参观察；不是远程漏洞证据。 |
| 内存库 | `QiuJi/App/QiuJiApp.swift:14–18` 的 `-v50.inMemoryStore` 无DEBUG保护，二进制有串。 | 参数可选择另一容器路径的静态风险，不必破坏磁盘来验证。普通Release补验必须不带它，不能复制Debug测试参数。 |
| 额度强制 | `QiuJi/Features/AngleTraining/AngleUsageLimiter.swift:51–64` 两个w7 flag无DEBUG保护并写当天偏好，包有串。 | 保留静态残留；本最小补验不启用它们污染额度。不据残留字符串宣称用户能从正常UI触发。 |

因此“Debug开关隔离”不能填写整体通过：部分已隔离、部分参数残留，应逐类说明。是否定产品问题及等级仍由主控按Release契约裁定；本稿不新分配QD编号。

## 最小正常运行：一次新专用安装、一条普通旅程

1. 等主控所有UI批次终态后串行操作。新专用iPhone模拟器（可用iOS26.2），实际UDID与明确授权匹配；没有用户账号/旧数据/本地StoreKit成功交易，不重置已有证据设备。系统中文、普通字号/浅色由编排记录。安装现成Release包，不执行会重编/覆盖目标App的普通 `make test`。
2. 安装前、安装后对实际可执行和Info.plist做SHA校验并记录包路径/UDID/进程；若安装要求签名，只在独立暂存副本处理，保存前后差异，不能暗改归档包。若无法安装这份无签模拟器包，记录真实错误及限制，不能偷换Debug包报通过。
3. **无业务/诊断launch参数、无预填defaults**普通启动（语言由系统设置）；先看真实首次引导/guest选择，正常完成，不传hasCompletedOnboarding。已有首启测试不必重演每个反例，这里只为真实Release进入首页建立必要前提。保留启动调用/PID/进入前台的单调时间，不设2秒SLA。
4. 首页核五Tab及 `trainingHome.freeTraining` 实际可操作；正常切“我的”核 `profile.login`游客、无accountHeader；回训练/记录各一次，确认未静默跳到fixture页面。再正常进入偏好设置并返回，核导航可完成；无需录完整训练或跑所有工具。关键图必须独立目视，启动不崩≠页面内容正确。
5. 结束时保留这一个PID时间窗的App日志/崩溃报告、输入hash、全屏PNG/AX与普通操作记录；确认是在Release可执行上，不以“scheme叫Release”替代安装身份。结束运行可以正常停止本App，不清沙盒。

现有 `PerformanceDiagnosticUITests/testFiveProcessColdLaunchObservations` **不宜直接选**：configuredApp带resetDebugPremium/forcePremium/inMemory/hasCompletedOnboarding，并重复5次，且普通测试编排可能重装Debug产品。不存在本次已核的可直接复用纯Release普通启动selector。最省事是主控在现成包上执行上述有界观察；若用独立UI runner，应仅attach/启动已核bundle并保证编排不重装宿主，先审xctestrun/安装路径。本稿不虚构现成selector或声称已配置此runner。

## 如需运行证据确认残留：仅一次独立有参对照

普通旅程和图审先完成，再terminate确认原PID退出，**同一已核Release包**仅加 `-deeplink.settings` 启动一次，其他诊断参数不带。预期观察对象是直接进入偏好设置而非训练首页；保留实际导航标题/正文、五Tab是否出现、进程参数与二进制SHA。若实际直接进设置，证实此测试深链残留在Release执行层；如未进入，不撤销源码/字符串事实，而核启动参数是否真的交付及条件。只此一例，不逐一触发额度/内存库/全部fixture，不把行为称安全攻击。返回普通状态可下一次无参启动，但不拿它再做5轮性能。

这次参数对照属于显式诊断启动，和前面的无参普通旅程分开记录。可以用静态源+包回答残留而省去对照；若SC37最终报告要宣称“残留参数真实效果已验证”，必须实际完成对照，不能以本方案代替。

## 日志隐私的现有静态证据和运行采集边界

本次只定向核 APIClient/AuthState/BackendSyncService/SyncQueueManager/AccountDataCoordinator 的日志调用。APIClient中Bearer赋值是HTTP header构造，不是日志打印；本次所查前三者及Coordinator未命中print/Logger/os_log语句，但不代表全App无泄漏。

`SyncQueueManager.swift:56–57,86,98–103,112` 有Release未屏蔽print，内容含entityType、entityId、operation及error/reason；不是已证实泄露token，但reason/error应按实际内容审查。已有包审“无私钥/证书/test bundle等路径”只回答路径层，不代表没有任何内嵌秘密。不得打开/打印Secrets内容来凑隐私审计。

运行日志最小检查：仅本App、这次PID与时间窗，标明是否出现完整Authorization/Bearer/JWT/refreshToken值、手机号/邮箱、用户心得/照片路径等；发现候选只记录类别/计数/脱敏位置，不把值贴报告。系统框架噪声和App日志区分；不扫描用户其他进程日志。新guest无真实凭据只证明这个普通路径没观察到相关泄露，不能证明登录/同步失败/崩溃上传路径全部安全。当前没有Release运行日志，所以该运行隐私结论仍未验。

## 不外推

Debug五次CTA查询含XCTest开销，不能给Release首次启动背书；十轮RSS不是Release内存/真机性能。此次单旅程不测真实Apple登录、StoreKit到账、通知送达、LiveActivity、相机、音效中断、签名分发或全量Release入口。QD020缺音频、QD009旧盘面、QD021配置缺口继续保留，普通启动成功不能撤销。当前只完成准备和两份包984项SHA复核，无新运行通过数。
