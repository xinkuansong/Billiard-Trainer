# 合成照片正常入口执行记录

2026-09-08。PHOTO-004-PREPARATION主控已全文审核；合成1000×800图及实际SHA/四角/接触点manifest在archive/quality-diagnosis/inputs/photo-004-synthetic-001，完整图已目视。新设备QD004-Photo-20260908，E19E17B9-F412-49D1-9BE0-EB12E58FC8F2；create/bootstatus成功，只用simctl addmedia导入此诊断图，import.json留存。未读取用户相册/未登录；forcePremium仅隔离功能门控，inMemory保护App数据，无confirmDemo/marks注入。

正式photo-picker001正在执行（session55917），仅普通练习→打→拍照建球形→系统选择器发现检查点。注册诊断类，xcodegen后原三个scheme字节恢复。尚未图审或计通过，后续取消/选图/四角/球标/送工具必须分别有真实证据。

photo-picker001实际1/1通过28.664秒，69文件/observer归档；入口和系统照片选择器完整PNG/AX已审。专用新模拟器自带6张风景样图，加本次导入共7张；本次诊断图已按外观和实际AX日期9月08日17:03唯一识别，不选用户图、不按索引。新增QD030 P2自动提取承诺与手动契约/实现不符。photo-select001正在执行正常取消/重新选诊断图→标定。

photo-select001实际取消→step1空输入通过；方法1失败46.145秒发生在系统Image缩略图的通用exists/hittable/enabled谓词，尚未点图。完整终态PNG/AX已审，诊断图仍唯一，框(0,292,132.9,133)不变。1339文件与observer归档，runner2/recorder0；不判产品加载失败。002独立方法不重复取消，仅严格核唯一label/当前frame并记录isEnabled/isHittable，按该已核图框中心点击，保留全部标定判据。

photo-select002实际1/1通过26.454秒，73文件及observer归档，runner/recorder均0。缩略图exists=true/enabled=true/hittable=false；按唯一标签和实框中心点击后实际合成图进入标定，完整PNG/AX已审。图片框(12,295,378,302.3)与内容一致，默认四角梯形可见。photo-calibration001使用当前唯一同尺寸Image再测frame，以像素规范的uv算四个内沿角，手势后每个标签中心+24点与目标≤2点，长库选中/进入空标球页严格判据，运行中。

photo-calibration001实际1/1通过32.175秒，85文件及observer归档，runner/recorder均0。四次正常拖动后实际标签中心+24与目标均≤2点；主控完整四角和空标球两张PNG及AX已审，四角确贴内沿，长库选中，已标0/下一步禁用。此不是精确奇异/短库/物理精度证明。marks001按当前标球页实际AX容器(12,178.7,378,528)和源码aspect-fit算显示图，以合成接触点uv(.3,.35)/(.7,.65)点击；实际标两球/撤销重做/确认继续运行。

photo-marks001实际1/1通过45.277秒，105文件/observer归档。正常母球/1号两次点击计数0→1→2，撤销1/重做2，进入确认页；主控三张完整标记/重做/确认PNG及AX已审，照片十字对应两球，确认页桌上2颗，黄1在右上/母球左下。此为长库正常映射相对位置，未冒称精确UI归一化坐标。send001继续当前正常全链后，点桌上1→球库2改号保位，再分别送自由走位/思路训练/打一走二想三及返回，运行中。

send001实际1失败44.133秒，1403文件及observer归档，runner2/recorder0；点台面1并点球库2后真实终态图为蓝2/母球，已选2，位置近原点。失败是旧_1 AX节点仍存在：旧父框扩至球台大小、隐藏子框残留，不可拿exists当可见球仍存在。主控完整终态PNG/AX与assignNumber隐藏旧球/显示新球/refreshKeys代码已核。原断言和失败保留，不删成绿；独立send-original001只用原母球+1号正常盘面验证三个目的地/返回，改号行为局部图证与完整改号发送尚未达严格区分。


photo-send-original001实际1/1通过77.721秒，1381文件及observer归档，runner0/recorder0。正常选合成图→四角→母球和1号标记→撤销重做→确认→自由走位/思路训练/打一走二想三分别送入及返回全部到达；主控四张完整目的地/返回PNG已审，均为母球左下、黄1右上，返回仍桌上2颗。仅证明原两球盘面正常交付及相对位置，不证明精确坐标、解算/击球、改号后交付；短库/奇异标定、确认编辑和图片查看器仍待。SC27保持partial。
