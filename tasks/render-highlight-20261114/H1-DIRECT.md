# H1补核：PBR逐灯入口（2026-11-14）

保留PBR、C1、全部surface输入，只用`.lightingModel` modifier将`_lightingContribution.diffuse/specular`置零。三镜头各6球态均零差，normal/roughness/AO诊断亦零差。GPU六组配对中位变化低位−3.16%、近景+1.43%、俯视−1.10%，对应AA−2.47%、−0.56%、−1.21%；不满足5%收益门槛，低位AA单组还出现较大漂移，不作微小收益解释。

**关键阳性对照**：再将两个贡献强制写成`float3(10,0,10)`，三镜头各6球态仍零差。因此本夹具中该入口没有按预期影响最终画面，不能从“清零零差”推出原生逐灯贡献为零、也不能声称已删除原生光照工作。H1先前“保留PBR但直接输出emission”的10–15色阶差异仍有效，PBR下游有真实剩余贡献；具体由直接光/环境光/其他合成各占多少，本轮未分离证明。该途径结束，不接入App。

依据：本机SceneKit SDK `SCNShadable.h:524–574`及[Apple逐灯入口说明](https://developer.apple.com/documentation/scenekit/scnshadermodifierentrypoint/lightingmodel)。文档说明入口逐灯执行，但实际路径仍需阳性对照，不能只按API名称推断。

原件：

- 清零：`output/local-test-runs/42cd63b06f5e4b6783a098dbc4d0353a/evidence/`
- 紫色标记：`output/local-test-runs/bc69f7d6a93140babad8f02b980ffbf1/evidence/`

两次临时程序均已回收，图像/源码/原始时序保留。
