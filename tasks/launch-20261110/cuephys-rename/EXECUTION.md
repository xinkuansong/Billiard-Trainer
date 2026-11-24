# CuePhys 改名整改执行记录

2026-11-24；用户授权基线提交后连续执行。依据[方案 v1.3](../CuePhys改名完整整改方案_v1.md)。本地可执行整改与回归已完成；外部条件仍开放，不是可发布结论。

## 已提交边界

- `8710c6fae`：当前代码、模型与上线准备基线，458 个正式文件；研究输出、备份、个人设置未入库。
- `be2c690c`：房间模型/贴图纳入打包门禁及执行入口。
- `78da2787`：当前生产工具路径、精讲/导入 CLI 测试、快照必需根与 LFS 实体化。
- `2e58618d`：远端安装产物 CuePhys.app、可显式借用现有设备、新版方法选择器括号与命令引用。
- `bb212189`：后端真实启动预检、签名归档身份门禁、当前持久化测试与现行权限/商品目录断言。
- `851bb777`：收尾生产工具/媒体采集入口、实际链接依赖及现行球桌测试合同；完整回归后提交。
- `0cc1f462`：I23通配profile精确授权匹配、导出后IPA资源及分发签名门禁，定向19项及真实签名包往返检查通过。
- 未推送、未上传 App Store、未部署本轮后端。

## 已核验

| 批次 | 证据与结论 | 边界 |
|---|---|---|
| B00 | 736 条历史标识候选、91 个场景引用文件、213 个测试写入候选文件已索引 | 文件数不是页面数；完整业务入口由 B11 矩阵核验 |
| B01 | 源模型 LFS OID/size/SHA256、房间 6 个 USDZ 和 9 张贴图、12 项打包负例通过；旧 Release 的两个 LFS 指针被拒绝；当前 Debug 原生 35/35 通过（模型5、音效24、贴图1、教学图5） | 新签名Release资源亦通过；生产配置/分发待B13 |
| B02 | 新目录/测试名/必需根/LFS 指针校验，44 项队列测试通过；Mac mini 当前提交 bb212189 干净构建及 67/67 测试通过，零跳过；quiescent 工作树快照 4,704 文件校验通过 | 首次容量限制和第二轮旧商品断言失败保留；r3 已回收证据并清理自己的远端工作区，核心设备保留 |
| B03 | 题库实际 verify 21,569 题摘要一致；隔离导入→精讲事实 CLI 与缺输入失败 2/2 通过；修正当前技能/规则路径 | Blender 只改路径并检查语法，未重烘资源；历史研究脚本保持原样 |
| B04 | 默认 CuePhys/TrainingQuota 文件、重复计数/损坏保留、SwiftData 新库重开、两球/分离角真实记录重开与 owner 转移通过；BoardMemory、Checkpoint、SpatialArchive 既有隔离/失败恢复测试通过 | 不读取、搬迁或清除旧 App 数据 |
| B06 | 当前 Keychain 注释纠正为同访问组回退；AuthState 26、APIClient 21 项通过 | 真机不可连接；安全项真机签名读写仍待实证，不用 mock 代替 |
| B07 | 生产预检接入 server.js 真实启动入口；缺身份配置在数据库/监听前拒绝；私钥 P-256、权限、JWT、微信格式/占位值校验；后端 44 项通过。真实本机 MongoDB + HTTP 账号绑定、Apple grant/注销及真实 mongodump/mongorestore 恢复演练通过 | provider HTTP 为受控夹具；不代表生产 Apple/微信授权成功。生产凭据缺口保留 |
| B08 | 官网 AASA 与 Apple CDN 均 200，appID=KWH2GRNSKG.com.youbilliards.cuephys、路径 /cuephys/wechat/* 一致 | 审核/真实 AppID/Secret、微信安装/未安装和签名回跳未验 |
| B09 | 本地 SDK27.1/iOS26.3.1 StoreKit 返回空商品/notEntitled，保留失败 | Mac mini Xcode26.2 同源模型5/5、资料/StoreKit45/46、冷启动1/1；唯一目录断言错误要求旧品牌商品，已改为当前3种商品，r3 资料/StoreKit 46/46、总计67/67通过；正式协议/商品/沙盒购买未关闭 |
| B10 | API /health 200；两法律页 200 且为 CuePhys；主 App/扩展/权限配置已审查。旧“只能竖屏”测试按现行 TP03/30 修正，5/5 通过 | /health 不代表业务就绪；通知与 Live Activity 真机交互未验 |
| B12 | 隔离 MongoDB + 真正 iOS APIClient/SwiftData 链：游客/禁同步不上传，拒绝/接受合并、账号 A/B 切换、恢复及未成年人边界通过；core-r2 18/18，零跳过 | 外部真实登录、正式购买、换实体设备仍需外部条件 |

## 本轮失败与修正

1. 初轮核心集 148 项，1 跳过、17 个断言/错误失败：旧竖屏测试 1、StoreKit 16。不把其它通过抵消失败。
2. 新版 Xcode 的方法选择器须匹配枚举出的 `testMethod()`；旧无括号字符串会造成选择缺失。改用实际枚举名并安全引用。两项磁盘重开和隔离同步在 r2 均真实执行。
3. Xcode 在 StoreKit 失败后启动长时间 simctl diagnose；保留原始日志，仅结束本任务诊断与构建进程。其它任务设备和进程未动。
4. 每日 UI 旧用例仍找顶层视图切换与已撤销的独立开球确认、旧空格计数。按当前菜单和“每日开球计一杆、自动交付”合同更新验证，原失败保留；产品交互未修改。手动开球恢复在 r2 通过；回放中重开由缺失 AX identifier 暴露当前标签，补以同一动作的语义标签定位，随后在 ui-final-phone 复验通过。

## 验证入口与状态

本轮证据根：`output/cuephys-rename-remediation/`。原生测试复用受管工作目录 `output/local-test-runs/45ea4b71660241f8843c51cccded5309/`；只持有本任务产品复验，不清理其它目录。UI 冻结矩阵 `ui-matrix.json`，覆盖导航、每日、七项练习、教学/求解/编排/试打/蛇彩/自定义及专项练习；逐组日志/xcresult 已完成并保留原失败；实际41个独立UI方法最新结果全部通过，见 REGRESSION。

B11 本轮影响 TP01/02/03/08/16/17/25/27/29/30/35：继承既有页面检查表与业务例外，核模型加载、切视图、首个核心动作与退出恢复。布局/物理没有变化；不能用“本次未改”把未验项写成不适用。尺寸矩阵和原图已逐项记录于 REGRESSION。

## 外部条件

- 当前两个实体 iPhone 均 unavailable；不冒充已完成真机签名、通知、触感与授权回跳。
- 微信移动应用仍依赖审核与真实凭据；公开链接已生效不代表 OAuth 成功。
- Apple 私钥/服务端完整配置、付费协议和正式永久商品按人工台账推进；没有实际回执不勾选。
- B13 门禁会拒绝占位微信配置、旧/错误主 App 或扩展身份、错误 API/法律 URL 和签名/profile 不匹配。候选归档即使生成也不等于可发布。

### 当前回归补充

- 初轮 UI：导航5/5；每日1/3；七练习5/7；共享宿主13/14；专项实际3/3。专项清单一项把 BankSolverTrajectoryUITests 误写为 BankPracticeUITests，出现零执行，已列入补测，未记通过。
- r2：两球/三球视图与状态保持均通过、每日实际手动开球及重开App恢复通过。编辑用例仍按旧3D菜单找控件，已核现行专用2D编辑合同，改为拖动→保存→练习重入和位置一致性断言，后续ui-final-phone已通过。
- 13个共享页面的returned-2D原图已逐页合成目视，桌体、球与相应球杆正常；每日浅深真实3D原图亦已核。原图/状态探针/xcresult都保留。此项不是其它未跑入口的替代证据。
- 备份恢复工具首次下载超时，保留失败日志后HTTP续传完整ZIP；隔离恢复演练在 b291ee586592486294f05f23230a16cd 退出0，safeToReopen/repeatReplaySafe/controlMatchesSnapshot为true；已注销账号恢复后的业务接口仍401。未访问生产库。

- 最终引用复扫补齐 `.cursor/agents` 当前角色路径、当前增长规则/题库文档、shot_reconstruction 默认路径及6个仍由媒体技能引用的 capture入口。保留带历史版本/研究现场的旧脚本。
- 6个真实capture shell入口在隔离make替身中验证当前target/方法/设备参数；Make支持带括号方法名的单参数引用，2项测试通过，无视频输出。内容/打包/签名/采集脚本合计18项、队列44项再验通过（首个汇总命令因模块搜索路径错误失败，已保留并纠正命令）。
- defense-bank审计链接器补全当前模块、Objects/LinkFileList和CuePhys.app路径；实际链接发现缺微信SPM依赖，按Package声明补齐SDK链接项，d75d2790a5ba422d9a3f3b9aa4b42146已真实链接成功；没有执行题库生成或更改资源。
- UI补测翻袋练习/求解回放、K球、拍照建球形与进球容错角通过。学习巡游的旧返回链及TablePreferences硬编码历史截图路径失败已保留，正在用逐页正式入口与xcresult默认附件复验。

- ui-final-phone 5/5：外观预览场景、模板实例球拖动/保存/练习重入、两球/三球再次复验、每日击球中重开与回放全部通过。每日重开仍在球运动中触发，未改为等动画结束或删除事务边界断言。
- ui-pad 2/2：iPad两球练习切换状态保持、每日真实渲染实例横竖往返通过。后续floor（iOS17小屏）22/22、学习/内嵌预览和批量工具均通过。

## 首发合同边界（D04 / I22）

- 当前付费商品入口只请求 CuePhys lifetime 非消耗型；测试目录中的月/年商品用于既有状态回归，不表示首发销售三种商品。`StoreKitService` 仅接受已验证交易，按当前 entitlement/撤销与账号 token 判定；`SubscriptionManager` 监听 `Transaction.updates`，App 启动/回前台刷新，购买恢复走 `AppStore.sync`。当前后端没有支付通知路由，也未承诺 App 离线期间实时写入服务端权益。本轮沿用此合同，不新增服务端支付系统；真实沙盒退款/换设备仍在 B09 外部待验，模拟器结果不能替代。
- App 的 `onOpenURL` / `onContinueUserActivity` 当前用于微信回调；AASA 只声明 `/cuephys/wechat/*`。没有正式通用训练分享深链合同，本轮不虚构 `cuephys://` 全业务路由；通知点击沿用独立 TrainingReminderNavigation。现有休息通知/Live Activity 真机开始结束与点击仍待 H-26。
- 已同步 HUMAN-REQUIRED 的现行法律 URL、Apple CDN 和真实条件：保留旧失败日期，避免继续要求恢复旧域名或把 CDN 复验误列未做。

- floor 22/22（iOS17小屏）：模型5、权限5、当前额度10、冷启动1、每日浅深入口1；ui-remaining 中学习与共享页面/动作详情预览均通过。该组唯一失败为摆球测试继承3D却使用2D投影坐标，原图/探针已定位测试前提；明确2D并隔离证据目录后 ui-palette-final 2/2 通过，覆盖编排/批量工具与拍照确认。
- 选择器与实际执行结果再次审计：41个独立UI方法最新结果全部通过，原始失败仍在各组xcresult；此数字不是41个页面，也未把模拟器结果替代真机。学习35张、页面记忆/详情10张、批量/编排2张原图补充目视通过。

- 本任务 Debug 工作区45ea4b71660241f8843c51cccded5309已在全部复验、证据导出和链接验证后由生命周期入口回收；日志/xcresult保留。3个远端任务亦已关闭并取回清理回执，未清理其它会话设备或数据。全局历史生命周期status因旧归档目录inode不一致报错，未修写这些旧登记；本任务记录身份一致、定向complete成功。

## B13 新归档与最终门禁

- 源码提交 `851bb777`，正式App源码未在归档后修改；候选 `output/cuephys-rename-remediation/release/CuePhys.xcarchive`，1.0.0 (1)，Release archive退出0。`source.json`留HEAD/当时文档diff摘要，`candidate-metadata.json`留主App/扩展二进制SHA256。旧坏归档未覆盖。
- 新包模型/房间/贴图门禁通过；主App与扩展 codesign strict 验证、当前Team+Bundle、有效profile、Apple/Associated Domains声明均通过，包内未发现.p8。此归档使用开发签名，尚非商店分发包。
- 首次身份门禁误拒扩展的 `KWH2GRNSKG.*` profile。依 [Apple TN2415](https://developer.apple.com/library/archive/technotes/tn2415/) 修正为同Team下终端通配授权，实际签名仍必须精确等于当前Bundle；错误Team/前缀/签名仍拒绝。原失败保留在identity.json，修正版identity-r2.json唯一身份配置错误为微信AppID缺失/占位。
- 新增 `--require-distribution`，核签名/profile均禁止调试，并拒绝设备限定/企业profile；接入Make导出后真实IPA检查，同时验包内模型。实际开发签名归档的分发检查正确拒绝；临时构造的签名包IPA仅用于验证解包/权限恢复/代码签名与资源检查结果一致，不是Xcode商店导出。相关19项测试通过。
- 当前 `publish_ready=false`：先取得真实微信AppID/Secret、Apple生产配置及完成正式商品/协议和真机链，再生成并验收分发导出；未通过配置门禁的本包没有导出商店IPA或上传。本地可执行工作已收口，B06–B10/B12/B13的外部项继续明确开放。
- 三个远端任务最终均通过定向complete回收build/source与无引用快照；r3先被本任务遗留DTServiceHub占用，在确认无活动Xcode/trace后仅结束该孤儿进程并重试成功。共享核心模拟器及其它任务进程保留。

Release临时构建工作区84b1943f6f114d17871a1db597552e18已定向回收；原archive与完整检查报告留在release/，原始门禁退出1保留。当前可执行整改无剩余代码/测试待办；外部条件按ISSUE-STATUS接续，完整发布验收尚未完成。
