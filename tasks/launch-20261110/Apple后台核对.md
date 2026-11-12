# Apple 后台核对 · 2026-11-10

在你已登录的 Apple Developer 和 App Store Connect 账号读取。以下记录只留页面给出的业务状态。此次没有保存改名、修改 Bundle ID、签协议、提交商品或上传 build。

| 页面 | 实查结果 | 对首发的影响 |
|---|---|---|
| Developer → 会员资格详细信息 | 注册身份“个人”，续订日期 2027-03-28。 | 尚未转为无锡有球科技有限公司。按现有会籍申请个人转组织。先核创始人/联合创始人身份、公司法定名称、D‑U‑N‑S 和公司资料。 |
| ASC → 商务 → 协议 | 免费 App 协议“有效（新协议可用）”，有效期 2026-10-19 至 2027-03-27。协议表仅列免费协议。页面要求持有人查看并接受新版开发者许可协议，并在签付费 App 协议前更新法律实体。 | 下次由持有人处理；银行、税务和 Small Business 生效状态没有独立核验结果。欧盟交易商声明也有提示，需申报状态；若在欧盟以交易商身份分发，再完成联系信息验证。 |
| App 信息 | Apple ID 6761309682，SKU QJ-001，简中名称“球迹”，副标题空。套装 ID 为 com.xinkuan.qiuji，显示为可选择的下拉框；ICP 项显示“设置”，未显示备案号。 | CuePhys 尚未写入商店记录；名称可用性须实际保存验证。项目与 ASC 目前的旧套装 ID 一致。 |
| TestFlight / iOS 历史记录 | TestFlight 显示“无构建版本”。iOS 历史仅有版本 1.0 于 2026-03-29“准备提交”。App 信息的套装下拉框含其他可选标识且未禁用。 | 三项共同支持现在仍有机会在原记录切换标识。未做保存验证，也没有逐条上传日志。确定主体和新标识后、首次上传前完成变更。 |
| App 内购买项目 → 终身会员 | 现有商品 Apple ID 6761312020，产品 ID com.xinkuan.qiuji.premium.lifetime，非消耗型，准备提交。简中名称“终身会员”。销售范围已选所有国家或地区，定价基准中国大陆，当前价格覆盖 175 个地区。 | 可沿用该商品；保存过的产品 ID 无法改名。如果要去除商品 ID 中的 xinkuan，需另建商品并同步代码、测试与审核资料。两种方式均只向首发用户展示一个永久会员。 |
| 中国区金额 | 详情页没有显示中国区数字；“所有价格和货币”为可选价格测算页。旧人工清单中的 ¥198 是历史参考。 | 当前后台金额仍待核，首发售价待你定。首个非消耗型须随新 App 版本提交。 |

[Apple 会员页](https://developer.apple.com/account/) · [商务协议](https://appstoreconnect.apple.com/business) · [App 信息](https://appstoreconnect.apple.com/apps/6761309682/distribution/info) · [构建与版本](https://appstoreconnect.apple.com/apps/6761309682/distribution/activity/ios/versions) · [终身会员详情](https://appstoreconnect.apple.com/apps/6761309682/distribution/iaps/6761312020)

## 办理顺序

1. 你核公司 D‑U‑N‑S 和创始人资格，用现有账户申请个人转组织；询问 Team、App 记录及 Apple 登录的连续性。你审阅并接受必须由持有人处理的条款。我按 Apple 回执更新卖方状态。[Apple 个人转组织指南](https://developer.apple.com/help/account/membership/updating-your-account-information/)
2. 我准备最终主 App、扩展和签名配置，对齐 Apple 登录 audience、微信回跳和两个平台的备案字段。已有 App 记录优先复用，先定标识再上传，以免锁定旧前缀。[Apple 更换 Bundle ID](https://developer.apple.com/documentation/xcode/changing-the-bundle-identifier)
3. 企业法律实体核准后完成付费协议、银行和税务，再核 Small Business 申请及实际生效日期。大陆店 iOS 内购标准 25%，计划生效且符合条件时为 12%。现有账户还没有证据可按 12% 预算。[Apple 大陆公告](https://developer.apple.com/cn/news/?id=dadukodv) · [Small Business](https://developer.apple.com/app-store/small-business-program/)
4. 你定价，我核中国区实际金额、商品文案和审核截图，后续收敛客户端商品列表为永久会员。已有商品的产品 ID 与类型不可编辑。[Apple 内购字段](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/)


## 11 月 10 日续查与会籍转换

Apple Developer 账户页提示，持有人须在 **11 月 14 日前**接受新版许可协议以继续访问会员资源。Keys 页面显示 “Getting Started with Keys” 和 “Create a key”，未列出任何密钥。你决定等公司会籍和正式 App 标识都确定后再创建登录密钥。

**Apple 事项先办现有个人会籍转组织。** 先按营业执照上的公司全称、总部地址、邮寄地址和工作联系方式核对邓白氏编号（D‑U‑N‑S）。已有编号则核对主体，未收录可从同一入口免费申请。现有持有人须是公司创始人或联合创始人，Apple 可能要求营业执照等材料。转换申请已于 11 月 10 日提交。转换后按实际回执核对 Team、卖方、原 App 和永久会员商品，再确定标识、配置密钥和真机测试。标准的跨账号 App 转移要求至少一个已发布版本，CuePhys 尚未具备。商标三类申报可同期推进。[个人会籍转组织](https://developer.apple.com/help/account/membership/updating-your-account-information/) · [邓白氏编号查询说明](https://developer.apple.com/help/account/membership/D-U-N-S/) · [跨账户转移条件](https://developer.apple.com/help/app-store-connect/transfer-an-app/app-transfer-criteria/)

**查询表实查。** 已在 Edge 登录现有 Apple 账户，进入[查找你的 D‑U‑N‑S 编号](https://developer.apple.com/enroll/duns-lookup/)并选中 China mainland。页面要求使用罗马字符，工作邮箱栏提示使用组织域名；另需总部地址、邮编和联系人电话。你已确认公司此前没有使用过英文名或拼音名。首次查询可尝试以 Wuxi Youqiu Technology Co., Ltd. 作为中文名称的译写；该写法仅用于检索，正式转换以邓白氏核实的企业档案为准。已按你提供的执照住所填写 Edge 查询草稿，包括公司名称译写、街道、市和省。已在表内填写并读回邮编 **214037**。[地址邮编目录](https://youbian.hao86.com/num/214037/)同时列出盛德路和新惠家园，[盛德路邮编](https://alexa.ip138.com/post/jiangsu/wuei/beitang/4.htm)可供交叉核对。工作邮箱按你指定的 163 邮箱填写。11 月 10 日已通过验证码并匹配现有企业档案，中文名、街道、门牌及房号与执照一致。档案英文名为 Wuxi Youqiu Technology Co., Ltd，档案邮编为 214000，查询表填写 214037。已确认该档案，Apple 回执显示编号已发往所填邮箱。11 月 10 日 07:47 的 Apple Developer 邮件确认 D‑U‑N‑S 为 **308938967**，企业英文名为 **Wuxi Youqiu Technology Co., Ltd**。已在现有个人团队的转换表预填地区、公司英文名和编号；你本人已确认是创始人或联合创始人，已在表内选 Yes 并读回。你确认公司没有其他经营名称、从未以公司名义加入开发者计划，两项均已选 No 并读回。税号字段起初留空。11 月 10 日复查 App Store Connect 商务，仅列有效的免费 App 协议，页面提示签付费协议前需更新法律实体，未显示已提交的税务表单或关联税号类型。打开法律实体详情亦未见税号字段，已取消退出。上述可见信息不足以确认个人会籍税号为 None。你随后决定按本人的判断选 None，无需另发询问。11 月 10 日已核对四项回答并提交现有个人会籍转组织申请。Apple 回执表示会审核并在一个工作日内回复，页面未显示案件编号；转换结果待回信。

## W5 本地实现与验收

iOS 登录现在通过 HTTPS 发送一次性授权码和身份令牌，服务端核对两者的 Apple 用户标识，并加密保存撤销所需的凭据。注销后清除云端训练数据。若 Apple 暂时不可用，账号保持冻结，后台重试；没有可撤销凭据的旧账号仍可删除，客户端提供手动解除授权的路径。本机训练记录继续按原设置保留为游客数据。

Debug 模拟器目标构建通过，后端 37 项测试通过。另用本地真实 MongoDB 副本集和带测试签名的模拟 Apple 响应验证 14 项，包括身份不符、授权码重放、加密保存、注销后拒绝旧凭据、撤销失败自动恢复和旧账号删除。此次 W5 尚未部署，真实 Apple 授权、隐藏邮箱、取消、重登和真机注销仍待验。Debug 及本机 Release 配置当前使用 HTTP，正式联调还需在现有服务器配置可验证的 HTTPS 入口。[隔离验证结果](../../output/launch-20261110/apple-revocation-local.json) · [Apple 撤销接口](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens)

11/10 10:24（北京时间）刷新 Apple Developer 账户，协议栏明确显示新版 Apple Developer Program License Agreement 签发日期为 10/30、接受日期为 11/10；原 11/14 前签署的待办已关闭。账户注册身份仍为个人，转组织申请继续等回信；此结果只核对计划许可协议。

## 11 月 11 日用户提供 Apple 支持回信

依据：用户提供 Cassie / Developer Support 邮件截图；截图未显示邮件发送时间，按 2026-11-11 收到用户反馈登记，不推定邮件时分。案件编号 **30000010499110**。

Apple 表示随时可以开始个人会籍迁移至组织会籍，要求准备好后回复邮件。因此当前状态为「已收到准备要求，待回复启动」，不能标记已开始迁移或已转换完成。邮件明确：

- Apple 账户须开启双重认证。
- 需要有效且可公开访问的组织网站，域名须与组织相关联。仅注册域名不等于完成网站要求。
- 迁移过程中不能访问 Certificates, Identifiers & Profiles；App Store Connect 等其他开发者资源访问不受影响。邮件没有说明现有登录密钥是否失效，不能据此推断。
- 完成后 App Store 的法律实体名称应用于所有 App；无法再获取适用于个人会籍的销售和趋势报告。
- 若有付费 App / IAP，迁移完成前收入进入迁移开始时有效的银行账户；如需更改该部分收入账户须在启动前完成。当前 App 尚未上线，不推定已有销售收入。

顺序调整：优先准备并发布 cuephys.com 的公司介绍页，说明无锡有球科技有限公司与 CuePhys 的关系及真实联系方式，并实际核验公开访问；同时核双重认证。准备好再由用户确认启动并回复此案。当前未发送回复、未启动迁移。若需要先为现有 App 创建 Apple 登录密钥，应在确认启动迁移前办理；迁移期间后台入口将不可用。

### 后续顺序确认（2026-11-11 12:17:59，北京时间）

用户决定登录密钥后置，先完成会籍转换；公司官网另开会话负责。采用本地预览、网站备案、现有上海服务器正式部署与 HTTPS 验收后，再回复 Apple 启动迁移的长期方案，不使用临时托管抢进度。此前「若需先建测试密钥」为备选讨论，已不作为当前执行路线。网站与迁移尚未开始计时；手机端新版登录尚未恢复。[交接卡](官网与账号迁移交接.md)
