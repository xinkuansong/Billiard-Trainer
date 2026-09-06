# SC37 Release 产物诊断准备

2026-09-05；状态：**准备完成，尚未执行 Release 构建或包检查**。基线仅为 `build/quality-diagnosis/snapshot-002`。本文件不代表发布许可或商店合规结论。

## 构建入口与证据边界

冻结 `scripts/Makefile` 的 `build` 两次调用均显式 `-configuration Debug`，传 `CONFIGURATION=Release` 无效。独立 `diagnostic-release.mk` include 该 Makefile，复用 `PROJECT_FLAG` / `SCHEME`，增加 `qd-release`。include 之前用 `override PROJECT_ROOT` 固定冻结根，避免 `lastword MAKEFILE_LIST` 及调用目录误指向主工作区；DerivedData 单独隔离。构建明确 Release simulator、禁签名、仅 build；不调用 archive/run/xcodegen，不安装、不上传。

主控须等当前 UI 测试结束，再串行执行；不与其他构建竞争。执行前记录基线与 overlay 哈希；保留实际命令、进程句柄及 make 退出码。入口将原始 xcodebuild 退出码写入 `xcode-exit.txt`，无 formatter pipeline、无自动第二次构建。已有 log 会拒绝覆盖，应先确认旧进程状态。

```bash
make -f /Users/song/projects/13.billiard_trainer/tasks/quality-diagnosis/diagnostic-release.mk qd-release
```

默认输出 `/Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-b5-release-001`。有意复测才能覆盖变量为同父目录下新的 `formal-b5-release-NNN`，不能覆盖既有轮次。项目 `packages: {}`，此入口不安装依赖、不主动访问网络，禁自动包解析；不增加 `-allowProvisioningUpdates`。编译工具正常读取既有 xcconfig；**禁止直接读取/展示 Secrets.xcconfig，禁止整体打印 build settings/环境变量**。

必须从构建日志核实 CompileSwift 的 Release/优化分支，检查是否异常出现 `-D DEBUG`；最终产物为 `DerivedData/Build/Products/Release-iphonesimulator/球迹.app`。只有 build 成功且产物存在才能进入包审查；Debug 包不得替代。

## 检查清单

| 项目 | 真源及产物核对 | 判定边界 |
|---|---|---|
| App 身份 | project.yml / Info.plist → 产物 bundle ID `com.xinkuan.qiuji`、显示名球迹、版本、build、最低 iOS17、zh-Hans、iPhone/iPad设备族、portrait方向 | 不把版本值存在等同于上架元数据一致 |
| 权限及运行声明 | 产物相机/照片读取/照片写入说明；`NSSupportsLiveActivities=true`；后台 audio；ATS 例外 | 只有生产 Info.plist 实值有效；不以 project.yml 声明代替；权限实际操作另测 |
| Extension | `PlugIns/QiuJiLiveActivityExtension.appex`、独立 Info、可执行文件、bundle ID `com.xinkuan.qiuji.liveactivity`、`NSExtensionPointIdentifier=com.apple.widgetkit-extension`、版本与宿主一致 | 无签名 simulator 包不证明真机 ActivityKit、后台系统调度或分发签名 |
| 隐私清单 | 包根 PrivacyInfo.xcprivacy 可解析；对照冻结源码声明 UserID/Name/Email/PhotosorVideos/OtherUserContent/ProductInteraction、UserDefaults CA92.1 | 只证实进包和声明一致；不声称完成隐私数据流或最新政策法律审查 |
| 必需资源 | Drills、Plans、DrillBoards、DrillThumbnails、TutorialFigures、Theory、Audio、TaiQiuZhuo.usdz、Assets.car；计数/大小/相对路径/哈希 | JSON与HEIC内容质量沿用B3抽样边界；存在不等于可用；Audio缺失/空目录需实际声音另测 |
| 禁入资源 | DrillTutorials母版、Videos、Previews、content源目录、测试bundle、源Swift、xcconfig、Secrets、证书/密钥、`.env` | 仅列相对文件名，不打开可疑秘密文件；配置 excludes 和包内 absence 双查 |
| 旧资源 | 检查 QD-009 已记录的六份 retired board 是否仍进 Release 包 | 使用 ISSUES.md 的确切名单，不能把所有旧文件名自动判定可达缺陷 |
| API / Legal | 产物 URL 非空、无未展开变量、scheme/host有效；legal须符合 AppConfig.validatedLegalURL 的HTTPS/非placeholder规则；ATS一致 | 禁止请求真实服务；只输出布尔值/协议，不输出整URL、query或任何凭据；可解析不等于在线可达 |
| WeChat | App ID 是否非空、非未展开变量；URL scheme 与 App ID 对应；UniversalLink结构 | 只输出匹配/缺失布尔，不输出值；实际微信登录、关联域/签名独立待验 |
| Debug 残留 | 条件编译源码 + Release 二进制精确字符串白名单 + 单独启动行为 | 字符串存在不等于用户可触达；源码无DEBUG保护为风险，不据此假称远程可利用 |
| 包体 | 文件逻辑字节、磁盘占用、文件数、最大20文件、各资源目录字节；和同基线Debug比较时注明构建架构不同 | 未签名模拟器包，不能声称IPA下载体积/App Thinning或真机存储体积 |

## 已发现的静态重点（尚未作 Release 产物验证）

- `Config/Release.xcconfig` 将两个 legal URL 默认设空，再 include Secrets。未读取秘密文件，**不能据默认空值断言最终包为空**。AppConfig.apiBaseURL 对非法值有 fallback，但空字符串等相对URL仍可能通过 URL(string:)；检查最终 API scheme/host，不能只检查非nil。
- `QiuJi/App/QiuJiApp.swift:16` 的 `-v50.inMemoryStore` 无 DEBUG 包围，显式参数可切内存库；RootView 的多条 `-deeplink.*`、`-v51.*` 路由及外观参数亦无统一 DEBUG 包围。`AngleUsageLimiter.swift:54` 的 `-w7.forceDailyLimit` / `-w7.forceDailyLimitNear` 会写计数。正常启动不传参数与 Release 排除测试入口是两个不同条件。
- `SubscriptionManager.swift:138–194` 的 forcePremium/forceNonPremium/resetDebugPremium 定义在 DEBUG 内；仍需在 Release 构建后二进制和正常免费态核实，不与上述无保护参数混为一谈。
- 已读 project.yml 中母版/视频/预览 exclusions、PrivacyInfo资源登记、Release `SWIFT_OPTIMIZATION_LEVEL=-O`。**真实产物审查尚未完成**。

## 主控可执行的只读产物命令

以下只在成功构建后执行。stdout 可重定向到本轮目录，Python使用系统版本，避免本机第三方Python plist依赖问题。内容白名单只输出必要元数据和URL形态。

```bash
/usr/bin/python3 - <<'PY'
import json, plistlib, pathlib, urllib.parse, collections
run = pathlib.Path('/Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-b5-release-001')
app = run / 'DerivedData/Build/Products/Release-iphonesimulator/球迹.app'
assert (run/'xcode-exit.txt').read_text().strip() == '0'
assert app.is_dir()
def read(p):
    with p.open('rb') as f: return plistlib.load(f)
p = read(app/'Info.plist')
keys = ['CFBundleIdentifier','CFBundleName','CFBundleDisplayName','CFBundleShortVersionString','CFBundleVersion','CFBundleDevelopmentRegion','MinimumOSVersion','UIDeviceFamily','UISupportedInterfaceOrientations','UISupportedInterfaceOrientations~ipad','NSCameraUsageDescription','NSPhotoLibraryUsageDescription','NSPhotoLibraryAddUsageDescription','NSSupportsLiveActivities','UIBackgroundModes']
report = {'app':{k:p.get(k) for k in keys}}
def shape(raw):
    raw = raw if isinstance(raw,str) else ''
    u = urllib.parse.urlsplit(raw.strip())
    return {'nonempty':bool(raw.strip()),'unexpanded':'$(' in raw,'scheme':u.scheme,'has_host':bool(u.hostname),'has_credentials':bool(u.username or u.password),'placeholder_host':u.hostname in ['example.com','yourdomain.com']}
report['url_shapes'] = {k:shape(p.get(k)) for k in ['API_BASE_URL','LEGAL_TERMS_URL','LEGAL_PRIVACY_URL','WECHAT_UNIVERSAL_LINK']}
wid = p.get('WECHAT_APP_ID','')
schemes = [s for row in p.get('CFBundleURLTypes',[]) for s in row.get('CFBundleURLSchemes',[])]
report['wechat'] = {'app_id_present':bool(wid),'unexpanded':'$(' in wid,'scheme_matches':bool(wid) and 'wx'+wid in schemes}
ats = p.get('NSAppTransportSecurity',{})
report['ats'] = {'allows_arbitrary_loads':ats.get('NSAllowsArbitraryLoads',False),'insecure_exception_count':sum(bool(v.get('NSExceptionAllowsInsecureHTTPLoads')) for v in ats.get('NSExceptionDomains',{}).values())}
report['extensions'] = []
for ext in sorted((app/'PlugIns').glob('*.appex')):
    e = read(ext/'Info.plist')
    report['extensions'].append({'path':ext.name,'id':e.get('CFBundleIdentifier'),'version':e.get('CFBundleShortVersionString'),'build':e.get('CFBundleVersion'),'extension':e.get('NSExtension'),'executable_present':(ext/e.get('CFBundleExecutable','__missing__')).is_file()})
privacy = app/'PrivacyInfo.xcprivacy'
report['privacy'] = read(privacy) if privacy.exists() else {'missing':True}
files = [f for f in app.rglob('*') if f.is_file()]
sizes = [(f.stat().st_size,str(f.relative_to(app))) for f in files]
totals = collections.Counter()
for size,name in sizes: totals[name.split('/')[0]] += size
report['package'] = {'file_count':len(files),'logical_bytes':sum(n for n,_ in sizes),'top20':sorted(sizes,reverse=True)[:20],'top_level_bytes':dict(totals)}
bad_dirs = {'DrillTutorials','Videos','Previews','content'}
bad_ext = {'.swift','.xcconfig','.p12','.mobileprovision','.cer','.pem','.key'}
report['suspect_paths_only'] = [str(f.relative_to(app)) for f in files if bad_dirs.intersection(f.relative_to(app).parts) or f.suffix.lower() in bad_ext or f.name.startswith('.env') or any(x.endswith('.xctest') for x in f.parts)]
(run/'package-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False,indent=2))
PY
```

```bash
du -sk /Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-b5-release-001/DerivedData/Build/Products/Release-iphonesimulator/球迹.app
```

二进制检查只输出命中的测试参数，禁止把全部 `strings` 发到会话。命令中路径为该轮 Release 产品；无命中是待结合源码解释的证据，并非全量不存在证明。

```bash
/usr/bin/strings /Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-b5-release-001/DerivedData/Build/Products/Release-iphonesimulator/球迹.app/球迹 | rg -- '^-(forcePremium|forceNonPremium|resetDebugPremium|v50\.inMemoryStore|deeplink\.silu|deeplink\.settings|w7\.forceDailyLimit|w7\.forceDailyLimitNear)$'
```

若需实际验证参数影响，主控另立执行号：新建无凭据 Release 专用模拟器，正常启动与显式参数启动分开记录；不能覆盖正式M1数据样本或宣称同一安装状态。用户已授权诊断，无需为普通可逆本机检查重复询问；本准备子任务没有执行安装/启动。

收口至少包括：真实构建退出码、产物检查JSON、大小、明确命中项、配置与产物差异、仍需真机/签名/真实服务验证项。SC37只能按已完成子范围标 partial；本轮不做发布判断。
