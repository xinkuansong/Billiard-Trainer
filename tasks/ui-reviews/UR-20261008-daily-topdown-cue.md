# 每日清台：3D 内临时 2D 俯视显示球杆

日期：2026-10-08。用户明确指 3D 模式中的临时俯视叠层。

## 原因与修改

`AngleTrainingScene.synchronizeTemporaryTopDownScene` 在复制临时俯视场景时明确排除了 `cueStick.rootNode`，因此主场景有杆，临时俯视没有杆。

删除这一项排除，让球杆使用现有递归同步：真实模型、presentation 变换、显隐、透明度与材质跟随主场景；geometry 继续独立复制，动作仍只在主场景运行。常规 2D、相机、球桌尺寸与 HUD 布局没有本任务改动。保留工作区原有的其他修改。

现有场景复制测试由“球杆不存在”改为核对真实可见球杆树，检查几何缓存独立、网格与材质一致、变换相同及源场景未被修改；没有删除其他约束。

## 功能验证

- iPhone 17 Pro / iOS 26.3 / 横屏 / 系统字号 large。
- `Daily3DClothPerformanceTests.testTemporaryTopDownSnapshotCopiesRealPocketMarkersWithoutSourceWrites` 通过，最大世界变换元素误差 0。
- `Daily3DClothPerformanceTests.testS8IndependentOverlayMeshMatchesNativeImportedGeometryPixels` 通过，原生网格复制像素 MAE = 0。
- `DailyAdaptivePanelUITests.testC54ActionStatesAndFourCameraRoundTrip` 通过：3D 四视角、第一人称进入临时俯视、退出恢复、击球、回放及重打。修前同项也通过，用作外观对照。
- 最终 3 项零失败，`after/test.log` 包含 `** TEST SUCCEEDED **`。`verify-gate` 通过。
- `make -f scripts/Makefile build` 通过，`build.log` 包含 `** BUILD SUCCEEDED **`；`verify-doc-size` 与 `git diff --check` 通过。构建脚本因本机没有 xcpretty 自动使用既有原始输出回退。
- 首轮修前取证因调用时漏传 `DAILY_LAYOUT_CONTENT_SIZE` 在测试夹具处失败；补入实际 `simctl ui content_size` 读回值 large 后，以相同源码重跑通过。原失败日志保留在 `before/`，有效基线在 `before-r2/`。

## 视觉审查

已打开同一 selection 球形、同一入口的原生前后图，以及改后返回 3D 原图。改前母球后方没有俯视球杆；改后皮头贴近母球，完整杆身沿当前瞄准方向延展，台外部分仍绘制在原有半透明 HUD 下方。球桌、球位、轨迹和控件位置保持；主场景的球杆及返回后的 3D 视角正常。

- [改前](../../output/daily-topdown-cue-20261008/before.png)
- [改后](../../output/daily-topdown-cue-20261008/after.png)
- [返回 3D](../../output/daily-topdown-cue-20261008/returned-3d.png)
- [测试日志](../../output/daily-topdown-cue-20261008/after/test.log)

完成范围为代码与上述模拟器验证；未安装真机，真机体验待用户复看，未提交或发布。
