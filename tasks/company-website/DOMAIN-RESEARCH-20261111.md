# 公司官网域名候选查询

2026-11-11 13:00:59（北京时间）初次整理；本轮查询约从 12:55 开始。后续用户明确确认“好的，那就YouBilliards吧”，公司官网选定 youbilliards.com；尚未下单或变更 DNS。

## 定位与现有域名

正式公司官网介绍无锡有球科技有限公司及 CuePhys，不能仅按 Apple 会籍迁移材料设计。公司域名独立选型；已购 cuephys.com 继续保留产品支持、隐私与协议、API、微信回调及邮箱等用途。两个域名可共用网站代码与现有服务器，具体路由在部署前定义，不对产品所有路径做整站跳转。

## 注册局查询快照

`.com` 查询 Verisign RDAP（`https://rdap.verisign.com/com/v1/domain/<域名>`）及部分 WHOIS（`whois.verisign-grs.com:43`）；`.cn` 查询 CNNIC WHOIS（`whois.cnnic.cn:43`）。未查到记录仅为候选筛查，不能等同注册商已确认可售、普通价格或已预留。

| 候选 | 查询结果 | 依据 |
| --- | --- | --- |
| youqiu.com | 已注册 | RDAP 200 |
| youqiu.cn | 已注册 | CNNIC 返回注册记录 |
| youqiutech.com | 未查到记录 | RDAP 404；WHOIS No match |
| youqiukeji.com | 未查到记录 | RDAP 404；WHOIS 超时 |
| wxyouqiu.com | 未查到记录 | RDAP 404；WHOIS No match |
| youqiutechnology.com | 未查到记录 | RDAP 404；WHOIS 超时 |
| youqiutech.cn | 已注册 | CNNIC 返回注册记录 |
| youqiukeji.cn | 已注册 | CNNIC 返回注册记录 |
| youball.com | 已注册 | RDAP 与 WHOIS 均返回注册记录 |
| youball.cn | 未查到记录 | CNNIC No matching record |
| youbilliard.com | 未查到记录 | RDAP 404；WHOIS No match |
| youbilliard.cn | 未查到记录 | CNNIC No matching record |
| youbilliards.com | 腾讯云确认可注册，普通域名，首年 88 元 | 13:04:39 官网 CheckDomain 接口；此前 RDAP 404 |
| youbilliards.cn | 未查到记录 | CNNIC No matching record |

## 名称比较与最终选择

2026-11-11 用户在核对 Billiards 广义涵盖斯诺克、比较 YouBallTech 后确认采用 YouBilliards。公司官网域名选定 youbilliards.com；保留 CuePhys 产品品牌及现有产品域名。以下为此前候选比较，未选中的名字不作为现行方案。

- YouqiuTech：对应“有球科技”，适合以公司身份为主的域名，业务范围较宽；拼音对不懂中文的人缺少直接含义。
- YouBall：较短，保留“有”的拼音并表达球；但 `.com` 已被注册，且 [App Store 已有 YouBall 游戏](https://apps.apple.com/us/app/youball/id6451358832)。这说明辨识度有竞争，不是商标冲突结论。
- YouBilliard / YouBilliards：台球方向明确，但比 YouBall 长，中文用户口述和拼写成本较高。若选这个方向，倾向 YouBilliards：表示运动通常用 [billiards](https://dictionary.cambridge.org/dictionary/english/billiards)，[billiard](https://www.oxfordlearnersdictionaries.com/definition/english/billiard) 常放在名词前，如 billiard table。自创品牌不必机械遵守普通词组语法，因此不将 YouBilliard 判为不可用。
- 这些候选不自动替换 CuePhys 产品名，也不变更公司登记名称。

## 价格与备案核查边界

初轮腾讯云选购页的浏览器读取连续超时，网页读取未取得完整实时价格表。随后在 2026-11-11 13:04–13:05（北京时间），读取[腾讯云选购页](https://buy.cloud.tencent.com/domain)实际引用的公开 JavaScript，按其中请求格式调用其无需登录的查询接口，取得以下结果；没有使用账号凭据，没有建立订单或付款。

| 查询 | 实时结果 | 平台响应时间（北京时间） |
| --- | --- | --- |
| CheckDomain：youbilliards.com，1 年 | Available=true，Premium=false，BlackWord=false，RecordSupport=true；Price=RealPrice=88 元 | 2026-11-11 13:04:39.350 |
| DescribeDomainPriceList：.com，新注及续费各 1 年 | 新注 Price=RealPrice=88 元；续费 Price=RealPrice=95 元 | 2026-11-11 13:05:00.712 |

接口地址均为 `https://dnspod.cloud.tencent.com/cgi/capi?action=<接口名>`，对应[官网价格页](https://buy.cloud.tencent.com/domain/price)。查询使用 Version=2018-08-08、serviceType=domain；CheckDomain 参数为 DomainName=youbilliards.com、Period="1"、Year=1、RequestFrom=new_domain_buy；价格参数为 TldList=[".com"]、Operation=["new","renew"]、Year=[1]。

两个请求的 RequestId 分别为 `4e3c1f45-1d12-43e0-b1f9-4910594688f9`、`7cfae6a1-b774-4bbd-a9d6-55782cbf50de`。RecordSupport=true 是平台标记，不代表网站已备案或必然审批通过。可售状态和价格是本次查询快照，未锁定域名；95 元是当前续费标准，不保证未来续费时永不调整。其他候选尚未逐个取得注册商报价。

cuephys.com 的历史购买记录为 2026-11-10 首年 88 元、当时所记续费标准 95 元/年，仅用于预算背景，不能当作新候选的当前报价。原始记录见[备案与微信材料包](../launch-20261110/备案与微信材料包.md)。

备案仍按公司主体、域名实名与实际接入服务办理。域名候选未到提交阶段，不承诺审批结果；已有备案草稿需要先核对，避免重复建单。腾讯云官方说明：同一账号只支持一个进行中的备案订单；网站和 App 是分别登记的备案对象，支持在同一订单中办理；域名不必转入腾讯云才能使用其备案服务。参考[备案前准备](https://cloud.tencent.com/document/product/243/18911)及[备案常见问题](https://cloud.tencent.com/document/faq/243/19627)。

下一步：域名购买单独办理，使用无锡有球科技有限公司的实名模板，在结算时复核域名拼写、年限及应付金额。当前已完成查询和名称选择，未下单。
