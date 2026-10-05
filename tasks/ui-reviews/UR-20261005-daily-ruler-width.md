# 每日清台标尺略加宽（2026-10-05，DR-335 r3）

## 修改
仅每日清台2D/3D：两条内尺28→32pt、外框40→44pt。共用dailyRulerWidth；力度组件新增默认28的compactPowerBarWidth可选参数，其他页面仍保留原宽度。144pt滑动行程、60pt侧栏、原触摸区域、灵敏度/速度曲线/触感保持。

## 功能验证
标准手机Camera Surface S1 / iOS26.3：构建成功，2项原生UI通过（standard.log，TEST SUCCEEDED）：手动开球参数调整及3D重开/2D往返。小屏Temporary Shot Camera SE / iOS26.3：同一构建test-without-building执行2项/0失败（compact.log，TEST EXECUTE SUCCEEDED），覆盖开球力度/打点调整及2D/3D方向条拖动后恢复静止。共4次测试执行、3个唯一用例。源码diff空白检查通过。

## 视觉审查
改前基线为同一聊天前一轮daily-title-20261005/focused-attachments中的2D/3D原图，本轮两张standard-attachments最终原图已打开目视。左右标尺同步稍宽、刻度/手柄正常、文字无截断，侧栏/球桌/其他按钮不因本轮变宽而位移。并发任务另改2D背景为地毯，这不是本轮宽度修改，也不据此认定整图像素等价。
- 标准2D：build/daily-ruler-width-20261005/standard-attachments/15265E14-8CDF-4F85-BF12-53D9FC5EDDCA.png
- 标准3D：build/daily-ruler-width-20261005/standard-attachments/BBA24AEC-F690-40A1-A216-CA48C1D0E345.png
- 未安装手机、提交或发布。真机手感仍待用户体验。

小屏2D/3D最终原图已打开目视，标尺宽度一致、读数无截断，2D侧栏不侵入台框；仅验本轮控件布局，不对已有3D取景裁切作新验收。小屏图位于compact-attachments/DFC78F88-E920-4B5C-BF7C-7CE6FBF5A315.png和D5779D55-14D6-4A88-9B9C-10983CC3E648.png。
