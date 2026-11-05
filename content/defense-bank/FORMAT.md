# defense-parameters-v1

本合同用于20题样例与5698候选的后续全量包。它借鉴TwoBallBank参数分片结构，但有独立schema及policy，不冒充TwoBallLayout。

## 包结构

`index.json`：schema、policyVersion、physicsModel、assessmentVersion、coordinateSystem、geometry、sourceFingerprints、counts、shards、questions、fingerprint。

- schema=`defense-parameters-v1`，physicsModel=`planarReference`。
- policyVersion=`pure-defense-cut60-rails1-total2-dual008-10-v1`。
- counts.inputs是已处理球形总数；questions是有参考的题数；references为不同出杆数。
- shards项含name（无扩展名）、压缩文件sha256、bytes。文件为`name.jsonl.gz`，每行一个完整题目；每片最多100题，按kind分片。
- questions项为id/kind/shard/line，line从0计数。id=`kind:sourceFormationID`；不同球权类别可以有相同几何，不能只按坐标合并。
- fingerprint=删除fingerprint字段后的index，按Python json.dumps(sort_keys=True,separators=(',',':'),ensure_ascii=False,allow_nan=False)编码UTF8后SHA256。跨语言消费者至少校验固定schema/policy及分片SHA，包指纹作为身份；不靠另一套浮点JSON序列化重算指纹。
- sourceFingerprints记录样本、生产源、资产、研究源和求解政策文件的哈希。对应manifest随包保留。不得只修改版本字符串冒充重新物理验证。
- coverage.json记录输入总覆盖（found/inaccessible/not-found），不作为成功题列表。未来运行错误不会伪装成not-found，整次构建应失败并保留failure.json。

## 单题

字段：id、sourceFormationID、sampleID、kind、cue、balls、ownBallNumber、opponentBallNumber、references。

- kind: one / two_black / two_own / three。依次为双方8、我8对9、我1对8、我1对9且剩黑8。
- cue和balls[].position均为原始`[x,z]`米制；台面中心为0，X为长边方向，Z为短边方向，Y向上。母球0号只用于结果/事件标识，不放入初态balls列表。球心Y在场景中取surfaceY+radius。
- 桌内尺寸2.54×1.27m，R=0.028575m；参数不量化。横桌/竖桌的屏幕轴由现有渲染器处理，数据不随方向翻转。
- sourceFormationID为源库身份；sampleID只是本轮图册/运行追踪号，不代替稳定id。

## 参考解

- id：仅基于parameters的规范JSON SHA256，在题内唯一。跨题标识必须用question.id + reference.id。
- parameters：direction `[x,z]`为实际入射方向；velocity m/s；spinX/spinY为引擎内部打点值，不是屏幕显示百分比。当前spinX全为0，高低杆沿引擎符号。
- tactics：block / distance / cue-rail / target-rail / angle / remove-threat / pot-opponent。同一出杆允许多个标签。
- effect：fullDirectBlock、score（100或null）、opponentBallNumber（终态合法目标）、cueToleranceDegrees、comfort。容错为对方六袋最大的母球瞄准窗口；comfort为六袋最高代表舒适分，两个极值不保证来自同一袋。参数门槛：全挡，或1e-6°<容错≤0.008°且舒适<10；另排除选袋覆盖疑点。
- execution：firstContactCutDegrees≤60、projectedThicknessFraction=1−sin(切角)、mainCushionCount≤2、mainCushionsByBall每球≤1、totalTravelMeters（recorder采样折线总长）。只把主库索引0–5计为主库，jaw不计入此限额；不能据此称实桌一定好打。
- selectionProbes：四个单变量检查（方向±0.1°、速度×0.95/1.05）；status为legal/inaccessible/too-thin或合法性/路线拒绝原因，qualifies为是否同时满足执行及效果门槛；tactics为仍成立的思路。此集合用于选解，不作独立成功率。
- expected.finalBalls：模拟终态球坐标，含落袋球的位置；画桌面终态时必须排除pocketedBallNumbers。
- expected.events：有序数组；kind为ballBall/cushion/pocket，ballNumbers为参与者（0为母球），timeSeconds从出杆开始，railIndex/pocketIndex按类型可选。主库编号为生产TableGeometry线段索引，袋口编号为生产schema，禁止由可见字母反推。事件顺序用于判断先后，同一timeSeconds不应重排。

参考顺序：四探针合格数降序；同等优先完整遮挡，再总行程短，最后id作稳定顺序。保持参数精度与顺序；消费者核验可以排除失效参考，不在线重新搜索或悄悄替换题面。

## 验证边界

pilot-v1来自先前已完整重放校验的44参考，导出又核对所有初态/方向/力度/球权及事件约束。新包不含轨迹，首次页面重放必须验证真实消费链；数据导出/DTO解码通过不等于页面/真机/实桌验收。另一个会话不应直接将研究预览图当训练成功判据。
