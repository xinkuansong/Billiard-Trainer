# B1 验收（2026-11-26）

默认扎杆新题25°、跳球45°；三页横滑观察，方向尺调整杆向；侧看时复用updateP01TargetCue保留可见机位。示范/自由页回放显式启用共享滚动观察，其他页面默认回放合同不变。

受管运行b625c03eb4164697995571889a98ec87：b1-before原生基线1/1通过；b1-after-r1两个真实VM方法和两个UI方法4/4通过，覆盖三页与两模式示范；b1-phone紧凑iPhone SE/iOS17原生三页方法1/1通过。verify-gate通过。原始日志/xcresult位于该run的evidence。

已检查iPad五张侧看/示范图及手机三页侧看图，角度、方向线、控件与观察姿态可读。图片导出目录b1-before-images、b1-after-images、b1-phone-images，manifest保留原图，*-preview为等比缩览。几何公式/渲染未改变；TP17/18/23/25局部复核。真机手感及用户认可未验。

源码身份见b1-source.json。B1依赖满足，进入B2。

补充兼容复核：旧SpatialPracticeRecoveryTests全桌观察→方向尺回沿杆测试发现保留overview回归；已将overview分支交给现有followP01TableAim，其余侧看继续保留眼位。b1-compat-r1两方法2/2通过。首次补丁有Swift空白解析错误，修复后构建通过；失败日志均保留。
