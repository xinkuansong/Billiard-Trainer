# SC27 照片确认改号与退化角补验草稿

2026-09-08；仅新增独立源码/本预飞。未注册、构建、运行、操作设备或改业务。`swiftc -frontend -parse` 退出 0，只证明语法解析。先读 PHOTO-004-RESULT、现有 PhotoImport 完整已执行源码、B6-COVERAGE-AUDIT-004 第4剩余包及 geometry 技能；不重跑三目的地交付、不扩真实相机。

## 已有证据核销

原 photo-calibration001 1/1、32.175s 正常四角/长库/空标记；marks001 1/1、45.277s 母球+1号/撤销重做/确认；send-original001 1/1、77.721s 原两球三个目的地及返回已验。send001 失败44.133s发生在改号后旧_1 AX存在断言：完整图已显示蓝2、母球，旧_1外层框变成桌面大小、隐藏mesh子框残留；该失败不能删，也不能算改号交付已通过。本条只新增一个目的地“自由走位”的改号交付闭环与一个意图退化角负例。

## 精确 selector 与环境

- `QiuJiUITests/PhotoBoundaryContinuationDiagnosticUITests/testRenumberedSyntheticBallIsDeliveredToFreePositionAndReturns`
- `QiuJiUITests/PhotoBoundaryContinuationDiagnosticUITests/testIntendedCollinearCalibrationRefusesProgress`

两方法均限**原**合成图专用设备 E19E17B9-F412-49D1-9BE0-EB12E58FC8F2，不复用其他设备标签/frame。env：`QD_PHOTO_CONTINUATION_AUTH=EXISTING_QD004_SYNTHETIC_ONLY_DEVICE`、`QD_PHOTO_DEVICE_UDID` 为该UUID并与实际 SIMULATOR_UDID相等、`QD_SHOT_DIR` 绝对根；支持 TEST_RUNNER_。每方法自动新UUID目录，PNG先于完整AX；teardown在terminate前保留终态，不清沙盒/相册。失败throw或XCTest首错停止，不注册或修改原PhotoImport。

合成图复用 `archive/quality-diagnosis/inputs/photo-004-synthetic-001`，1000×800，SHA256 `6edb335b50b642b898e741d75eedd6bee9ab6805afe18dfd77bed4f5091032f3`。manifest的imported=false是创建时字段；实际addmedia记录/照片001证据另外证明后来导入。主控须核仍为原专用相册。已观察唯一label“照片, 9月08日, 17:03”与缩略框(0,292,132.9,133)严格保留。更换设备必须先重新观察，不能复制这些值。

启动普通练习入口，inMemory隔离训练库，forcePremium仅绕过已单独验证会员门控，真实guest检查；无照片confirmDemo/marks注入、无真实账号。不是本地StoreKit/免费门控测试。正常入口、照片加载、四角、标两球及撤销重做 helper从已实际运行的PhotoImport源复制到独立私有helper，不调用其test方法，不重跑三目的地。

## 坐标与真源

图像 uv 左上原点、x右/y下，显示按1000×800 aspect fit。桌面 CanvasPoint x∈[0,1]、y∈[0,.5]，scene映射与 `.kiro/steering/table-geometry.md` 同向；portrait屏幕上为+x，屏幕右为+y。`Homography.swift` 全文与 `BallExtractionView` uv/point真源已核。

数值草稿实际执行：内沿uv(.1,.25),(.9,.25),(.9,.75),(.1,.75)，长库映射((u-.1)/.8,v-.25)，母球(.3,.35)→(.25,.1)，1号(.7,.65)→(.75,.4)。仅校验合成定义；实际UI不是精确归一化坐标测量。四角标签在handle上24pt由View:243–261及原图证实；仍要求实际拖后≤2pt。原标记图像容器(12,178.7,378,528)内aspect fit后点击已知接触点；不是任意猜屏幕坐标。

## 正常链：改号后一个目的地

确认原两球 → 点击实际_1外层球frame中心 → 精确“已选1号” → 唯一paletteBall__2 → “已选2号”/桌上2颗/实际_2外层ball-sized frame且中心与原点≤2pt → 送入…/自由走位 → 真导航页、_2与cueBall外层frame、母球左下/2号右上 → 当前导航栏唯一BackButton返回 → 确认仍2颗与2号/母球。

真源 `BallExtractionViewModel.assignNumber:402–417` 保存旧position、hide旧球、show新key、更新selected/onTableKeys/history；`currentSnapshot:421–429` 只取onTableKeys且!hidden。确认View:483选中球后palette执行assignNumber。

AX依据 send001 terminal：_1外层275.4×497.9，隐藏子框10.1×10.1；_2外层/子框均10.1×10.1，cueBall外层14.7×15.1。草稿取同key首个外层并要求尺寸<30，**不拿所有同key后代的小frame冒充可见根，也不要求旧_1完全不存在**。这与原三目的地测试的ball-size约束一致，但不能独自证明像素可见/旧球已消失；主控必须完整图审蓝2、母球、无黄1，以及交付前后相对位置。返回BackButton只在当前“自由走位”导航栏唯一匹配；未知时失败取证，不猜首按钮。

## 负例：四角意图共线及精度边界

`calibrationValid`（VM:89–92）要求homography非nil且cornerResidual<1e-6；Homography.solve/squareToQuad以det或denom 1e-12为阈值。`BallExtractionView.uv:641–645` **没有clamp、吸附或精确数字输入**。不能把手势拖到边界误说成内部精确0，也不能把任意近共线当必须拒绝。

草稿正常选图到默认标定，只一次依次拖四角至同一真实图像中心x，y为图像高度比例.15/.37/.59/.81（分开避免handle重叠）。数值草稿已验证理想uv四点的squareToQuad denom严格0，因此理想模型必须拒绝。实际每次要求handle跟随≤2pt；最终先PNG/AX再读四标签x差≤.01pt，并要求下一步disabled、仍标定未到已标0颗。**AX精度仍不足以证明内部1e-12精确奇异。** 若x差不满足，是手势输入未建立；若满足但按钮enabled，保留“输入精度/产品未分”的失败，不能直接登记Homography产品错误，更不能改成近似阈值或跳过判定通过。该方法只能在真实disabled时证明本次手势形成的输入被UI拒绝；独立Homography单测才证明精确奇异数学分支。

此负例最多一次有界意图输入，不无限微调；无正常UI精确坐标入口这个限制仍保留。B6图片查看器/短库/真实相机不是本文件的完成声明；本条不核销整个SC27。

2026-09-08 boundary001：退化输入1/1通过33.904秒；改号方法失败48.094秒，原始1459文件和observer归档。实际选中2号时状态栏显示“已选2号”，count文本仅未选中分支显示；完整图是蓝2+母球，无黄1。BallExtractionView:409/420与VM.selectBall再次点同球取消选择已核。002只追加点击实际2号取消选择后再验原两球计数，不删除计数断言，不重跑已通过退化方法。
