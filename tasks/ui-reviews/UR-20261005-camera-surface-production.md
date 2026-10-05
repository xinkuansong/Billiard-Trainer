# DR-348 S2 生产默认接入验收（2026-10-05）

## 范围
用户试用S2后要求替换生产代码。每日清台普通Debug与Release默认使用曲面；其他宿主、导出相机保持原接入。S2数学与手势参数未调；CameraSurface仅更新说明注释，主要变更为VM默认配置与移除实验包激活函数。旧DEBUG参数保留历史对照。

## 验证
证据目录：`build/camera-surface-production-20261005/`。

- 普通工程Debug：`validation.log` / `validation.xcresult`，实际15项、0失败、TEST SUCCEEDED。9相机核心（含普通包默认/非每日隔离）、1 SceneKit动作唤醒/完成/空闲、5无相机功能参数的原生UI流程全部通过。
- 5原生流程覆盖近远/外沿绕桌/松手保持/俯视原姿态返回、45度斜拖与16pt反向、实际击球到下一杆、俯视选球/选袋再返回、自由球/线后自由球/禁摆三种权限及45pt非中心抓取位移。
- 专用iPhone17Pro模拟器（52B02877-CF83-425C-9196-88BA2B98E1E1，iOS26.3.1）。`screens/`共17张截图；已打开检查默认、外沿、俯视选球和下一杆4张原图，确认实际页面、球桌/球/控件呈现；截图不证明全域无遮挡。
- Release：通过Make包装的generic iOS设备build，`release-build.log` BUILD SUCCEEDED；无签名编译，不是签名归档/安装验证。
- `debug-identity.json`与`release-identity.json`：二者均为普通`com.xinkuan.qiuji`、显示名“球迹”，均无CameraSurfaceExperiment键；Release记录二进制哈希。
- `gate.log`、`doc-size.log`、`diff-check.log`：门禁/文档体积/空白检查通过。

注：截图名称沿用历史用例的surface-s1/merged-v5前缀，真实执行的是本轮普通包、默认S2；不能按文件前缀解释为旧实验运行。

## 交付边界
源码替换不等于上架发布。本轮未覆盖手机普通App；已安装实验S2保留。全域动态遮挡/杆身、跨尺寸手感与持续性能未作新验收，不关闭FL-094。
