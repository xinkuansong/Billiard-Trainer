# Pro解锁按钮统一样式 · 2026-10-19

用户接受`output/pro-button-preview-20261019/preview-light-1x.png`，授权应用所有Pro解锁按钮并适配深色。最新纯金皇冠r11继续使用，母版/球布局不变。

## 覆盖与实现

| 宿主 | 消费路径 |
| --- | --- |
| 动作详情底栏 | BTButtonStyle.goldFilled → BTProUnlockButtonStyle |
| 详情/计划渐隐锁、统计/历史/理论等全遮罩门控 | BTPremiumLock → BTProUnlockButtonStyle |
| 深色球桌次数用尽：完整、紧凑 | BTDailyLimitGate → 共用样式，强制dark |
| 文档工具次数用尽：完整、紧凑 | BTAdaptiveToolLimitGate → 共用样式，随外观 |
| 会员购买及升级终身 | ProBrandButtonStyle → 共用样式，品牌深色；按钮补r11皇冠 |

新语义色：浅色底#E9DEC9/字#765C30（已接受），深色底#3B3325/字#EAD6AF。48pt按钮最小高度、56pt购买按钮最小高度；使用minHeight允许大字增长，保持原字体及点击行为。禁用购买仍是灰态；恢复购买/管理订阅/模拟器调试操作不属于升级CTA，保持语义。

## 验证

隔离当前源码并逐文件SHA匹配；目录`output/pro-unlock-style-20261019/`。构建、两外观颜色对比度、全部共享宿主的原生组件画廊、详情双入口/Pro边界、订阅选档与登录返回、小屏旋转大字号复验中。改前证据沿用r11原生截图与用户接受的预览；不以旧截图作为新结果。


### 验证结果

- 构建通过；标准手机6组件/对比度测试与详情双入口UI通过，小屏会员状态页旋转请求/大字号UI通过，合计8通过。已打开浅/深组件画廊、深色详情双CTA、小屏大字号原图；文字/皇冠可辨，按钮无裁切。浅色文字对比4.712:1、深色8.739:1。
- 订阅选档`testProPresentation`未通过：年付商品不存在。失败AX显示“模拟器未注入商店配置，当前无法购买”；本机此前同类StoreKit限制见`tasks/PRO-ENTITLEMENT-EXECUTION-20261017.md`。保留phone.xcresult的7通过/1失败，不宣称购买流通过。未再重复运行同样依赖商品的旋转购买测试，改跑不依赖商店的会员状态fixture；购买按钮样式本身有原生组件渲染证据，真实商品加载/成交仍未验。
- 15个相关生产/测试/资源SHA与已测冻结快照一致。diff/doc-size通过；verify-gate内容/同步/术语通过，路由签名漂移仍阻断整门禁，未改基线。
- `buttons-light-dark-1x.png`为真实组件渲染1x对照；`page-light-1x.png`/`page-dark-1x.png`为详情原生截图。未装真机，未提交/推送/发布。冠球r11原资源、布局及权限逻辑不变。

截图边界补充：SE的portrait/landscape请求截图均为750×1334，App保持纵向；本轮小屏大字号布局已看到，旋转请求通过不等于横屏布局已验收。
