# UR-20261002：桌参照轨道 v1.5 原生画面审查

状态：本轮TP开发切片附条件可试用；FP遗留、完整C/S/V与生产替换未放行。主控逐张实看46原图，独立QA另审17连续轨道图和18球形图；功能记录不自动等于视觉PASS。

## 来源

- iOS26.3，隔离设备08FC41A5-57EA-4262-847B-5B297CF101EB，874×402pt横屏，Light、正常字号；没有iPad/小屏/真机证据。
- `build/table-rail-camera-20261002/final-host.xcresult`：62核心0失败，UI5通过/1测试诊断错误失败。`memory-repaired.xcresult`：修正实际heading与EulerY混比后受影响UI1通过；生产源码相同。
- 最终原图为41＋5＝46张`XCUIScreen.main`完整屏幕PNG，原2622×1206横向内容与EXIF保留，未裁切/增强。[查看页](/Users/song/projects/13.billiard_trainer/output/table-rail-camera-20261002/index.html)与[screenshots.json](/Users/song/projects/13.billiard_trainer/output/table-rail-camera-20261002/screenshots.json)记录每图名称、文件、原结果包、实际姿态附件、SHA-256，复制哈希一致。全部失败尝试及旧附件仍保留。

## 用户观看任务与逐组结论

| 组 | 主控实看画面 | 判定与限制 |
|---|---|---|
| 连续轨道17帧 | 短库far、上滑4帧、near绕15/30/45/60/75/90°、长库退远4帧、斜向far、回短库far | 从全桌35°逐步降为6.78°低机位；near绕行台面主体保持中央，远側逐渐展开；长库退远与斜向far恢复六袋完整，往返姿态一致。桌角/线在near裁切是工作边界，截图只证明离散姿态。 |
| fixture0长台3帧 | TPfar/near、FP | TPfar桌外框/六袋完整，near低位桌面明显；FP母球与目标可辨，旁观蓝球落右HUD下，不能称全球无遮挡。 |
| fixture3近短库3帧 | TPfar/near、FP | TP参照不随近库母球改向，near可读桌面；FP母球下缘被蓝库沿部分切去，FL-098开放。 |
| fixture13大切角近角袋3帧 | TPfar/near、FP | TPfar全桌完整；near黄球下缘部分受前库边遮挡，不能据中心入框判完整ROI。FP母球下缘仍受真实库体遮挡。 |
| fixture4近长库3帧 | TPfar/near、FP | TP外框与中心稳定、near低位；FP母球下缘仍有真实库体遮挡，未改善本slice。 |
| fixture8中袋3帧 | TPfar/near、FP | TP桌参照保持、far全桌，near球群可辨；FP中心击球关系可辨但旁观蓝球在右HUD下。 |
| fixture12贴球3帧 | TPfar/near、FP | TPfar未自动追并球，near两轮廓透视相贴；FP两球可辨。TP不保证所有并球入口分轮廓，这是撤销本杆选向后的真实行为。 |
| 模式/记忆11帧 | FP入口/转头2、TP首次/一次上滑/斜滑2D往返3、复位1、双mode保存/恢复/FP明确归正5 | FP转头不移眼位或改杆意图；恢复画面/实际姿态一致；明确沿杆复位恢复标准；TP首次/复位全桌，2D往返恢复手动pose。此组并非完整上下文与生命周期组合。 |

原生实际诊断：短库far Y2.585m→near Y1.180m，俯角35°→6.78°，55°镜头不变；near绕行长库俯角约11.92°。台心投影横向约50%→52.63%→50%，与目视中心带相符；仅投影点，不能代替面积分布或实体遮挡判断。

## 未完成项

FP近库完整接触轮廓仍不通过；TP近端部分球/线受库体/HUD遮挡，不宣称全部对象精读。用户舒适度、滑动方向/速度手感、全部屏幕与浮层、连续真实网格和connector安全、运动速度界仍缺证。保留DEBUG开发候选；FL-099是方向实现后待视觉反馈/完整门槛，FL-098未关闭。渲染R/P未实施，没有实机帧率、温度或能耗收益结论。

原生`table-rail-joint-native.mp4`保存前一同轨道轮次的录屏；首次默认入口当时不同，不能代替最终首次入口图。尚未完成连续录屏逐段审查，不把17帧拼成连续运动证书。
