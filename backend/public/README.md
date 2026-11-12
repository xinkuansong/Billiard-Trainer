# CuePhys 法律页面发布说明

`privacy/index.html`、`terms/index.html` 与 `support/index.html` 是根据当前客户端、后端数据字段和
Apple 审核要求制作的中英双语模板。服务器默认返回 503，避免把缺少法定主体、
基础设施和保留期限的草稿误当正式政策。

发布前必须由运营主体和专业法律人员核对实际业务，并在生产环境填写：

- `LEGAL_OPERATOR_NAME`：无锡有球科技有限公司（上线时核对营业执照全称）；
- `LEGAL_CONTACT_EMAIL`：`contact@youbilliards.com`（2026-11-12用户已确认外部来信及回复验证通过）；
- `LEGAL_EFFECTIVE_DATE`：`YYYY-MM-DD`；
- `LEGAL_INFRASTRUCTURE_PROVIDER`：实际云服务/受托处理方；
- `LEGAL_DATA_REGION`：实际存储地区；
- `LEGAL_BACKUP_RETENTION_DAYS`：与生产备份删除策略一致的非负整数；
- 最后设置 `LEGAL_DOCUMENTS_PUBLISHED=true`。

部署后必须在未登录浏览器中核验 `/privacy`、`/terms`、`/support`、`/legal.css` 返回 200，
无模板标记、无证书警告，并确认 App Store Connect 隐私标签与页面逐项一致。

随后在 `Config/Secrets.xcconfig` 写入同一组最终地址（xcconfig 中用 `$()` 断开
双斜杠，避免被解析成注释）：

```xcconfig
LEGAL_TERMS_URL = https:/$()/youbilliards.com/legal/cuephys-terms/
LEGAL_PRIVACY_URL = https:/$()/youbilliards.com/legal/cuephys-privacy/
```

重新构建后，登录页、关于页和订阅页会同时显示该组链接；任一值为空、非 HTTPS
或仍为占位域名时，三个入口都会保持“尚未发布”状态。

参考依据：

- 全国人大《中华人民共和国个人信息保护法》：https://www.npc.gov.cn/npc/c2/c30834/202108/t20210820_313088.html
- Apple App Review Guidelines 5.1：https://developer.apple.com/app-store/review/guidelines/
- Apple App Privacy：https://developer.apple.com/help/app-store-connect/reference/app-privacy/

## 首发数据流核对（2026-11-10）

下表据当前客户端和服务端源码核对。候选版本仍需用隔离账号比对网络请求与服务端数据。备份实际保留期限待 W9 恢复演练核实。

| 使用状态 | 处理的数据及接收方 | 源码入口 |
|---|---|---|
| 游客 | 本机保存训练、已保存球形和游客头像。照片建球形在设备上标注，保存为球形布局。训练同步队列要求已登录且已启用同步。 | [训练上传条件](../../QiuJi/Data/Services/SyncQueueManager.swift)、[头像存储](../../QiuJi/Data/Services/AvatarStore.swift)、[照片输入](../../QiuJi/Features/BallExtraction/Views/BallExtractionView.swift) |
| 已登录，训练同步关闭 | Apple 登录向 CuePhys 后端提交认证材料。账号资料（含选填生日）和主动保存的头像仍经账号接口处理，用于展示账号资料。训练上传和球形同步受当前账号开关控制。购买或恢复通过 Apple StoreKit 核对权益。 | [账号接口](../src/routes/auth.js)、[资料接口](../src/routes/user.js)、[账号同步](../../QiuJi/Data/Services/AccountDataCoordinator.swift)、[购买与恢复](../../QiuJi/Data/Services/SubscriptionManager.swift) |
| 已登录，训练同步开启 | CuePhys 后端按账号保存、恢复训练记录、角度成绩、已保存球形，以及工具使用记录（入口、日期、时长）。照片建球形只同步模板。游客数据另按迁移选择处理。 | [工具使用记录](../../QiuJi/Data/Services/ToolUsageTracker.swift)、[训练队列](../../QiuJi/Data/Services/SyncQueueManager.swift)、[球形同步](../../QiuJi/Data/Services/CustomFormationSyncService.swift) |

上线前验证公司对外邮箱能收信并回复。微信登录完成接入后按实际 SDK、授权字段与接收方更新两种语言的政策。公开支持网址拟使用 `https://youbilliards.com/support/`；App政策与协议拟使用公司官网 `/legal/cuephys-privacy/` 与 `/legal/cuephys-terms/`，公网可访问性待部署后验收。

2026-11-12：公司咨询、CuePhys产品反馈与权利请求统一使用contact@youbilliards.com；不购买邮件高级功能，暂不开通support@cuephys.com。源码默认值及.env.example已更新；部署时须核生产环境同名变量是否仍覆盖旧邮箱，本轮未修改生产环境或启用法律页。

2026-11-12：公司官网已导入两份中文草案并单独补齐网站隐私说明；来源哈希和审阅缺项见 `/Users/song/projects/23.website/company-site/docs/LEGAL-REVIEW.md`。本文上方后端503发布门槛继续有效；公司静态网站单独按其正式构建门槛发布。当前未修改App链接配置、生产环境、商店后台或部署；不能因本地页面已有全文就启用App链接。
