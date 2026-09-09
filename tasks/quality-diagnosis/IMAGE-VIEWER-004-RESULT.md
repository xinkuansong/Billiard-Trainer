# 图片查看器正常入口与手势诊断结果

2026-09-08 图片查看器正常c001观察003 1/1通过36.923秒（82文件）；双击放大/复位已图审，但gesture001拖动失败52.700秒（1391文件）、无缩放普通左滑swipe001也失败54.802秒（1393文件），均停1/6。后一轮实际关闭并恢复原精讲位置≤2pt通过；整方法仍失败。主控7张关键完整PNG复核，五run及observer全部归档。登记QD033 P2交互异常、根因/真实触控未确认，详IMAGE-VIEWER-004-RESULT.md。

同一新隔离249B8998-B4A5-4F3C-ACED-173D0C290355、iPhone17Pro/iOS26.2、Light/large；普通游客库搜索半台直线球→c001详情→精讲→开局图，无Pro强制，无深链/媒体注入。inMemory用于隔离。六图来自同一球形的真实Bundle图集。

| run后缀 | 实际结果 | 裁定 |
|---|---|---|
| image-viewer-observation-001 | 1失败24.663秒，1427文件 | 库三个ScrollView被草稿错误要求唯一；只到搜索卡。 |
| image-viewer-observation-002 | 1失败40.825秒，1337文件 | 已到精讲；AX图片按钮继承tutorialSection标识，未暴露tutorialPoster标识，草稿未定位首图。 |
| image-viewer-observation-003 | 1通过36.923秒，82文件 | 实际首图打开，全屏1/6，初始五目标球+母球、caption正确。只观察，不算手势验收。 |
| image-viewer-gesture-001 | 1失败52.700秒，1391文件 | 双击放大、再次复位完整图证成立；坐标水平拖动后12秒仍1/6，没有到达关闭步骤。 |
| image-viewer-swipe-001 | 1失败54.802秒，1393文件 | 不经过缩放的CollectionView.swipeLeft也保持1/6；继续点击关闭、回精讲、首图滚动中心≤2pt保存均通过，最后保留翻页失败。 |

每个run前缀formal-004-，runner与录像器已终止，所有原tested-sources/选择器/xcresult/日志保留。每个观察目录6文件有SHA。新正常左滑对照没有删除原gesture001失败证据；两个入口定位失败不当产品缺陷。

主控PNG审查：初始全屏台面与精讲同一六球图；放大图球和地标明显放大且台面被裁切，复位恢复适配六球全图，未仅靠截图hash判断缩放；无缩放左滑仍同一首图及1/6。关闭回原初始图段，页码/关闭控件消失，首图位置保持。本批未取得第二张图/2/6，因此不能声称切图成功或全图集不串图验证完成。

真实AX CollectionView(0,0,402,874)，媒体Image(0,68.3,402,715)；关闭xmark.circle.fill/关闭。原gesture使用图内(332,425.8)→(70,425.8)一次拖动；独立swipe用实际CollectionView的标准swipeLeft，日志36.94秒Swipe left/36.97秒Synthesize event，12秒后页码仍1/6。关闭在51.04秒事件后正常返回，说明当时并非整个App失去响应。

QD033仅确认当前模拟器两种自动化输入下横向分页未达。DrillTutorialView的TabView.page与ZoomableContainer同时挂drag/magnification/doubleTap，为候选手势竞争调查路径；没有独立实验确认唯一根因，不能直接说simultaneousGesture一定吞掉分页。真实触控、其他Runtime未验；解锁后的单次手动对照留给后续核查，不无界更换手势追绿。

证据在archive/quality-diagnosis/runs/各run与observations/各run；主控7张完整图SHA在observations/image-viewer004-review.json。连续视频保存，未逐帧量化。5350冻结输入19:47:39复核改变0/缺失0，source-recheck-silu-viewer001.json。
