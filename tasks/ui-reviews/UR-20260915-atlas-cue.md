# 两图谱球杆显示（2026-09-15）

范围：角度与瞄准 → 学 → 分离角图谱、加塞吃库图谱。

两个 VM 原先在 updateAimVisualization 无条件隐藏球杆。现复用 currentIntent 的世界系瞄准向量与 AngleTrainingScene.updateCueStick；拖球时隐藏、松手刷新，无有效目标时隐藏。加塞吃库的参考杆采用当前 spinY、spinX=0，八档左右塞对比仍由原轨迹表达。没有改相机、物理预测、轨迹颜色或页面布局。

## 验证

- 最终 `make -f scripts/Makefile build`：BUILD SUCCEEDED，日志 `build/atlas-build.log`。

- iPhone 17 Pro / iOS 26.3 / 402pt，默认深色工具页，实际页面改前与改后 2D/3D 截图在 `output/atlas-cue-20260915/`。
- 两页改后 2D/3D 四张原图已逐张目视：球杆可见、杆头在母球后方，与瞄准线对齐；原轨迹和控件位置保持。
- 改前日志：`build/atlas-before.log`、`build/atlas-cushion-before.log`。两项既有 S2 Atlas3DRoundTrip 均在第595行失败：实际宽度 43.99999999999994 < 44。该失败发生于本次修改前，保留原测试断言。
- 改后回归日志：`build/atlas-after.log`；执行2项，均复现与改前相同的第595行浮点精度失败；2D/3D切换与轨迹开关在该失败之前执行，后续交互没有执行。
- verify-gate / verify-doc-size 与 git diff --check 通过。

## 边界

未验证真机、小屏/iPad、完整拖球/换目标/高低杆操作流程。加塞页顶部读数横向超出在改前已存在，本次未改布局。整页完整视觉验收未闭合，本次仅核验新增球杆。
