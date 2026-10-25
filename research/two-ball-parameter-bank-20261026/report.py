"""Independent audit of native replay results and a human-readable report."""
from pathlib import Path
import json,math,ast,struct,hashlib,statistics,collections,sys,subprocess
ROOT=Path(__file__).resolve().parents[2];O=ROOT/'output/two-ball-parameter-bank-20261026'
read=lambda p:json.loads(p.read_text())
write=lambda p,x:p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
f32=lambda x:struct.unpack('f',struct.pack('f',x))[0]
def stats(xs):
 xs=sorted(xs)
 return {'n':len(xs),'median':statistics.median(xs),'p95':xs[math.ceil(.95*len(xs))-1],'max':max(xs),'mean':statistics.mean(xs)}
def main():
 d=read(O/'native-results.json');pack=read(O/'pack.json');audit=read(O/'audit.json');idx=read(O/'ParameterBank/index.json');cases=read(O/'reference-cases.json');records=d['records'];qs=d['questions']
 assert d['state']=='complete' and audit['auditPassed'];assert len(qs)==len(cases)==138
 expected={(c['key'],t['comboIndex'],i) for c in cases for t in c['candidate']['top5'] for i in range(3)}
 actual={(r['question'],r['routeID'],r['repeat']) for r in records};assert actual==expected and len(records)==len(actual)==1734
 cmap={c['key']:c for c in cases};assert all(q['allGenerated'] and q['liveOrderAscending'] for q in qs)
 # Load ONLY the previously approved pure Python formula, independently from Swift.
 source=ROOT/'research/two-ball-comfort-full-20261025/run.py';tree=ast.parse(source.read_text());function=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='score');G=idx['geometry'];hx,hz,R=G['length']/2,G['width']/2,G['radius'];ns=dict(math=math,HX=hx,HZ=hz,R=R,ANCHORS=[(-hx+R,-hz+R),(hx-R,-hz+R),(-hx+R,hz-R),(hx-R,hz-R),(0,-hz),(0,hz)])
 exec(compile(ast.Module(body=[function],type_ignores=[]),str(source),'exec'),ns)
 deltas=[];deterministic={};keys=['points','rails','stop','comfort','effort','difficulty','mandatoryPointIndices','excludedAtContact']
 for r in records:
  assert r['status']=='generated' and r['railMatch'] and r['jawFree'] and r['qualified85']
  c=cmap[r['question']];old=next(x for x in c['routes'] if x['comboIndex']==r['routeID']);top=next(t for t in c['candidate']['top5'] if t['comboIndex']==r['routeID'])
  assert old['trajectory2mm']['points']==r['points'] and r['stop']==old['cueStop'];assert r['rails']==[e['cushionID'] for e in old['trajectory2mm']['cushions']];assert r['mandatoryPointIndices']==old['trajectory2mm']['mandatoryPointIndices']
  assert r['rmsCM']==0 and r['rmsFullCM']<=.5 and r['stopErrorMeters']==0
  length=sum(math.dist(a[1:],b[1:]) for a,b in zip(r['points'],r['points'][1:]));side=abs(old['spinX']);v=old['velocity']/4.5;n=len(r['rails']);sy=old['spinY']
  e=2.5*side+.8*max(sy,0)+1.2*max(-sy,0)+.8*v*v+.12*n+.06*length+.6*side*v+.15*n*side
  assert abs(e-r['effort'])<1e-12 and abs(e-old['executionDifficulty']['effort'])<1e-12
  score=ns['score'](r['stop'],list(map(f32,c['candidate']['position'])),top['pocket'])
  for native,python in [('distance','distanceScore'),('space','spaceScore'),('angle','angleScore'),('total','totalScore')]:
   delta=abs(r['comfort'][native]-score[python]);assert delta<1e-9;deltas.append(delta)
  key=(r['question'],r['routeID']);values={k:r[k] for k in keys}
  if key in deterministic:assert values==deterministic[key]
  else:deterministic[key]=values
 first=[r for r in records if r['repeat']==0];random=[r for r in first if 'random128' in r['cohorts']]
 summary={'state':'complete','parameterAuditPassed':True,'replaySampleAuditPassed':True,'fullLibraryPhysicsReplayPerformed':False,'size':pack,'sample':{'questions':len(qs),'recommendations':len(first),'repetitions':3,'totalSimulations':len(records),'randomQuestions':sum('random128' in q['cohorts'] for q in qs),'randomRecommendations':len(random),'allStatusGenerated':True,'exactCompactPoints':len(first),'exactStop':len(first),'exactOrderedRails':len(first),'sameDifficultyOrderQuestions':len(qs),'comfort85Crossings':0,'deterministicAcrossThreeRuns':True,'maxFullTrajectoryRMSMM':max(r['rmsFullCM']*10 for r in first),'maxComfortDeltaFromOffline':max(abs(r['comfortDelta']) for r in first),'maxEffortDeltaFromOffline':max(abs(r['effortDelta']) for r in first),'maxIndependentPythonScoreDelta':max(deltas),'eventOrderTieCases':sum(bool(r['excludedAtContact']) for r in first)},'timingMS':{'routeFirstPass':stats([r['totalMS'] for r in first]),'routeAllRepeats':stats([r['totalMS'] for r in records]),'randomRouteFirstPass':stats([r['totalMS'] for r in random]),'questionFirstPassIncludingRead':stats([q['loadMS']+q['pipelineMS'][0] for q in qs]),'questionFirstPassGenerationOnly':stats([q['pipelineMS'][0] for q in qs]),'randomQuestionIncludingRead':stats([q['loadMS']+q['pipelineMS'][0] for q in qs if 'random128' in q['cohorts']]),'parameterShardReadDecode':stats([q['loadMS'] for q in qs]),'indexDecode':d['indexDecodeMS'],'processFirstProfileLoad':d['profileMS'],'coldFirstQuestionIndexProfileAndReadGenerate':d['indexDecodeMS']+d['profileMS']+qs[0]['loadMS']+qs[0]['pipelineMS'][0]},'sourceFormulaSHA256':sha(source),'nativeResultSHA256':sha(O/'native-results.json'),'method':'arm64 simulator optimized serial harness; exact current solve/failure/comfort and unchanged physics; no UI or device benchmark; P95 nearest-rank'}
 # Confirm the production package stayed intact throughout the experiment.
 S=ROOT/'QiuJi/Resources/TwoBallBank';src=read(S/'index.json');assert sha(S/'index.json')==pack['sourceIndexSHA256']
 for sh in src['shards']:assert sha(S/(sh['name']+'.jsonl.gz'))==sh['sha256']
 summary['productionPackageAllHashesStillMatch']=True
 sys.path.insert(0,str(ROOT/'scripts'));from simulator_lifecycle import Manager
 closure=read(O/'device-closure.json');uid=closure['deviceAfter']['udid'];mgr=Manager()
 with mgr.state() as state:assert not state['devices'][uid].get('lease');closure['leaseReleasedVerified']=True
 assert mgr.snapshot()[uid]['state']=='Shutdown';closure['shutdownVerified']=True
 try:subprocess.check_output(['ps','-p',str(d['pid']),'-o','command='],text=True);alive=True
 except subprocess.CalledProcessError:alive=False
 assert not alive;closure['workerExitedVerified']=True
 run=Path(closure['managedEvidence']).parent;receipt=read(run/'run.json');closure['buildWorkReclaimed']=not (run/'work').exists();closure['localTestState']=receipt['state'];assert closure['buildWorkReclaimed'];write(O/'device-closure.json',closure)
 summary['hostCPU']=closure['hostCPU'];summary['simulatorOS']=d['os'];write(O/'summary.json',summary)
 t=summary['timingMS'];s=summary['sample'];before=pack['sourceTotalBytes'];after=pack['totalBytes']
 md=f'''# 两球参数题库原型与实时轨迹测试

**独立原型已完成，未替换正式题库或修改App。** 全量数据打包/审计通过；物理一致性为138题抽测，不是全库重放。

## 实际体积

|项目|字节|MB（十进制）|
|---|---:|---:|
|当前正式题库（索引＋gzip）|{before:,}|{before/1e6:.3f}|
|参数版gzip|{pack['gzipBytes']:,}|{pack['gzipBytes']/1e6:.3f}|
|参数版索引|{pack['indexBytes']:,}|{pack['indexBytes']/1e6:.3f}|
|**参数版合计**|**{after:,}**|**{after/1e6:.3f}**|

减少 **{(before-after)/before*100:.2f}%**，约原来的1/{before/after:.1f}。保留13,358初始布局、166,443题、677,488推荐引用、552,055布局内共享路线；1357个gzip分片。不是按文件系统占用块或IPA下载压缩量计数。参数包约{after/1024**2:.2f}MiB。

保留：初始C/A/下球点、B位置、两杆目标袋口、原题/路线ID、杆速/高低/左右打点、实际出杆方向、首碰后库编号顺序、推荐顺序及必要索引。无轨迹点、停点、评分、过程证明。未量化浮点、未减少题量。库序保留为低成本重放校验。完整原库及过程档案仍在原处。

## 实时速度（{closure['hostCPU']}，iPhone16 Pro Max模拟器，{d['os']}）

Swift -O单进程串行，固定哈希随机128题＋边界极值样本合并为138题/578条，全部各跑3次，共1734次。没有丢弃首次路线耗时，统计首轮，P95用nearest-rank。

|计时内容|中位毫秒|P95毫秒|最大毫秒|
|---|---:|---:|---:|
|单条推荐生成|{t['routeFirstPass']['median']:.2f}|{t['routeFirstPass']['p95']:.2f}|{t['routeFirstPass']['max']:.2f}|
|整题1–5条推荐生成＋分片读取解压|{t['questionFirstPassIncludingRead']['median']:.2f}|{t['questionFirstPassIncludingRead']['p95']:.2f}|{t['questionFirstPassIncludingRead']['max']:.2f}|
|分片读取/解压/查找部分|{t['parameterShardReadDecode']['median']:.2f}|{t['parameterShardReadDecode']['p95']:.2f}|{t['parameterShardReadDecode']['max']:.2f}|

索引解析{t['indexDecode']:.2f}ms；本次新进程首次球杆模型加载 **{t['processFirstProfileLoad']:.2f}ms**。首题把索引、模型初始化与读取/生成相加约{t['coldFirstQuestionIndexProfileAndReadGenerate']/1000:.2f}s；先前诊断运行模型初始化为1.37s，因此它不能混入稳态毫秒数后省略。可在进入训练前加载模型、后台预生成下一题，当前App尚未做此改动。

生成计时含真实出杆空间检查、三球物理、首球进袋/母球安全/碰B检查、母球路径提取、2mm压缩、舒适度/E计算；不含离线参考轨迹审计、报告JSON写出、UI渲染/切题动效、模拟器启动时间。原生计时详见native-results.json。这是模拟器数据，不代表iPhone真机速度。

## 一致性

- 全量参数与源数值逐字段一致，题目成员和推荐顺序完全一致，索引与所有源/目标分片SHA通过。
- 抽测578/578重放成功；压缩轨迹点（含时间）、停点、事件锚点与库编号顺序全部精确相同；三次重放输出确定性一致。
- 完整实时路径对原2mm折线的最大弧长RMS为 **{s['maxFullTrajectoryRMSMM']:.4f}mm**，全部低于现App的5mm准入限值。此误差是原折线近似误差，压缩点对压缩点误差为0。
- 舒适度最大差{s['maxComfortDeltaFromOffline']:.8f}分（实时B位置经过Float转换），无85分跨界；四项分数另用既有Python公式复算通过。
- E最大差{s['maxEffortDeltaFromOffline']:.3g}；138题推荐排序不变。
- 两条同刻事件边界需按**事件顺序**判断首碰前后，不能只用time≥contactTime；已沿用原库contract.normalize口径纠正测试程序。首轮诊断原证据在runs/before-event-order-normalization/，没有改物理或原库规则。

## 使用与边界

[参数题库](ParameterBank/) · [参数全量审计](audit.json) · [抽测汇总](summary.json) · [原生详细数据](native-results.json) · [设备收尾](device-closure.json)

独立格式two-ball-parameters-prototype-v1，不直接兼容当前App读取器。正式接入前仍需参数读取/版本绑定、预加载缓存、旧记录兼容和真机体验验证。去掉离线轨迹以后，App不能再直接用原离线折线做RMS准入；应保留物理成功/库序/舒适度检查，并在研发回归中保留独立参考库防止引擎漂移。尚未执行全677,488条物理重放。

受管模拟器已Shutdown，租约已释放，原生进程退出；新建编译工作区已自动回收，构建日志/哈希及诊断证据保留。正式包全量SHA在测试后再次核验未变。
'''
 (O/'README.md').write_text(md);print(json.dumps(summary,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
