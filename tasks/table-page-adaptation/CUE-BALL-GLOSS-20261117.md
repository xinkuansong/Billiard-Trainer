# 白球抛光效果试看 · 2026-11-17

用户要求：“先修改白球，我看看效果吧”。根因是正式自定义着色器白球使用0.34，号码球使用0.05。此次把白球改为0.05；保留浅象牙白底色、红点、B档显示曲线、灯光、反射探针、库边和物理。

## 范围与验证

- 共享入口：MobileReferenceLighting.makeBallSurface → applyBall；AngleTrainingScene.enhanceBallMaterials及后续球实例走现有入口。只调整参考渲染的非号码球表面参数；旧版渲染不变。
- TP29按用户反馈调整材质；TP16/17继承生产相机行为，本轮只用生产Pose构造静态近景；TP35使用同场景同机位0.34/0.05对照、非白球区域零差、恢复零差检查；TP36记录试看状态，不当作用户已认可。
- 使用SceneKit世界米制，X–Z水平、Y向上；球心高度沿用surfaceY + ballRadius，三球中心在X=-0.16/0/0.16、Z=0。近景用TwoViewCamera.Pose.looking并检查实际forward朝向台面中心。未修改生产相机或球形。
- 技术before：output/cue-ball-gloss-20261117/before-MobileReferenceLighting.swift，包含本轮之前已有B档改动。
- 受管原生Mac SceneKit作业：da872bbed64f464f9270ec7a8c140d1f。全台、近景、俯视1600×1000；白球、15号、2号同场。
- 当前：构建与原生出图完成。未安装手机、未测最低iOS设备/动态镜头/温升；本次只复用已用于号码球的着色公式和0.05参数，没有新增Metal语言/API。

## 实际结果（北京时间08:18）

原生Mac / Designed for iPad构建成功，XCTest 1通过、0失败、0跳过。三视角变动像素为575/6423/160，非白球区域变动均0；恢复旧参数逐像素一致，无shader错误色。冻结源与执行源一致，生产文件当前SHA与已测SHA一致（0c449e6c2e0f433b0e0fc02c106051cb23499ab6bcc8d5c95ce97a4df8bfe524）。

已查看三组完整对照、近景原图和同范围原尺寸裁片。白球上方可辨清楚灯面高光，号码球和库边保留原画面。俯视图为离屏采集，黑色外围不是正式页面地毯变更。仅静态视觉范围，不能代替手机转镜头/温升验收。

[近景细节](../../output/cue-ball-gloss-20261117/ball-detail-comparison.png) · [完整近景](../../output/cue-ball-gloss-20261117/close-comparison.jpg) · [数据](../../output/cue-ball-gloss-20261117/cue-gloss-preview.json) · [原始日志与结果包](../../output/local-test-runs/da872bbed64f464f9270ec7a8c140d1f/evidence/)。细节图仅相同区域裁切、拼版、加标签，无后期调色。

临时构建/源码工作目录已由生命周期入口回收，实际free_space_delta=2501492736 bytes；原始PNG、日志和结果包保留。没有新建模拟器、安装手机、提交Git或发布。

下一步：用户查看对照反馈；0.05已在工作区生效，观感尚未认可。
