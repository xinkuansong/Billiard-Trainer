# 进阶卡片调整验收

2026-11-27；用户已授权实施；DR-478。

## 实现

顺序：翻袋 → 颗星解球 → 扎杆与跳球 → 翻袋练习 → 解球练习 → 扎杆练习 → 跳球练习 → K球练习 → 防守练习。两项空间专项改「答题」，综合页仍是「击球」。标题、副标题、难度、订阅与目标路由保持。

新增 coverPracticeMasseJump / coverPracticeMasseExercise / coverPracticeJumpExercise 三套独立1600×1200 sRGB图片。保留旧coverPracticeSpinAndEnglish及其他使用者。无文字烘焙，无色洗；复用原生序号和内容类型角标。

## 封面来源

source-r4包含正式源图、完整题目JSON与XCTest附件清单。assets.json记录正式图片SHA256。使用liveReference球桌、房间、球体和原相机曝光配置，由SpatialQuizPhysics复算合格示范，再用SpatialShotRendering的minimal真实碰前路径导出。扎杆取合格参考中的清晰弧线球形；跳球取首碰目标之前的真实腾空顶点；综合图用初始球位与参考抬杆。所有取景变化仅在离线导出器内，不改变App的摄像机或互动行为。

SpatialCoverExportTests.swift是归档导出源，不加入日常测试。重现时临时放入CuePhysTests现有编译文件并仅运行该类，按manifest导出附件，完成后移除；正式测试文件已恢复本轮前内容。首轮到第三轮取景作为迭代证据保留，只有source-r4接入Assets。

## 验证

- final-notch.xcresult：AtmosphereCatalogTests 11/11通过，包含70个封面资源与46个入口唯一映射/资源加载检查。
- final-notch-r2.xcresult：iPhone 13、iOS26.3.1，浅/深色原生首页截图用例通过，0/1两帧覆盖九卡及三个新封面。
- 首轮final-notch/final-compact用例本身通过，但「Dark」附件实际为浅色；目视识别后改用现有-v54.forceLight/forceDark入口。首轮Dark不计深色覆盖。
- final-compact-r2.xcresult：iPhone SE3、iOS26.3.1，浅/深色原生首页截图用例通过；采用较短慢速拖动，1/2帧完整显示三个新封面与答题标签。两台手机各一轮最终UI方法执行通过，共覆盖4种尺寸/外观组合。原图目视：内容角标未盖住母球/黑八，九卡顺序正确，防守末位。
- verify-gate通过；git diff --check通过。

所有生产差异限于卡片顺序、类型与封面映射/资源；changes.patch以任务开始时备份比较，未回退共享工作区既有变更。题库与运行时物理、渲染、交互未改。真机、iPad及用户最终观感未验。

## 现场与证据

受管构建 fbd6d36b806a4616b388f82d6274906d 复用完成后回收work，保留结果包/原图/日志。不删除模拟器，不移除既有保护或数据。
