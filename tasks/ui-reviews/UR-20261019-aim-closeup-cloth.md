# 瞄准特写台呢更新 · 2026-10-19

状态：实现、构建及定向验证完成；尚未用户验收。

用户要求替换特写背景为当前正式台呢。旧版绿底是固定RGB(25,111,18)，其他颜色直接使用albedo；没有新版材质光照。已在修改前原生截图确认明显暗圆底。

实现：共享Overlay预取TableFigureRenderer的liveReference纯台呢近景，使用当前台呢颜色及球房；复用有上限缓存，定位刷新不重渲染，不保留第二个实时场景。原球/线/放大和避让不变；教学图片仍默认plainLegacy。

坐标：SceneKit X–Z平面、Y向上、米制；取样中心(0,innerWidth/4)，半高R×3.2，边界数值为X±0.09144m、Z[0.22606,0.40894]m，完全位于台内且避开中心置球点。背景是材质样片，不伪称当前球形实时截图。

证据目录：`output/aim-closeup-cloth-20261019/`。

- before：旧构建成功；首次UI断言在280ms保留期内立即要求隐藏而失败，原日志/录像保留。video-frame.png可见旧暗绿圆底。
- before-r2：实际持触截图已获得；隐藏等待通过，后续旧测试导航未打开设置菜单就找视图按钮而失败。仅修正新测试的导航，生产显隐/菜单未修改。
- after：App及测试目标构建成功；首次runner启动被模拟器Busy/preflight拒绝，无产品测试结果。after-r2重启脚本遇到已关闭设备，已改为先读取状态。
- after-r3：沿用上述最终构建，1项原生UI通过，绿色/赛事蓝×2D/3D共4张持触原图均已逐张查看；松手隐藏检查通过。设备为iPhone17Pro/iOS26.3，UDID `3CD07A23-44BA-4641-90AA-65408ADC6C11`，借用前为Shutdown。
- 单测：`unit.log` 的4项全部通过。覆盖6色赛事球房、绿色另两球房共8组独立场景对SwiftUI背景的像素比较；最大通道差约1/255，原阈值0.05未放宽；另覆盖颜色/球房/历史配方缓存及坐标映射。
- 单测结果：`build/AimCloseupCloth20261019/Logs/Test/Test-QiuJi-2026.10.19_17-35-46-+0800.xcresult`；UI结果：同目录 `Test-QiuJi-2026.10.19_17-33-31-+0800.xcresult`。

视觉核对：新版绿色不再呈明显暗色圆块；赛事蓝保留可见细纹理，圆内球、假想球及虚线清晰。2D背景与主台呢更一致；3D使用同源俯视材质样片，不模拟当前机位的透视光照渐变。未见置球点、球影或库边混入背景。

[前后裁切对比（左旧、右新）](../../output/aim-closeup-cloth-20261019/before-after.jpg) · [绿色2D](../../output/aim-closeup-cloth-20261019/after-r3/cloth-green-2d-landscape.jpg) · [绿色3D](../../output/aim-closeup-cloth-20261019/after-r3/cloth-green-3d-landscape.jpg) · [赛事蓝2D](../../output/aim-closeup-cloth-20261019/after-r3/cloth-tournamentBlue-2d-landscape.jpg) · [赛事蓝3D](../../output/aim-closeup-cloth-20261019/after-r3/cloth-tournamentBlue-3d-landscape.jpg)。裁切仅用于对比，原始PNG保留。

收尾：文档体积及本任务diff检查通过；已通过生命周期入口将借用模拟器恢复Shutdown，数据与原有保护保留，租约已释放。源码哈希见证据目录 `final-source-sha256.json`。

未安装真机、未提交或发布；不代表全App回归或持续性能验收。
