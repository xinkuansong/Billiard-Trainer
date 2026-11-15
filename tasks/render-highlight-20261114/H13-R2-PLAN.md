# H13 R2：固定漫反射移至顶点与CPU分支补齐

R1现行完整材质诊断显示低位wood约0.120ms、legs约0.074ms GPU差值，俯视分别0.056/0.054ms；各6组AB方向一致。room约1%，不作为优先。它们是完全替换着色的诊断，非可发布收益；低位AA存在离群原样保留。球影变化0.007–0.009ms、帧后扫描约0.013–0.015ms，绝对成本小。R1 camera标记usesTwoViewPoseControl=false，viewport绕过现行窗口转换；两项不得用来判定当前相机成本，R2通过生产configurePlayerCameraControls(daily:true)补齐并强断言。

本轮两个对象各用同一候选：仅把固定灯解析漫反射从逐像素移至顶点，经float3 varying插值；木台边高光与粗糙度逐像素保留，几何、纹理、色彩和其他材质不改。此为插值近似，不是数学等价，也不是跨帧缓存。使用同一生产解析公式与世界变换，vertex函数单独改名前缀以免与surface重复定义。

先三机位AA和恢复零差，新增差异最大≤1/255才计时；不过画质不为速度放行。通过后按R1的6组AA/AB时序，不改门槛，不删离群；目标low/overview>max(5%,absAA)、near非退化。成立才扩展颜色/机位/动态边界及生产接入；不成立最多一次有依据修订。原生selector实际执行数1、0失败/跳过，可能通过研究测试但候选因画质淘汰，两者分开。

API依据：本机Xcode iPhoneOS SDK SCNShadable.h 的geometry/model空间、normalTransform和varyings合同；[Apple shader modifier文档](https://developer.apple.com/documentation/scenekit/scnshadable)。这是新增材质计算路径研究，无页面交互合同变更。
