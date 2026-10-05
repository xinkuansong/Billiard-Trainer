# 打点盘手指防遮挡（DR-335 r8，2026-10-05）

根因：旧BTSpinPad将每帧手指绝对位置直接转换成打点，因此红点始终在指腹下，起手也会跳到触点。参考AngleSceneView既有52pt一次性启动区与固定偏移跟随，不修改球拖动。
实现：起手冻结现有红点；先移开手指52pt，再同向等量移动；反向保留偏移；轻点松手选位。保持打滑极限、杆可达约束与方向键。

验证：build/spin-finger-clearance-20261005/verify.log及xcresult：12项单测、1项含2D/3D原生交互通过，覆盖起手/跨阈值连续、反向固定间距、轻点与短拖区分、新手势复位、屏幕符号和圆界/锁轴扫描。build/daily-spin-glass-20261005/final.log补验4项杆可达原生测试全部通过（近库限制低杆、近库/后方贴球完整高杆、空间充足完整低杆）；旧测试拖动长度增加52pt启动行程，最终断言未放宽。
图像基线：output/daily-spin-neutral-20261005/settings-2d.png（原点选盘面）。output/spin-finger-clearance-20261005/spin-finger-clearance-{2d,3d}.png两张拖动后原图已审；不能用模拟器代替真机手指舒适度。
