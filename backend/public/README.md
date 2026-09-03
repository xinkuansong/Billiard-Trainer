# 球迹法律页面发布说明

`privacy/index.html` 与 `terms/index.html` 是根据当前客户端、后端数据字段和
Apple 审核要求制作的中英双语模板。服务器默认返回 503，避免把缺少法定主体、
基础设施和保留期限的草稿误当正式政策。

发布前必须由运营主体和专业法律人员核对实际业务，并在生产环境填写：

- `LEGAL_OPERATOR_NAME`：营业执照上的完整主体名称；
- `LEGAL_CONTACT_EMAIL`：真实可收信的权利请求邮箱；
- `LEGAL_EFFECTIVE_DATE`：`YYYY-MM-DD`；
- `LEGAL_INFRASTRUCTURE_PROVIDER`：实际云服务/受托处理方；
- `LEGAL_DATA_REGION`：实际存储地区；
- `LEGAL_BACKUP_RETENTION_DAYS`：与生产备份删除策略一致的非负整数；
- 最后设置 `LEGAL_DOCUMENTS_PUBLISHED=true`。

部署后必须在未登录浏览器中核验 `/privacy`、`/terms`、`/legal.css` 返回 200，
无模板标记、无证书警告，并确认 App Store Connect 隐私标签与页面逐项一致。

随后在 `Config/Secrets.xcconfig` 写入同一组最终地址（xcconfig 中用 `$()` 断开
双斜杠，避免被解析成注释）：

```xcconfig
LEGAL_TERMS_URL = https:/$()/qiuji.app/terms
LEGAL_PRIVACY_URL = https:/$()/qiuji.app/privacy
```

重新构建后，登录页、关于页和订阅页会同时显示该组链接；任一值为空、非 HTTPS
或仍为占位域名时，三个入口都会保持“尚未发布”状态。

参考依据：

- 全国人大《中华人民共和国个人信息保护法》：https://www.npc.gov.cn/npc/c2/c30834/202108/t20210820_313088.html
- Apple App Review Guidelines 5.1：https://developer.apple.com/app-store/review/guidelines/
- Apple App Privacy：https://developer.apple.com/help/app-store-connect/reference/app-privacy/
