# 每日清台标题简化（2026-10-05，DR-335 r2）

按用户截图要求移除返回区域页名下的小字：删除dailyLandscapeHeader的开球/aimSelectionLabel行，标题保留原字体、单行缩放与外部布局。2D/3D共用；不改变选球、模式或规则。PocketLeatherFlowUITests原读取该小字的断言改为确认不存在，原HUD“自由模式”断言保留。

## 功能验证
- 最终源码与UI测试包构建成功；focused.log为TEST SUCCEEDED，实际执行2项/0失败：testFirstEntryWaitsForManualBreakAndAllowsInputChanges、testS8BreakFarthestThirdPersonAfterRerackAnd2DToggle。覆盖开球参数操作、重摆和2D/3D往返。
- 首轮旧testLandscapeEntryPaletteAndPortraitReturn在第744行要求HUD包含“2 杆”失败；保留after.xcresult与test.log，不修改/放宽该统计断言。本轮未定位统计夹具问题，不能宣称全部回归通过。
- PocketLeatherFlowUITests断言变更已编译，未执行整条选袋用例。diff空白检查、verify-doc-size通过。

## 视觉核对
- 标准手机模拟器Camera Surface S1（iOS26.3，1206×2622原生截图旋转横屏）实际2D/3D原图已打开检查：左上只有返回箭头和单行“每日清台”，无开球/球袋说明；页名未截断，与返回箭头居中对齐，球库及左右控件保持。
- 修改前本轮simctl启动截图仅白色启动页，不作为有效页面证据；改前界面以用户提供截图为依据，与改后不是同球形/同相机对照。
- 2D：build/daily-title-20261005/focused-attachments/3F7B3693-EFE0-47DC-9848-D3156B16258E.png
- 3D：build/daily-title-20261005/focused-attachments/DF9EF523-3B8D-49C4-A59F-747C47F0B186.png
- 小屏与真机未复验；未安装手机、提交或发布。
