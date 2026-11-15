# H1：内建材质实际贡献（2026-11-14）

基线为当前默认C1，使用实际App的`StaticClothIrradiance`构建消费者，资产/基线身份在原始任务中冻结。700×400、HDR/4xMSAA、真实USDZ/TaiNi、三个镜头和两个球uniform状态；不含真实球体几何及整页UI。

| 候选 | 低位/近景/俯视最大色阶差 | 结论 |
|---|---|---|
| 保留PBR，fragment只输出自定义emission | 13 / 10 / 15 | 粗糙度/法线/AO诊断图均逐像素相同，但最终颜色不同；证明后续管线仍有可见贡献，不能直接剥离 |
| 直接constant | 157 / 220 / 218 | 粗糙度输入最大差232/230/233，法线最大差4/22/5；明显变暗并产生尖锐亮斑，淘汰 |
| constant并显式输出emission | 157 / 220 / 218 | 与直接constant相同，说明只改最终输出不能恢复输入合同，淘汰 |

全部A/A原图零差。已查看近景原图与constant反例；当前差异显著大于预先声明的零差门槛，因此未进行性能排名，也不把省去的管线工作当作可用收益。尚未把PBR残余进一步归到特定内部灯光/IBL公式，不虚构GPU指令占比。

与旧试验区别：本轮以已启用C1为基线，通过相同粗糙度/法线/AO输出诊断区分“输入改变”与“后续管线贡献”，不是简单重复开关constant后看亮暗。Apple说明shader modifier注入既有管线，实际贡献仍以本轮对照为据：[SCNShadable](https://developer.apple.com/documentation/scenekit/scnshadable)。

原件：`output/local-test-runs/742344ccc10c4ab286152b4e7735cd54/evidence/`，含结果、源快照、原图和编译/执行日志。临时程序已自动回收，生产代码未改变。下一步H2固定灯样本几何复用。
