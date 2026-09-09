# 照片四角退化与改号交付结果

2026-09-08，snapshot004，SC27。既有专用E19E17B9-F412-49D1-9BE0-EB12E58FC8F2及原合成图；图片SHA保持6edb335b50b642b898e741d75eedd6bee9ab6805afe18dfd77bed4f5091032f3。inMemory训练库/forcePremium仅隔离本批和开放入口，不是相机采集或权益验收。

| 运行/方法 | 结果 |
|---|---|
| photo-boundary001 / intendedCollinear | 1/1通过33.904秒，实际四角拖后下一步disabled，保持标定页 |
| photo-boundary001 / renumber | 失败48.094秒，选中2号时状态栏没有总球数文字，未送入工具 |
| photo-boundary002 / renumber | 1/1通过63.566秒，正常取消选择后验原两球数，改号送入自由走位并正常返回 |

001整体make2/recorder0，1459文件归档；002 make0/recorder0，1341文件归档。原选中态失败是测试前提失配：BallExtractionView的选中分支显示“已选2号”，未选中才显示“桌上2颗”；独立补验仅加入同一实际球再次点击取消选择，没有删掉球数断言或改业务。旧PhotoImport send001隐藏mesh的exists失配也不覆盖。

主控总计复核5张关键完整PNG：001退化拒绝、001改号失败页，002改号取消选中/自由走位交付/返回。三张正常链均看到蓝色目标球和母球、台面无黄色1号球；AX实际_2根节点和两颗计数对应。前后母球左下、目标球右上，改号前后实际球屏幕中心误差≤2pt。不同页面相机布局可不同，不以像素绝对坐标相等判跨页位置。

四角负例为一次意图共线输入，实际AX中心x均201pt、完整图四角在竖线上、下一步禁用、未进入标球。本次说明此手势输入被正确拒绝；未直接读取内部uv精度，不扩称所有近退化输入均有合理阈值。数学精确退化判例与既有HomographyTests分层保留，不为本条重复全套。

证据：[001原失败与拒绝原件](../../archive/quality-diagnosis/runs/formal-004-photo-boundary-001/)、[002交付返回原件](../../archive/quality-diagnosis/runs/formal-004-photo-boundary-002/)、[五图SHA复核](../../archive/quality-diagnosis/observations/photo-boundary004-review.json)。两观察目录含视频及SHA；002 xcresult为Test-QiuJi-2026.09.08_19-23-46-+0800.xcresult。

原两球三个工具交付已复用，本条仅补改号后一个目的地，不重复三工具。SC27继续partial：真实相机/硬件、其他未覆盖输入与原B6图片查看器等仍按范围表；不是照片功能全验收。未新增产品缺陷。
