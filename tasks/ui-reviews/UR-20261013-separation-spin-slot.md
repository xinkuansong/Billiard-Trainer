# 分离角图谱禁用打点盘 · 2026-10-13

用户要求补回右侧打点盘，并采用不可选样式，解决力度条位置上移。

## 实现

无打点操作时，原仪表柱直接删除入口。现在通过默认false的showsDisabledSpinEntry显式保留圆盘、标签、原尺寸和间距；只有分离角图谱开启。无操作闭包的圆盘按HUD禁用透明度显示，并disabled；原力度绑定、量程与左侧八档开关不变。无额外offset或页面专用坐标。

## 验证与限制

- Debug构建：BUILD SUCCEEDED，日志output/separation-spin-slot-20261013/build.log。已安装到Daily-Fix-Phone-20261009（iPhone 17 Pro，iOS 26.3）。
- verify-gate：FAIL 0；verify-doc-size、定向git diff --check通过。
- 已目视改前用户图、改前模拟器图和改后原生图；改后可见灰色圆盘与其下方杆速柱。初次改后模拟器保持竖屏；其他测试结束后，经Simulator方向按钮恢复横屏，已目视灰色圆盘/标签在杆速尺上方、球桌大小保持。最终横屏证据after-landscape.png。
- 已扩充现有testSeparationAtlas3DRoundTrip：断言圆盘存在/禁用、点击不能展开，并保留力度拖动及相机往返；相机定位断言改取实际powerShell（不再取含新增圆盘的整列）。
- 本次XCUITest未执行：资源编译报No space left on device / Failed to write to CAR，TEST FAILED。未删除其他任务缓存或中断其他任务；其他原生UI测试占用共享Simulator界面期间不抢焦点旋转。
- 尚待：紧凑屏截图、实际点击与拖动回归、3D往返；未安装真机、未提交发布。

证据目录：output/separation-spin-slot-20261013；before/user.png、before/native.png、after-settled.png、after-landscape.png。下一步为磁盘空间恢复后重跑现有定向UI验证。
