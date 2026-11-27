# W4 集成验收与范围外隔离

2026-11-27：通过。W1→W2→W3均先关闭验证再进入本批。

- 小屏SE3三个空间页侧视/方向条/25°合同1/1通过；平面真实2D/3D见W1。iPhone13全绘制族与空间流程见W2/W3。iPad双答题实际/历史/换题、三页侧视以及浅深色分离角与走位2D/3D共4/4通过。原生图已目视，见W4-small/images、W4-pad/images及review-small.png；iPad使用现有受管设备窗口状态，不声称全页面全尺寸矩阵。
- 最终几何/兼容5/5通过：主4.5mm/辅4mm，实例重建与2D/3D不丢配置，旧原语/细线/图解投影不改。全量调用分类见COVERAGE、constructors-final.txt、style-calls-final.txt；8个剩余全局引用均有排除理由。
- 为真实前后对照建立受管、写时复制的独立旧源码副本，504个App Swift SHA与本轮修改前完全一致（W4-baseline/source-verification.json）。旧副本两次构建缺配套文件：首次LiveActivity目录、第二次project.yml/.gitattributes；补齐后W4-baseline-r3的2个采集测试通过。未在共享工作区回退生产代码。
- 固定drill_c001、同一序列和尺寸、同设备采集BTTableFigure、共享静态场景、真实DrillThumbnailRenderer和SequenceVideoExporter导出帧。W4-final/image-comparison.json：图解213440像素、缩略图204800像素解码完全一致；共享场景仅7个通道差1色阶。导出s01帧差异集中在母球表面，排除明确母球ROI后只有1通道差1色阶；终局帧存在球面与桌边细小像素差异，未称整图字节一致。原图、差异区域与受控主线ROI均留存，已目视未见线宽变化。验证的是导出渲染帧；未额外重跑整段视频编码。原圆柱缩放与网格不匹配的既有边界保留。
- 47个物理/相机/特写/图解导出等受保护源码SHA与任务开始相同；W4基线与门禁后6300个素材/内容文件一致。本轮没有重烘焙题库/图像，未修改图解导出消费者。
- verify-gate通过（路由101、截图基线66、写入面212；同步和内容门禁通过），定向diff --check通过。verify-doc-size首次发现PROGRESS已有103KB，按规则原文归档11/23已接续历史，复测通过，未提高阈值。
- iPad四项测试完成后Xcode卡在附加simctl diagnose收集（600秒超时配置）。独立采样确认后只终止该诊断子进程；xcodebuild随后正常exit0并写完整xcresult，截图已导出。该附加诊断不完整，测试结果完整；诊断停止记录与采样保留。首轮过早尝试导出未封口结果包失败，最终封口后重新导出成功。

TP22、变更来源、相关页面卡、UI组件说明和DR-479已同步。真机与用户观感未验，无发布/提交。
