# P13 · 拍照建球形与批量提取

连续授权范围为原图/四角标定/号码标记/真台确认的容量与旋转；保留单应变换与编辑坐标，禁止更换图片/识别算法。普通拍照向导和批量向导分别追踪，确认页仍使用同源AngleSceneView及autoFitsRotatedTable。母球在这里是照片标记/编号对象，需保留编辑入口；不套击球页的15槽与自动回台。没有开球、FPS或球杆速度业务，不增加这些操作。

先以现有确认fixture、实际批量入口采集before；不请求睡眠用户照片权限、不选私人照片、不保存或覆盖内容。复用DailyTableOrientation的iPad双方向能力，验证旋转后标定位置/已选号码/确认球形保持及撤销重做。源码before位于output/table-page-adaptation/P13/r01。

改前手机/iPad确认页交互已采集，保留包含母球的编辑球库。已补iPad双方向与黑底暗色token，撤销/重做语义及44pt命中；新增验证覆盖加球→撤销→重做→横竖→送入自由走位保持编号。四角单应5项既有单测随最终矩阵；不触碰识别算法和私人照片。

最终验证入口：`output/table-page-adaptation/P12/r01/final-r4`；生产版本与source-after-r4指纹对应。P12手机/iPad见final-r2，P13/P14及详情手机/iPad见final-r3，训练记录见final-r4；小屏除内部目录补验外已通过，未安装真机或提交发布。

### 本轮收口
工程与三设备定向验证已完成，原图已审；最终证据索引见output/table-page-adaptation/P13/r01/REPORT.md。未验边界明确保留，无需等待逐页认可才能完成本次连续授权。未装真机、未提交发布。
