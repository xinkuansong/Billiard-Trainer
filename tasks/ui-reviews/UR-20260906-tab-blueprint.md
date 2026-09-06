# 五 Tab 几何线稿背景审查（DR-114）

## 范围

用户确认将训练页现有线稿推广到其余 Tab。新增 `BTBlueprintBackground(style:)`：训练保留原构图，动作库/练习使用边缘瞄准圈、虚线与刻度，练习另有圆弧；记录无虚线，个人页只有瞄准圈与圆弧。颜色沿用 `btBG` / `btPrimary`，Dark 13%、Light 8%、1pt 线宽。背景固定在滚动内容后，不占内容布局，关闭命中与无障碍元素暴露。没有改动业务逻辑或真实球桌几何。

## 验证范围及状态

最终带页面身份断言的 **3 组检查全部通过**，使用同一份已编译 App/测试产物，源码在三组期间指纹未变化（`verified-source.json`）。测试选择器：`QiuJiUITests/ScreenshotTourUITests/testV47TabRootsHaveNoNavigationTitle`。

| 设备（iOS 26.2、标准字号、竖屏） | 外观 | 功能检查 | 视觉检查 | 日志 |
|---|---|---|---|---|
| iPad mini (A17 Pro) | Dark | 1/1，TEST SUCCEEDED；含 Debug 测试构建 | 5/5 页面，已目视 | `verified-ipad-dark.log` |
| iPhone SE (3rd generation) | Light | 1/1，TEST EXECUTE SUCCEEDED | 5/5 页面，已目视 | `verified-se-light.log` |
| iPhone 17 Pro | Dark | 1/1，TEST EXECUTE SUCCEEDED | 5/5 页面，已目视 | `verified-standard-dark.log` |

截图在 `output/tab-blueprint/verified/{ipad-dark,se-light,standard-dark}/`。三组各有五张独立页面原图；已查看全部联系表和关键页面原图。`audit-images.py` 核验15图数量、解码、尺寸、唯一哈希，以及边缘像素的真实Light/Dark亮度；结果 PASS，详见 `image-manifest.json`。最终无待修复的背景视觉问题。此次覆盖是三种代表性设备/外观组合，不是全设备×全外观矩阵。

- 基线：SE/iOS26.2 Dark，五 Tab 首屏，`before/se-dark`，1 UI 通过。
- 初版：SE Light/Dark 各1 UI/5图通过并目视，`after/se-*`。
- 并行账号文案变化后重新编译；标准手机 Dark 的 `final/standard-dark` 五图已目视。
- `final/se-light/tab-root-动作库.png` 实为训练页，**这组视觉未通过**，不算最终证据。旧“无导航大标题”测试不足以识别误页；补充每页真实可见内容身份断言，找不到时明确失败且不写截图，未放宽断言、未用旧图补齐。

## 视觉观察

已查看基线和初版原图，以及最终三组全部联系表和动作库/记录/我的等关键原图：新增图案只在留白及透明表面背后露出，原卡片大小与位置、文字层级、Tab 导航布局保持一致。训练构图保持原样。后续并行修改的游客提示文案已出现在标准手机重新编译版本中。

## 执行环境及证据边界

使用本轮独立创建的模拟器与 `output/tab-blueprint/DerivedData`。原工程并行测试时标准手机启动阶段长时间未进测试；主动终止本轮等待的进程，保留日志。临时工程最初放 `/tmp` 时配置路径不正确，没有找到 destination；保留该失败，改为仓库根旁的独立工程包与正确 scheme container 后编译运行。临时工程仅作验证，已移至 `output/tab-blueprint/runner-project/`；正式工程仍由 `project.yml` / XcodeGen 管理。

本轮期间有其他任务修改账号/云同步代码。背景及五个接入页面以各次指纹记录为准；不将本轮背景截图和 Tab 导航测试外推为账号同步、真实登录、StoreKit、VoiceOver 实听或真机验收。

## 变更审计

仅新增共享组件、五个根页背景接入、复用导航测试的内存数据/外观前置及截图/身份核验、XcodeGen 文件注册、设计说明与进度。工作区原有与并行改动保留；本报告不将其他任务的账号文案、RootView、网络与同步改动归入 DR-114。未 commit/push。

文档体积门禁与本轮代码空白检查通过。旧的缺身份断言/中断/路径配置失败证据保留，不计入最终3组通过结果。
