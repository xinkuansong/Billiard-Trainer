# 移除安装包中的旧模型 · 2026-11-16

状态：✅ 实现、真机平台构建与模拟器定向验证完成；手机尚未覆盖安装。用户本轮明确同意移除安装包内的旧版本，原资产保留。

## 范围与原因

现有真机 Debug 包实测 780,128,675 字节。其中默认球桌 119,558,458 字节，备用球桌 109,310,081 字节；原安排来自 [10 月 10 日可回退试用](MODEL-TRIAL-20261010.md)。本轮结束这项运行时试用安排，当前默认模型字节和缓存身份保持。

- `project.yml` 与生成的 `project.pbxproj` 排除旧 `TaiQiuZhuo.usdz`；该原件仍留在 `QiuJi/Resources/TaiQiuZhuo.usdz`。
- 配套旧球杆 `CueStyles/CueUV.usdz`（666,941 字节）移动至不打包的 `QiuJi/Resources/LegacyModels/CueUV.usdz`，补 Git 忽略例外以保留归档。
- `ModelAssetTrial` 保持现有类型名及默认文件名，移除旧开关和回退分支。历史 `modelAssetTrialUseOriginal=true` 不再改变资源选择。当前资源缺失时明确记录缺失并返回 nil。
- 旧诊断和资源测试改为当前生产模型合同；性能工具不允许把旧偏好误报成原版 A/B。
- 增加每次构建末尾的打包检查，覆盖配置真源、生成工程及真实 `.app`；6 项正反例覆盖丢失排除、恢复旧资源声明、过期工程、缺当前资源和子目录夹带旧资源。

本轮确定排除资源合计 **109,977,022 字节（109.98 MB）**。没有实施题库压缩或图片优化，也没有更换当前球桌、球杆、材质、网格或物理逻辑。

## 资产保留与身份

| 资源 | SHA-256 |
|---|---|
| 当前球桌 | `73e43df002f07637656b767fdc105033d10f0d764f6d91aa7a5276cf1c885fb6` |
| 当前球杆 | `9288907e666d897e4f3be5b94e7ec989eb5a75116f74a07d3790e4340f2e117e` |
| 保留的旧球桌 | `40b546a554257897c7df78df540b36b0ea3f1f2a3fc592c5d67306b3c632942b` |
| 归档的旧球杆 | `ad24d3696bc78a02cb3a08a9c09af5f04c657a79404754d8b555c744ba429e7f` |

## 验证与证据

- 打包门禁：`python3 -m unittest discover -s scripts -p test_verify_model_packaging.py -v`，6 项通过；源码与生成工程检查通过。
- 本机构建：受管目录 `output/local-test-runs/bcbb96e8dea740e4b09a3087c7a9fd30/`，当前工作文件先复制并逐文件核对至独占源码副本，再构建 iOS Debug、arm64、`-O`，关闭签名，仅验证构建与包体，不安装手机。
- Mac mini：作业 `model-package-20261116-r2`（r1 同快照留存）；快照 `233df5651ef66f7d90e9553a264331552ee022158a329dce8575b6275f2cb57a`；iPhone 16 Pro / iOS 26.2。目标为资源身份与包内原件缺席、旧偏好兼容、缺资源不回退、几何导入、16 球网格与原生渲染、两种相机下颗星位置。
- 真机平台 Debug 构建：`** BUILD SUCCEEDED **`，成品门禁通过，包体 **669,634,572 字节（669.63 MB）**。当前模型哈希与改动前一致，旧模型缺席，保留的旧资产哈希一致。原 780.13 MB 包与本轮无签名新包不是严格同源码／同签名 A/B，因此精确归因采用被排除资源的 109.98 MB，不把其余差值归入本轮收益。
- 本地受管构建已自动收尾，`run.json` 状态 `reclaimed`；源码清单、产物逐文件大小、模型哈希和构建日志保留于上述 evidence。
- 模拟器：`TEST BUILD SUCCEEDED` / `TEST SUCCEEDED`，实际 **6 passed / 0 failed / 0 skipped**。结果及逐方法核对见 `output/model-package-20261116/r2/evidence/test-summary.json`、`test-details.json`；包内两份当前模型SHA、旧资源缺席、旧偏好、缺资源反例、几何导入、每球2880面及2D/3D颗星断言均通过。
- 两张1000×1000正反向16球原生渲染图及启动首页已打开检查；未见缺球、缺材质或网格裂口。导出使用xcresult副本，原件未改；图片位于 `output/local-test-runs/e0346e7aa98549128440e6c6f7b92b62/evidence/attachments/`。这不是完整页面／真机画质验收。
- r1/r2证据均回传并逐文件哈希校验；两轮远端源码／构建及最终无引用快照已通过queue complete回收，r2临时模拟器登记为deleted。导图副本工作目录亦为reclaimed。本地构建目录收尾测得可用空间净增2,871,574,528字节（整机观测，不等同目录独占物理块）。
- 最终9个本轮实现／测试／配置文件与已验证冻结输入哈希一致；见 `output/model-package-20261116/final-audit.json`。
- 尚未执行手机覆盖安装、用户画质验收、全 App 回归、Release Archive 或 App Store 体积报告。

### 首轮环境拦截

r1 的 `TEST BUILD SUCCEEDED`，但 iPhone 17 Pro 类型已达容量上限，生命周期返回 `Managed capacity reached (8 total / 2 per type+runtime)`；**0 项测试执行**。现场实查远端共4台，未关闭或回收任何既有设备。通过同一FIFO队列用完全相同冻结快照提交r2，改用iPhone16Pro；r1原始失败保留于 `output/model-package-20261116/r1/`，不计作通过。
