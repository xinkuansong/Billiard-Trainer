# CuePhys · App Store Connect 隐私填表稿

2026-11-11，北京时间。主体为无锡有球科技有限公司。依据当前 iOS 客户端、服务端接口和本地未签名 iPhoneOS Release 1.0.0 (1)。本次更新了主 App 的隐私清单和隐私政策模板；后台问卷尚未提交。

## 后台怎么填

进入 App Store Connect → App → CuePhys 对应的 App 记录 → App 隐私。第一问「你或你的第三方合作伙伴是否从此 App 收集数据」选 **是**。下表每行均选 **关联用户身份：是**、**用于跟踪：否**。这是因为登录账号的数据和购买归属均可对应用户，当前用途是提供功能或统计工具使用情况。游客可以完全留在本机，商店标签仍须涵盖选择登录、同步或购买的用户。[Apple 数据定义](https://developer.apple.com/app-store/app-privacy-details/) · [后台操作说明](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)

| 在后台勾选的数据类型 | 勾选用途 | 触发条件、接收方及保留内容 |
|---|---|---|
| 标识符 → 用户 ID（User ID） | App 功能 | CuePhys 后端保存内部账号 ID、Apple 用户标识或「微信 AppID + OpenID」。绑定后两个入口可进入同一账号。购买时 App 另向 Apple 提供对应账号的专用标识。注销账本保留内部 ID、阶段、时间及校验信息，用于恢复备份时重新执行删除。[登录和绑定](../../backend/src/routes/auth.js) · [微信换码](../../backend/src/services/wechatLogin.js) · [注销账本](../../backend/src/services/deletionLedger.js) |
| 联系信息 → 姓名（Name） | App 功能 | Apple 登录可提供用户授权的姓名，CuePhys 后端可将其保存为显示名；用户也可编辑昵称。仅使用微信登录时，后端没有调用微信资料接口。[Apple 登录请求](../../QiuJi/Data/Services/AuthService.swift) · [账号模型](../../backend/src/models/User.js) |
| 联系信息 → 电子邮件地址（Email Address） | App 功能 | Apple 首次建号时，如身份凭据包含邮箱，后端保存该地址；可能为 Apple 中继邮箱。[服务端建号](../../backend/src/routes/auth.js) |
| 用户内容 → 照片或视频（Photos or Videos） | App 功能 | 登录用户确认保存头像时，JPEG 上传并与账号关联。游客头像、球桌照片原图、保存到系统相册的训练分享卡均在本机处理。同步自定义球形时服务器收到模板。[头像接口](../../backend/src/routes/user.js) · [权限实测](相机相册与通知权限验证.md) |
| 健康与健身 → 健身（Fitness） | App 功能 | 用户在真实球台完成或手动记录的运动训练可包含日期、时长、组数、进球与目标。开启该账号的同步后，这些字段进入 CuePhys 数据库，可供恢复与查看训练历史。按 Apple 的运动数据定义归入健身；无须使用 HealthKit 才适用。[会话字段](../../backend/src/models/TrainingSession.js) · [数据库复验](游客与云同步验证.md) |
| 用户内容 → 其他用户内容（Other User Content） | App 功能 | 训练心得、手工输入的练习内容、自定义球形名称与布局、角度答题输入及结果随账号同步，用于复盘、编辑和恢复。[成绩模型](../../backend/src/models/AngleTest.js) · [球形模型](../../backend/src/models/CustomFormation.js) |
| 其他数据 → 其他数据类型（Other Data Types） | App 功能、分析（选填年龄段用于用户分布统计） | 登录时提交的“已满 14 周岁”确认、成功登录后才随账号保存的选填年龄段、选填性别、出生日期、球种偏好、水平、球龄和周目标。登录后保存或带入资料时可写入账号，用于资料展示、计算年龄或显示目标；训练同步开关单独控制训练数据。此项为对当前结构化资料的填表判断。[资料字段及带入范围](../../backend/src/services/userProfile.js) |
| 使用数据 → 产品交互（Product Interaction） | App 功能、分析 | 自由击球等入口保存工具名称、日期和停留时长，形成工具使用记录。账号开启同步后可离机，用于个人历史及方案已列明的产品统计与改进。短于 5 秒的停留会被忽略。[记录入口](../../QiuJi/Data/Services/ToolUsageTracker.swift) · [隐私页用途说明](../../backend/public/privacy/index.html) |
| 购买项目 → 购买历史（Purchase History） | App 功能 | 永久会员交易将 CuePhys 账号专用标识发给 App Store，StoreKit 在已验证交易中返回该标识，App 比对归属后解锁或恢复。按这项持续关联的权益作保守披露。当前业务后端未设订单库或收据上传接口，Apple 处理付款，CuePhys 不收银行卡号。[购买请求](../../QiuJi/Data/Services/StoreKitService.swift) · [账号归属实测](永久会员本地验证.md) · [Apple 交易标识](https://developer.apple.com/documentation/storekit/transaction/appaccounttoken) |

**留空的项目。** 当前公司侧没有手机号登录、通讯录读取、定位、广告 ID、人脸识别、医疗数据或付款卡资料业务。自适应角度选题在设备的 UserDefaults 中保存并使用局部历史；本轮没有发现服务器以用户画像投放内容。拟不勾选产品个性化、广告或营销。支持渠道为外部邮件，正式版如新增 App 内工单、故障上传或服务端推荐，应按实际收集重新评估。[本地出题逻辑](../../QiuJi/Features/AngleTraining/AdaptiveQuestionEngine.swift) · [Apple 的用途和可选披露条件](https://developer.apple.com/app-store/app-privacy-details/)

## 离开设备的数据去了哪里

- **游客、登录及同步。** 游客训练、球形和头像首先保存在本机。登录会联系对应身份提供方和 CuePhys 后端；保存账号头像或资料会上传。只有按账号启用训练同步后才上传待同步的训练、成绩、球形。拒绝合并的游客记录仍留本地；关闭同步后，先前已同步的云端记录仍可存在。[游客与云同步验证](游客与云同步验证.md)
- **微信。** App 以 OpenSDK 2.0.9 发起授权，实际请求的范围为 `snsapi_userinfo`。服务端仅用授权码交换并保存应用范围的身份标识，没有调用微信资料接口。腾讯说明 iOS 适配所用设备型号保存在设备本地，跨 App 传递相关信息可使用系统剪切板。机型本身不能据此推断成已采集唯一设备 ID。未启用微信支付。真机授权及回调待正式 AppID、Universal Link 验证。[SDK 入口](../../Packages/CuePhysWeChat/Sources/CuePhysWeChat/WeChatAuthorization.swift) · [腾讯个人信息处理规则](https://support.weixin.qq.com/cgi-bin/mmsupportacctnodeweb-bin/pages/RYiYJkLOrQwu0nb8)
- **存储与删除。** 业务库和头像存储承担当前账号数据，Mac mini 保存受控的加密备份。注销清除业务数据，独立注销账本供旧备份恢复时补删。备份保留期与注销账本的存续条件应分别核对；个人身份证、公司证照和域名注册资料属于公司办事材料，不进入这份 App 用户标签。[备份与恢复](备份恢复验证.md)

## 构建核验及正式发布前的三个检查点

1. 11 月 11 日 02:11 已读回未签名 Release 包。当时主清单 9 项均关联用户、跟踪为否，仅产品交互另含分析。新增年龄段问卷后，源清单的「其他数据类型」也列入分析用途，正式归档时重新核对。App 使用 UserDefaults（CA92.1），并用系统时钟测量动画、声音等事件间隔（35F9.1）。微信包内清单与固定 SDK 压缩包内的清单内容相同，仅列 UserDefaults（CA92.1）；供应商未列收集类型不能代替对实际登录链路的判断。正式签名 Archive 后用 Organizer 导出聚合隐私报告，与本次清单逐项比对。[包内核验与哈希](隐私清单包内核验.json) · [Apple API 理由](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
2. 正式 HTTPS 入口启用时，核对代理、云安全服务与应用错误日志是否保存 IP、请求路径、设备信息或诊断内容，保存多久、是否关联账号。若留存，按具体用途补类型；不从一个 IP 推定地理定位。检查生产诊断和分析配置，尤其是另行取得并留存的用户级崩溃或性能数据。[Apple 关于 IP、Apple 服务与仅设备处理的说明](https://developer.apple.com/app-store/app-privacy-details/)
3. 「隐私政策网址」填写正式部署并验证可匿名访问的 HTTPS 隐私页。确认页面有公司主体、可用的联系邮箱、真实备份保留期；完成微信真机复核、未成年人处理核对及上述日志检查后，在 ASC 预览标签，再发布。此次没有写入 ASC 或公开发布隐私页。
