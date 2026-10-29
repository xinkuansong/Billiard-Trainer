# 练习页面集中整改：实施与截图复核

状态：22项需求已实现并完成本轮定向验证。标准手机最终11项、4443投影补验、小屏返回补验及iPad均通过；对应原图已审并汇入交付图册。用户视觉验收待截图反馈。

需求真源：[完整方案与逐项合同](../table-page-adaptation/PRACTICE-REVIEW-PLAN-20261029.md)。用户已确认4443靠上下长库，规划球圈按第一／第二／第三角色配色并保留全部已选球。

## 实现范围

|范围|实现|验收关注点|
|---|---|---|
|标题与按钮|项目名称统一；瞄准／练习＋点；停止两字；角度与瞄准点使用标准主动作基线|球库不挤行、辅助收起不移动主键、左右重打与其他页对齐|
|球库|七类固定题型按本题初始目标球名单展示|已进袋保留灰槽，母球不进入球库，禁止新增目标球|
|瞄准点|五档评级与ⓘ；右上均差，右侧作答；左下重打|首答冻结、重复复练不扣额度、末题保留、checkpoint向后兼容|
|训练设置|模式／玩法与动态说明，训练量和条件按序；恢复默认；演示精简|取消不落盘；三球无演示选项；蛇彩最近记录默认展开|
|中杆轨迹|分离角／两球首杆前显示，提交后不再恢复|重打、回放、换目标路线、恢复旧档不能复活|
|多球|中八残局在左，追分在右；规划球标记默认开|蓝／金／浅紫角色圈贴台面，选完后保留；第三角色虚线；关闭生效|
|4443|球组靠上下长库，球面到库边一球直径|维持组内间距与球号，2D／3D使用同一实际坐标|
|探索入口|原自由走位改分离角与走位；旧独立卡片与自由击球退役|只有一个探索入口；删辅助线／重命名／清空并重来，保留清空桌面；默认母球＋1＋8|

## 回归发现与修复

- **长标题预算**：探索页改名后原单行测量挤落球库，改用共享60pt两行预算。标准横屏断言同排；窄屏／竖屏按现行规范允许分行，所有尺寸断言窗内及互不重叠（FL-224）。
- **文案与统计**：两球自由模式的袋口由题目指定，三球仅执行前两杆、评价两次走位；说明据此修正。分离角桌面标题改用TrainingProject正式名称；瞄准点复练保存首答，JSON冻结测试使用排序编码。
- **iOS17进入球形卡顿**：几何探针已稳定，但有界`_printChanges`显示DismissAction环境持续失效。移除选择页内额外navigationDestination，以同一目的页切换选择／球桌，并由active所有者处理退出。r15小屏4443两视图＋返回、复制编辑＋返回已通过（FL-225）。
- **重开动画竞态**：r15小屏L型重开崩溃位于主线程SCNNode.hasActions，原SCNTransaction锁仍复现。r16在渲染完成回调采样动作状态，主线程只读加锁Bool；新增连续重开各三次，并复验无几何动画／长动画唤醒及完结休眠（FL-226）。
- **探索返回所有权与测试触摸**：小屏返回测试未看到父页面；r16只把dismiss上移至PositionPlayComposerView仍无效；r18由MainTabView持有者显式弹出anglePath仍未解决测试失败，不能据此认定dismiss为根因。r21保留入口退出所有权，补菜单前／菜单后独立返回、菜单关闭状态及精确坐标触摸，并通过既有DEBUG DailyLayoutProbe记录回调是否触发。r21使用真实坐标触摸，进入后直接返回及关闭菜单后返回均通过；未改生产返回行为。因此早先失败不能用来证明dismiss缺陷。试打／导入保持自身dismiss fallback。
- **跨次测试视图残留**：r15长标题回归第一种题目通过，第二种失败。保存的AX树明确显示第二种题目仍为3D：上次用例选择的视图会跨启动保留。r17曾误按renderer合同变化推断，未执行就进一步核证并纠正；r19在基准页及每种试打进入后通过真实菜单明确选择2D，保留原renderer＝stage断言，并补实际球桌投影比较。随后再切3D、返回；不改产品偏好或布局。

## 证据与覆盖

基线提交`6d233c3c4d9d05cf857a5adf2750e78bb443bb46`；原始用户截图14张已归档。证据根`output/practice-review-20261029/`保留xcresult、快照清单、附件映射、SHA与回传校验。

|批次／设备|结果|用途|
|---|---|---|
|r6 标准iPhone17Pro／iOS26.2|79通过、0失败（74逻辑＋5UI）|主要功能与45张修改截图|
|r6 小屏SE3／iOS17|3通过、1失败|40张原图；旧4443进入阻塞已由后续定位|
|r6 iPad11M4／iOS26.2|4通过、0失败|58张原图，含九入口横竖设置标题18张|
|r7 小屏／iPad|分离角最终标题两端均通过|各13张原图；小屏4443仍失败，未伪报整轮通过|
|r8 标准手机|4通过、0失败|4443、规划圈、探索及正式标题补验，23张原图|
|r15 小屏|2通过、2失败|进入阻塞已消失；发现重开崩溃与探索返回测试失败|
|r15 标准手机|8通过、1失败|功能通过；第二种试打保留3D却按2D断言，r19修正测试前置条件|
|r16 小屏|5通过、1失败|动画与两种球形各三次重开、复制编辑返回、4443返回通过；探索入口返回仍失败|
|r16 iPad|2通过、0失败|4443两视图及返回、探索菜单及返回；5张原图已审|
|r18 小屏|0通过、1失败|显式路由回调仍未解除返回失败，继续定位触摸与动作触发|
|r19 标准手机|11通过、0失败|2动画＋9UI，含四种长标题、两种球形各三次重开、编辑／菜单／规划圈|
|r21 小屏|1通过、0失败|菜单前直接返回＋关闭菜单后返回；6张原图，默认球形／菜单已审|
|r23 标准手机|1通过、0失败|4443强制3D→2D→3D往返、投影尺寸及返回通过；2张最终原图已审|

r6快照`1ddf9e7ac1c699560664d0efd6b34bebea4bb1ef2efe84987fd94d00bc0f581a`覆盖主要逻辑；最终验证快照r23为`4fe2a8da3697fdab967edfb4960438f169f08698eca100c74180aafe9a65f321`，4177个冻结输入与当前工作区SHA一致。r19以后生产仅提取路由返回方法并加既有DEBUG诊断，r22／r23只调整4443截图测试。r6以后的生产修改为AngleSceneView、CustomFormationPracticeView、PositionPlayComposerView、SeparationPracticeViewModel、MainTabView与FreePlayView；主要评分、球形几何、设置与圈标记逻辑未再变化。完整verify-gate FAIL=0。

早期失败完整保留：r2测试编码／菜单滚动；r4容量门禁仅构建未执行；r8–r14布局猜测及退出绑定尝试未解决、已撤回。诊断关键文件：4443-main-thread-sample.txt、4443-layout-probe-r9.jsonl、4443-layout-update-trace-r12.txt、compact-r15-restart-crash.ips；临时stdout／失效追踪已移除。

## 逐项交付映射

下列实现与标准手机证据已完成；跨尺寸结果与最终用户视觉接受另列，不混同。截图按最终有效批次汇入`output/practice-review-20261029/SCREENSHOTS.html`；各批次screenshots目录保留原图，manifest记录来源。

|需求|交付|证据|
|---|---|---|
|R01|统一主动作基线|2D-review-angleTraining-input、2D-review-aimPointTraining-input；UI同基线断言|
|R02|五字标题组合|2D-review-aimPointTraining-input；宽度矩阵单元测试|
|R03|卡片／页面同名|review-practice-play-cards、2D-review-accuracy-input；共用TrainingProject|
|R04|停止两字|2D-review-accuracy-stop-replay、3D-review-accuracy-stop-replay|
|R05|蛇彩默认展开|review-snake-expanded-settings；未点击折叠头即可看到空记录|
|R06|4443上下长库|review-4443-2d、review-4443-3d；物理间距断言|
|R07|固定题型精简球库|1／2／3球UI断言；review-multi-rings-2d|
|R08|五档评级与ⓘ|2D-review-aim-rating-info；阈值边界／无效值单元测试|
|R09|右侧信息与左下重打|2D-review-aim-result、2D-review-aim-retry；首答、恢复与额度测试|
|R10|角色圈及默认设置|review-multi-rings-2d／3d、review-multi-marker-setting；贴台／关闭／旧档单元测试|
|R11|首杆后不保留中杆|SeparationPracticeTests、TwoBallPracticeTests：重打／换路线／恢复后不再显示|
|R12|演示与击球过程文案|review-separation-settings-bottom|
|R13|三球、多球无演示设置|review-threeBall-settings-bottom；设置UI删项断言|
|R14|恢复默认|review-threeBall-settings-bottom、review-snake-expanded-settings|
|R15|自然语言说明|各练习settings-top原图；多球随玩法／模式计算说明|
|R16|统一分组顺序与训练模式|review-twoBall-settings-top、review-multi-settings|
|R17|中八左／追分右|review-multi-settings；保留rawValue与旧默认|
|R18|目标路线|review-twoBall-settings-top、review-separation-settings-top|
|R19|探索入口合并|review-practice-play-cards；卡片唯一断言|
|R20|菜单删项|review-composer-menu；原三项不存在且清空桌面可达|
|R21|默认球形|review-composer-default；母球＋1＋8，导入／试打优先|
|R22|自由击球入口退役|真实卡片不存在断言；旧路由不可达／兼容重定向审计|

## 边界

本轮为修改页面及共享宿主影响面的定向验证，未运行全部历史UI巡游。真机操作感、VoiceOver、系统多窗口全部组合、真实账号同步、购买与发布不在本轮通过范围。未提交或发布；用户最终视觉接受以交付截图后的反馈为准。

## 截图补验说明

r19原图审查发现一次4443俯视桌体偏小，未把该图当作最终视觉通过。补验必须读取实际球桌投影并核对stage尺寸后才截图，不以按钮ready代替画面就绪。

r22构建通过，但指定的iOS26.0运行时未安装，因此没有执行测试、没有创建成功的设备。r22b改用已登记iPhone17Pro／iOS26.2；测试误用Other查找语义为Image的stage，在尺寸断言前失败。已保存AX归档：球桌投影为[131.664,44.091,742.336,381.909]，stage为[128,42,618,342]，该时刻实际投影正常。这只是诊断证据，不冒充测试通过。

r23只修正any类型定位，保持完整尺寸约束和3D→2D→3D实际菜单操作；结果见上表。旧失败附件、日志与截图保留。

最终4443俯视投影：[131.664,44.091,742.336,381.909]，预留区域[128,42,618,342]，尺寸与边界断言通过。r19偏小图仍保留在原批次，交付图册选用r23最终原图；未将一次截图异常直接宣称为已证明的产品相机缺陷。

交付：[分类截图图册](../../output/practice-review-20261029/SCREENSHOTS.html)／[逐图文档](../../output/practice-review-20261029/SCREENSHOTS.md)。本任务模拟器租约、远端构建和冻结副本在证据回传校验后按登记流程回收；未触碰其他任务保留设备。
