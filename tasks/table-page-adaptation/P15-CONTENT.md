# P15 · 内容内嵌球桌与输出消费者

范围：DrillDetail/DrillRecord→DrillSceneView；BTPracticeCover→BTTableFigure；外观组合预览以及离线DrillThumbnailRenderer/TableFigureRenderer/BallFaceRenderer/SequenceVideoExporter。保留只读展示、球形选择、杆边界暂停/继续、试打入口及原内容坐标。不向内容小卡加入15槽/双尺/相机HUD，不批量重烘焙静态资产。

详情实际入口before与试打转场纳入下一原生矩阵；渲染器按plain/mobile/studio用途记录，固定输出尺寸不是响应式UI缺陷。共享BTTableFigure投影更新通过P11验证，内容卡需复核。before源码位于output/table-page-adaptation/P15/r01。

手机/iPad详情→试打旧入口通过并已目视。已将详情/录入正文和球桌宽屏限制720pt，复用iPad方向控制；只读回放保留28pt图标并扩至44pt命中。下一轮验证2D/3D/全桌/杆边界暂停/试打与实际录入页嵌入球桌（内存数据，不保存）。离线plain/mobile/studio参数与烘焙资产保持，独立固定镜头预览无需操作HUD。

最终验证入口：`output/table-page-adaptation/P12/r01/final-r4`；生产版本与source-after-r4指纹对应。P12手机/iPad见final-r2，P13/P14及详情手机/iPad见final-r3，训练记录见final-r4；小屏除内部目录补验外已通过，未安装真机或提交发布。

### 本轮收口
工程与三设备定向验证已完成，原图已审；最终证据索引见output/table-page-adaptation/P15/r01/REPORT.md。未验边界明确保留，无需等待逐页认可才能完成本次连续授权。未装真机、未提交发布。
