# C1-R9 随包固定灯数据

2026-11-13。R8 新发现的字段运行时编译准备成本约240ms，本轮用已验证的R7字段字节原样资产化解决。无插值算法、精度、采样或shader改动，不重复GPU排名。

- 新资产 `QiuJi/Resources/StaticClothIrradiance-v1.bin`，1,048,576字节（包内容新增1MiB，实际压缩增量未测）。两张64×32×16 RGBA32Float连续存放；来源、尺寸、域和SHA见 [资产清单](C1-field-asset.json)。原始浮点字节无转换。
- 运行时核灯源/辐亮度身份、数据长度/SHA，读入两张只读3D纹理。字段准备本机1.4396ms，实际分配1,081,344字节；不创建GPU compute队列/管线或提交字段生成命令。该时间不含SceneKit首次消费shader编译，不等于整页进入时间。
- 实际新loader回读两张纹理与R7原字段逐字节相同；消费shader与R8实际44组材质验证使用的源码相同。原数值/画质和消费成本证据可沿用，无须重新跑一轮同内容排名。
- 缺资源、改一个字节、截断文件3种反例均拒绝加载；调用方保留原shader。正常加载后资源共享、wrapper最后owner释放通过；包内材质持有的纹理由其自身生命周期释放，未做整页退出GPU内存测量。
- 调用仍限DEBUG显式参数。Release代码不加载该数据；资源文件随包存在。非DEBUG三个改动Swift文件语法解析通过，完整Release发布未重跑。初始六段灯/采样/解析积分/台呢生成器SHA全部未变，见 [基线身份](C1-baseline-identity.json)。
- 末轮代码审查补入设备能力守卫：只有 `MTLDevice.supports32BitFloatFiltering` 为真才加载32位浮点插值字段，否则保留原解析路径。能力不能由当前Mac推定给所有iPhone；依据 [Apple能力说明](https://developer.apple.com/cn/documentation/metal/mtldevice/supports32bitfloatfiltering) 和当前iOS SDK声明。无该能力设备的实际运行未验。

原始证据：`output/render-activity-20261113/c1-asset/{missing,corrupt,truncated,valid}/result.json`。最终iOS构建、签名与包内资源验证见 [阶段交付](C1-DELIVERY.md)。未安装手机、未测温升、未取得最低iOS17实际渲染结论。
