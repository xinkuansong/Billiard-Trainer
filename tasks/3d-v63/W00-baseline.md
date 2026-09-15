# v63 W00：实施基线与状态入口

日期：2026-09-12。用户已授权按 v63 持续实施到全部任务完成。

## 基线证据

- `output/3d-v63/W00/baseline.json`：当前 HEAD、621 个源码/测试/配置/模型文件的 SHA-256 与大小。
- `output/3d-v63/W00/source/`：对应文件的逐字节副本，可与后续本轮修改区分。
- `output/3d-v63/W00/preexisting.patch` 与 `git-status.txt`：实施前已存在的变更，保留不回退。
- `output/3d-v63/W00/state-entry-index.json`：122 处现有页面摄像头与操作入口的定位证据。它是源码索引，不是功能验收结果。
- 上轮三设备审查继续保留在 `output/3d-scope-audit-20260912/`。此次没有把历史截图重新标成新构建通过。

本轮可能写入 CameraRig / AngleSceneView / AngleTrainingScene、PositionPlay 与训练页、Physics、Media、相关测试和规格。材质、HDR、USDZ 与 v62 渲染文件保持原有工作；若接口必需变动，先核对实时 diff。CameraRig 已存在 hasPendingDamping 精度判断，后续改动必须继续覆盖其收敛语义。开始时进程检查未发现实际运行的 xcodebuild；不据此推断其他任务已经结束。

## 页面业务状态与数据流

| 页面 | 现有状态/入口 | 观看契约与回归重点 |
|---|---|---|
| 自由击球 | PositionPlayViewModel aimMode、isPlaying；play、startBreakFlow；FreePlayView pendingGame / rules | 2D/3D 不改自由/袋口意图；开球结束交付规则，沿杆与散局分开 |
| 分离角与走位 | ShotSimulationView → 同一 PositionPlayViewModel；ShotPlayCamera.setMode / focus | 两页共用观看入口；观察不改瞄准，切换不重新击球 |
| 动作库试打/序列 | PositionPlayViewModel SequencePlayState、playSequence、resumeSequence、exitSequenceMode | playing→杆间 paused→继续；切自由恢复原试打布局；相机不能改变杆序 |
| 自由走位/编排 | PositionPlayComposerView → PositionPlayViewModel；选球/袋、录制、保存输出 | 编辑草稿/序列二维快照是业务真源；3D 只看或播放 |
| 思路训练 | SiluTrainerViewModel selectTarget / selectPocket / play / resetAll；isComputing / isPlaying | 选目标区与求解结果独立于相机；只读参数不改成自由击球输入 |
| 打一走二想三 | PlanThreeViewModel selectBall / selectPocket / play；solutions/currentIndex/adjustmentDraft | 三球角色和草稿语义保持；换解与观看焦点不是同一个动作 |
| 斯诺克 | SnookerTacticsViewModel → PositionPlaySolver.solveSnooker | 当前是中八防守工具，按所选球组推断对方球组；不是另加斯诺克比赛玩法 |
| 3D 角度训练 | AimingQuizViewModel → SceneAimingView | 出题/答题/结果/下一题；理论答案不受相机影响 |
| 3D 瞄准点 | AimPointSceneTrainingView.swift 内的模型：nextQuestion / submit 后验证与自动 nextQuestion | phase/答案/物理演示分离，换题重建可见球与有效机位 |
| 角度与瞄准 | AngleDynamicViewModel selectedTargetKey / selectedPocketIndex / updateCalculations | 几何读数与拖球即时更新；观察不回写位置 |
| 分离角图谱 | SeparationAngleAtlasViewModel enabledTracks、lastPaths、后台 8 路 simulateFree | 至少一条轨迹；轨迹选择只挡画线，不改变求解；保留球号规则 |
| 加塞吃库图谱 | CushionEnglishAtlasView / ViewModel，velocity / spinY 变更与相机 binding | 多路显示与输入绑定分别保持；后续 W14 核验全部路线标签 |
| 翻袋/反射解球器（2026-09-15 补审） | BankShotViewModel / DiamondSystemViewModel → SolverStageChrome | cameraMode 与解/自由模式分离；相机操作不改球形、选中解、库数、袋口或打点；3D 观察隔离摆球 |
| 每日清台 | FreePlayView isDailyClearance → DailyClearanceController start / handleShotSettled / finishCompletion | draft/completion 为业务记录；前后台 flush/resume，切镜头不重复写杆数/犯规 |

共享链路：页面输入→现有 VM/求解器→预测/轨迹记录→AngleTrainingScene/TrajectoryPlayback；序列导出走 SequenceVideoExporter。W01 先约束观看状态，W04–W08 再替换运动记录与进袋链路，不让每页独立增加进袋动画。

## 坐标与测量样例

采用 SceneKit 世界坐标：X 为台面长轴，Z 为短轴，Y 向上，单位米。二维归一化保持 `canvasX=(x+1.270)/2.540`、`canvasY=(z+0.635)/2.540`。具体 surfaceY 从当前加载场景获取，不能把历史 0.8 写为所有消费者的常量。

生产 `TableGeometry.chineseEightBallQiuJi` 和 `AngleSceneCalculator.pocketPositions` 一致：

| ID | X/Z 符号 | 内容 ID |
|---|---|---|
| pocket_0 | −X/−Z | topLeft |
| pocket_1 | +X/−Z | topRight |
| pocket_2 | −X/+Z | bottomLeft |
| pocket_3 | +X/+Z | bottomRight |
| pocket_4 | X=0/−Z | topCenter |
| pocket_5 | X=0/+Z | bottomCenter |

Steering 上方旧编号表的 pocket_1 / pocket_2 与上述生产顺序冲突，而下方映射与代码一致。本轮已修正文档编号表，不改生产坐标。角袋交互 marker 的视觉偏移不作为物理袋心。

W05 测量采用 pocket_0 和 pocket_4 为基本样例，其余四袋验证镜像与实际模型差异。每袋记录：实际加载变换、台呢支撑边缘、袋沿截面、可见袋壁/底部几何、球半径、法线方向和来源文件哈希。用球半径尺度建立中心正入、偏心接触、切向擦沿、悬袋和返回五组，速度作为扫描输入，不预设全部进袋。旧 `output/middle-pocket-alignment-20260910/` 只提供测量方法，数值必须用当前基线重新获取。

局部区接管前保留 p/v/ω/time/pocketID；失支撑和最终捕获分别验证。初始样例不承担新碰撞模型正确性的证明；W05 数值和近袋慢放通过后才有该结论。

## 自动下一题可见性：固定输入计划

当前 `nextQuestion()` 使用随机角度、随机球号，没有可重放随机源。上轮 UI harness 只固定操作，不固定题目，故不能保证复现那一次母球不可见。

W11（必要时 W01 状态测试先行）采用依赖注入题目供应器，测试中顺序提供三组固定 AngleQuestion：中袋正向、角袋切角、贴库低视角；题目对象必须包含完整 cue/target/pocketIndex，直接保存实际生成的合法题目，不能只保存角度当作同一球形。生产默认仍随机，测试接口不改变评分。目标球号固定为 1、8、15，连续循环三次；提交方向固定为当题几何答案，另以初始中心瞄准做误差分支。

观测：题目 ID/布局、cue node hidden/opacity/scale、世界坐标与投影坐标、相机当前/目标机位、phase 和 run token；等待真实验证完成再检查，另保存过渡帧。不使用固定睡眠替代业务完成判断。旧未复现问题保留为风险，不宣称已修复。

## W00 验收与下一步

已完成：基线与已有修改备份；全部页面族业务/观看职责清单；真实生产袋口 ID 样例；换题固定输入与可见性观测方案。验证为文件哈希逐字节比对、生产映射交叉核对与入口源码读取；本批没有产品代码变更，不使用构建成功包装基线完成。

下一批 W01：共享观看状态契约与 2D/3D 无损往返。W03/W04 的共同前置 W00 已就绪；仍按批次分别实现和验收。整个 v63 目标继续进行，W01–W16/H01–H04 均未完成。
