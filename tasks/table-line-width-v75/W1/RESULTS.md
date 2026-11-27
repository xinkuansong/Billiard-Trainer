# W1 验收通过 · 2026-11-27

共享实例线宽已落地，Composer交互入口显式采用4.5/4mm。全局旧常量、图解/导出默认、通用原语6mm及细标记保留。覆盖清单见../COVERAGE.md。

- 改前：V75LegacyCaptureTests 1/1通过（5.638秒），受管run b7836e3fbf3e4a4faf5b48af660d85c9。
- 改后：3项实际几何/兼容测试、1项图解采集、1项真实页面UI测试，共5/5通过；日志after-build.log、after.xcresult。
- 实际网格检查4.5/5.6mm、默认原语6mm、显式细线2mm，2D/3D切换及重建保持。
- 两张完整页面图已目视；与用户选中B档的输入/相机字段一致，见same-condition.json。
- 图解/共享场景前后均已目视；解码像素差：图解2个通道、场景4个通道各最大1色阶；非整图字节相等，未见线宽变化。原图分别在before-images/after-images。Python缺PIL的比较未执行，改用compare.swift的CoreGraphics解码，不修改原图。
- 真机未验。W2依赖就绪；受管工作目录为后续批次明确保留，结束统一complete。
