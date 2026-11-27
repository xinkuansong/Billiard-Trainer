from pathlib import Path
import json,hashlib,math
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-85-validation-20261106'
cases=json.loads((OUT/'scenario.json').read_text())['cases'];summary=json.loads((OUT/'summary.json').read_text());recs=json.loads((OUT/'recommendations.json').read_text())
review={'priorityExamples':['85-02','85-05'],'qualifiedButComplex':['85-09'],'lowerGoalDiagnostic':['85-01'],'notes':{'85-02':'中杆0.6，两球合计2库，基础防守83.88，四次扰动最低83.4左右，8号已确认窗口2.004→5.165度','85-05':'中杆0.75，两球合计2库，靠8号遮挡达100，四次扰动均100，8号窗口0.839→1.474度','85-09':'中杆2.719、两球合计7次碰库；通过联合扰动但暂不当作简单推荐','85-01':'仅75分目标通过，合计5次碰库；作为诊断保留','85-06':'8号初始窗口8.428度，沿用不下降会很苛刻；只有1个名义候选通过自身窗口检查，不能据此判定该球形无用'},'scope':'Editorial priority among verified routes, no numerical cushion-count hard gate and no unverified feasibility rejection.'}
(OUT/'review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2))
notice='<p><b>优先看85-02和85-05：</b>均为中杆、低杆速、两球合计2库。85-09虽然通过，但合计7库，仅作诊断保留；85-01仅75分目标通过，合计5库。其余6例本轮未找到，并不证明无解。</p>'
p=OUT/'index.html';s=p.read_text();s=s.replace('<section>',notice+'<section>',1);p.write_text(s)
report=OUT/'report.md';report.write_text(report.read_text()+'\n优先看85-02、85-05。85-09通过但两球合计7库，85-01仅75分目标通过且5库，暂不当作简单推荐。其余6例仅为本轮有界搜索未找到；不得以此淘汰为物理无解。\n')
class Links(HTMLParser):
 def handle_starttag(self,tag,attrs):
  for k,v in attrs:
   if k in ('href','src') and not v.startswith('#'):assert (OUT/v).is_file(),v
Links().feed((OUT/'index.html').read_text())
paths=list(OUT.glob('85-*/recommended.png'));routes=list(OUT.glob('85-*/route-*.png'));assert len(paths)==10 and len(routes)==7
for c,row in zip(cases,recs):
 data=json.loads((OUT/c['label']/'routes.json').read_text());r=data['routes'];key=lambda a:(a['effort'],a['shot']['speed'],sum(e['kind']=='cushion' for e in a['events']),a['id'])
 for t in [75,80,85]:
  good=[x for x in r if t in x['stableThresholds']];best=min(good,key=key) if good else None;assert row['bestByThreshold'][str(t)]==(best['id'] if best else None)
 bands=json.loads((OUT/c['label']/'region-bands.json').read_text());areas=[b['area'] for b in bands];assert areas[0]>=areas[1]>=areas[2]
 for band in bands:
  assert abs(sum(b['area'] for b in band['blocks'])-band['area'])<1e-8
  assert all(b['sampledCoreRadius']>=0 for b in band['blocks'])
(OUT/'artifact-validation.json').write_text(json.dumps({'passed':True,'resultCards':10,'routeImages':7,'htmlLinksVerified':True,'regionAreaNesting':True,'simpleRepresentativeRankingVerified':True,'hashes':{str(p.relative_to(OUT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths+routes+[OUT/'index.html',OUT/'overview.png']}},indent=2))
print('PASS: ten result cards, seven replay figures, gallery links, nested areas and representative ranking')
print('Totals',{'parameters':sum(c['counts']['parameters'] for c in summary['cases']),'physics':sum(c['counts']['physics'] for c in summary['cases']),'seconds':sum(c['seconds'] for c in summary['cases'])})
