# c042 tutorial006 主线程布局忙只读审计

2026-09-08。读取主控现有 `build/quality-diagnosis/formal-004-c042-tutorial-006/app-wait-sample.txt`、同批已有日志，以及冻结004 DrillTutorialView/BTPressableStyle；未新增采样、操作UI、启动测试、修改代码或终止进程。报告写入时任务仍由主控收取真实终态，不宣布失败退出/恢复。

## 实证

- sample目标为App PID74085，com.xinkuan.qiuji，启动15:52:33.426，采样15:58:00.787。physical footprint562.2M、peak707.8M；这是一份短采样中的占用，不是6分钟连续CPU测量或泄漏证据。主控另观察约6分钟CPU100%，与此样本相容但不能用本文件独立证明整段持续时间。
- 主线程887个采样：879落在SwiftUI ViewGraph事务更新链，877经过GraphHost.flushTransactions，739在AG::Subgraph::update路径。下游明确出现LazySubviewPlacements.updateValue、LazyLayoutViewCache.commitPlacedSubviews、LazyVStackLayout initial/finalPlacement、motionVectors及sizeThatFits/StackLayout计算。计数为树内包含关系，不可相加成CPU百分比。
- 主线程不是停在XCTest测试代码的等待，也不是此样本里的网络信号量/锁睡眠；App确在SwiftUI布局/属性图更新执行。日志的AX超时至少不能简单归为“定位器找不到字”。样本没有将热栈符号化到DrillTutorialView某一业务行，所以尚不能锁定唯一视图或宣布布局无限循环已证实。
- 006日志t190.77–192.57已找到F2第五杆图片Button，ready与实际视口查询继续完成，读取到两个ScrollView实例，当前活跃视口(0,163,402,711)。t193.16为了第五杆caption的一次上拖，从(201,696.2)到(201,340.8)，速度500、hold0；t194.29等待App idle，254.32提示事件循环idle未收到；344.36/375.38/406.41为caption存在性查询及重试。此处长等待在**一次事件后的AX/idle**，不是16次reveal循环已经耗尽；不能沿003“多给微调机会”的结论处理006。

## 源码关联与假设排序

**较强的候选关联：已访问两份滚动内容仍参与同一布局树，长图LazyVStack在滚动时重新放置。** DrillTutorialView.multiFormationBody采用ZStack，ForEach(visitedFormations.sorted())；切F2只追加visited并更新selected。旧F1 ScrollView继续存在，以opacity0、allowsHitTesting(false)、accessibilityHidden(true)隐藏；这些修饰没有把旧子树从布局结构删除。每份ScrollView内VStack+header+LazyVStack，每节多行文字、结构化items和长图Button。该结构与采样的lazy placement/sizeThatFits吻合，日志也证实已有两个ScrollView实例。

但不能据此直接认定“隐藏F1就是根因”：采样没有标识哪个ScrollView的布局耗时；也可能当前F2自身长行估算/实例化、视口变化、图片布局或SwiftUI runtime触发反复更新。没有单F2对照，也没有移除旧层的受控证据。本轮不改产品条件来验证猜想。

其他相关因素：

- 长图Image.resizable.aspectRatio(.fit).frame(maxWidth:infinity)依赖宽度推导高度，节内有padding、clip、overlay，可能放大LazyStack的高度估算与重新布局成本；文本fixedSize(vertical:true)也参与尺寸计算。内容数量/图片高度能解释工作量，但不能单独解释多分钟忙。
- 每节ForEach使用offset并附`.id("formationIndex-index")`；内容ID在此次滚动中为稳定值，没有看到持续生成UUID或滚动时直接写@State的代码。不要无证据称为ID无限变化。
- ZStack上的animation(easeFast,value:selectedFormation)只以切球形为触发；滚动发生距切换已有一段时间，没有采样证明该有限动画一直不结束。BTPressableStyle仅按isPressed做0.98 scale与短动画，无repeatForever或Timer，不能仅凭它在图片按钮上就解释6分钟忙。
- 图store使用NSCache与UIImage(contentsOfFile:)；本样本热路径不是HEIC/ImageIO解码（ImageIO只出现于映像清单不是热点）。因此“704张图重复解码”或“网络加载卡住”缺乏当前支持；缓存占用与layout问题仍可能同时存在。

## 当前诊断判断

记录为“c042双球形阅读途中App主线程持续布局忙/交互不可响应的实证观察，根因未定”，不宜仍笼统归为草稿定位失败。触发动作是正常页面上的真实滚动，自动化可能影响手势速度，但没有证据证明只有测试才会触发。也不把iOS26.2模拟器单次事件外推到所有真机/runtime。

当前仍live时，由主控保留原进程采样、日志、最后成功PNG/滚动事件和最终退出/恢复状态；不要再发AX密集探测拖长同一等待。本子任务不对进程执行任何操作。若主控后续被迫中止，明确外部终止与产品自然退出不同。

## 最小后续复现边界（仅建议，不执行）

1. 先收006终态，不再以增加等待/滚动次数作为修复。将最后成功F2图片frame、caption状态与193.16动作绑定，记录布局忙持续时长及主控第二次现有采样是否同栈；持续同栈增强反复布局判断，仍不能确定是哪层。
2. 如诊断目标需要区分双层保留与单页因素，最多做两个**正常UI、相同冻结输入**短对照：A进入精讲后立刻切F2直接滚第五杆（F1仅初始访问）；B复现本轮先F1深滚后F2到第五杆。其差异是旧F1深滚布局/缓存状态，不是有无旧ScrollView（两条路径都会保留F1），必须准确命名，不能把A称为单ScrollView对照。单ScrollView隔离真正需要源码实验，不在当前只诊断授权内。
3. 每次只到该触发点，遇同类主线程忙即取证止损，由主控决定终止；不继续F1恢复、不盲重试、最多一次A/一次B。若已明确复现阻塞，记录问题即可，不需为完成两球形方法持续跑到绿。
4. 图注揭露前新增独立观察点可帮助定位，但不把删除caption滚动步骤当通过；不能放松完整图片/图注可见、回F1不滚动与位置保留oracle。未执行的回F1仍未验证。

本报告不提出产品修复、不生成资产或修改snapshot。隐藏布局假设应作为将来修复阶段的候选，不写成已证实根因；本次系统诊断可以在有界证据足够后保留问题与未覆盖项，而不无限追究SwiftUI内部实现。
