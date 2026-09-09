# Release004 构建与产物诊断

2026-09-08，冻结snapshot004，本地仅build，未安装/签名/上传。`make -f tasks/quality-diagnosis/diagnostic-release-004.mk`退出0，xcodebuild0，实际BUILD SUCCEEDED。13条Swift命令中12条有-O，DEBUG定义0；产物x86_64+arm64双架构，是模拟器优化包，不是IPA/真机分发包。

## 已核产物

- 身份com.xinkuan.qiuji，球迹，1.0.0(1)，最低iOS17，中文，iPhone/iPad，竖屏；相机/相册读取/写入用途说明、LiveActivities和后台audio存在。
- Live Activity扩展可执行文件及widgetkit扩展点存在，版本/build与宿主一致。隐私清单可解析且与冻结源完全相同；不代表系统权限操作、实际后台调度或法律审查。
- 984文件，逻辑412316542字节（约393.2MiB）；主要是TutorialFigures118722587、Assets114701432、USDZ98247794、双架构主可执行69435336字节。不是商店下载大小。
- Drills76、Plans13、DrillBoards98、DrillThumbnails74、TutorialFigures704、Theory4、Audio3文件。未见禁止目录、Swift/xcconfig/私钥证书/test bundle等可疑路径；存在不等于各内容正确。

## 缺口与风险

- **QD021仍在（P1）**：实际Info.plist API_BASE_URL为空，无scheme/host，无未展开变量。两个法律URL亦空。仅输出URL形态，未读取Secrets或请求服务；不替用户配置地址，不能断言真实部署故障。
- **QD020仍在**：支持音频格式文件0，Audio3文件为文档；未做听感/播放验收。
- **QD009仍在**：六份c002/c006(2)/c007/c062/c066下架盘面进包；不据此宣称正常入口可达。
- 主二进制精确命中-v50.inMemoryStore、-deeplink.settings、-w7.forceDailyLimit、-w7.forceDailyLimitNear；forcePremium/forceNonPremium/resetDebugPremium精确串未命中。结合已有无DEBUG保护源，仅说明测试参数残留；本轮未实启参数，不称普通用户能触发或远程可利用。
- StoreKit空商品Release源分支还显示Xcode配置指令（SubscriptionManager.loadProducts），属于面向用户错误说明风险；本轮没有用Release运行触发该页面，Debug商品失败实测见STOREKIT-004-RESULT。

## 可追溯性与后续

实际产物/日志/调用记录/白名单审计JSON/每文件SHA已归档`archive/quality-diagnosis/runs/formal-004-release-001`，991文件manifest。冻结5350输入在13:33再核changed0/missing0，检查日志和输入哈希同档。没有复制或打印Secrets内容。

SC37本轮完成构建和上述静态包核查；普通Release启动及残留参数真实影响、真机签名/推送/后台仍未验。原docs引用的旧RELEASE-RESULT.md当前不存在，不能用旧路径冒充可重核材料；本报告只引用新004实际档案。整体质量诊断未完成。
