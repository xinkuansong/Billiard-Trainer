"""Angle comparison from matching archived two-ball polylines. No B or physics run."""
from pathlib import Path
import collections, gzip, hashlib, html, json, math
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/k-ball-middle-rails-20261029'
OLD=ROOT/'output/two-ball-parameter-consumer-20261026/before/QiuJi/Resources/TwoBallBank'
NOW=ROOT/'QiuJi/Resources/TwoBallBank'
OUT.mkdir(exist_ok=True);(OUT/'images').mkdir(exist_ok=True)
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(FONT,n)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old_index=json.loads((OLD/'index.json').read_text());new_index=json.loads((NOW/'index.json').read_text())
G=old_index['geometry'];R=G['radius'];HX=G['length']/2;HZ=G['width']/2
bindings={};events=[];unmeasurable=[]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def sub(a,b):return [a[k]-b[k] for k in (0,1)]
def basis(p):
    if abs(abs(p[1])-(HZ-R))<.001:return [1,0],[0,-1 if p[1]>0 else 1]
    assert abs(abs(p[0])-(HX-R))<.001
    return [0,1],[-1 if p[0]>0 else 1,0]
def angle(v,t,n):return math.degrees(math.atan2(abs(dot(v,n)),abs(dot(v,t))))
def clipped(points,limit=.35):
    result=[points[0]];length=0
    for a,b in zip(points,points[1:]):
        step=math.dist(a,b)
        if length+step>limit:
            u=(limit-length)/step;result.append([a[k]+u*(b[k]-a[k]) for k in (0,1)]);break
        result.append(b);length+=step
    return result
middleLayouts={x['id'] for x in old_index['layouts'] if x['board']['pocket'] in (4,5) and 10<=x['board']['angle']<=45}
scanShards=sorted({x['shard'] for x in old_index['layouts'] if x['id'] in middleLayouts})
print('MIDDLE SCAN',len(middleLayouts),'layouts',len(scanShards),'shards',flush=True)
for scanNumber,shard in enumerate(scanShards):
    if scanNumber%100==0:print('SCAN',scanNumber,'/',len(scanShards),flush=True)
    tables=[]
    for root,index in [(OLD,old_index),(NOW,new_index)]:
        p=root/(shard+'.jsonl.gz');digest=sha(p)
        assert digest==next(x['sha256'] for x in index['shards'] if x['name']==shard)
        bindings[str(p.relative_to(ROOT))]=digest
        tables.append({d['id']:d for d in map(json.loads,gzip.open(p,'rt'))})
    for identity,d in tables[0].items():
        if identity not in middleLayouts or identity not in tables[1]:continue
        current=tables[1][identity];assert current['board']==d['board']
        routes={r['id']:r for r in current['routes']}
        for r in d['routes']:
            if r['comboIndex'] not in routes:continue
            cur=routes[r['comboIndex']]
            assert [r['velocity'],r['spinX'],r['spinY'],r['strikeDirection']]==[cur['v'],cur['sx'],cur['sy'],cur['dir']]
            track=r['trajectory2mm'];pts=[p[1:] for p in track['points']];cushions=track['cushions']
            assert [e['cushionID'] for e in cushions]==cur['rails']
            assert track['timeOrigin']=='firstTargetContact' and track['maxDeviationMeters']<=.002
            for j,e in enumerate(cushions[:3]):
                i=e['pointIndex']
                if j==1:continue
                if i==0 or i==len(pts)-1:continue
                pre,hit,post=pts[i-1:i+2];lens=[math.dist(pre,hit),math.dist(hit,post)]
                if min(lens)<=1e-8:continue
                if j==0 and min(lens)<.06:continue
                t,n=basis(hit);incoming=sub(hit,pre);outgoing=sub(post,hit)
                if not (dot(incoming,n)<0 and dot(outgoing,n)>0):
                    unmeasurable.append(dict(key=f'{identity}/{r["comboIndex"]}/{j+1}',reason='Archived adjacent secants do not resolve incoming/outgoing normal signs',points=[pre,hit,post],normal=n))
                    continue
                if dot(incoming,t)<0:t=[-v for v in t]
                lo=cushions[j-1]['pointIndex'] if j else 0
                hi=cushions[j+1]['pointIndex'] if j+1<len(cushions) else len(pts)-1
                before=clipped(list(reversed(pts[lo:i+1])))
                after=clipped(pts[i:hi+1])
                def local(p):
                    delta=sub(p,hit);return [dot(delta,t),dot(delta,n)+R]
                events.append(dict(key=f'{identity}/{r["comboIndex"]}/{j+1}',layout=identity,board=d['board'],route=r,
                    railOrdinal=j+1,pointIndex=i,railID=e['cushionID'],inAngle=angle(incoming,t,n),outAngle=angle(outgoing,t,n),
                    adjacentLengths=lens,shortAngleSegment=min(lens)<.06,tangent=t,inward=n,contact=hit,
                    localIn=list(reversed([local(p) for p in before])),localOut=[local(p) for p in after],
                    segmentIn=[local(pre),[0,R]],segmentOut=[[0,R],local(post)]))

# Separate provisional criteria for before/after K; not validated human difficulty.
def length(points):return sum(math.dist(a,b) for a,b in zip(points,points[1:]))
filters={'maxRailOrdinal':3,'maxVelocity':3.0,'maxAbsSideSpin':.15,'maxAbsVerticalSpin':.5,
         'maxPrefixMetersByRail':{'1':2.5,'2':2.5,'3':3.5},'minIncomingLegMeters':.4,
         'minPriorLegMeters':.4,'minPriorRailPocketDistanceMeters':.18,
         'afterMinOutgoingLegMeters':.4,'afterMinRemainingMeters':.6,'nearObservationPocketWarningMeters':.18}
reviewAudit=[];eligibleByAxis={'inAngle':[],'outAngle':[]}
pockets=[[-HX,-HZ],[HX,-HZ],[-HX,HZ],[HX,HZ],[0,-HZ],[0,HZ]]
for e in events:
    r=e['route'];pts=[p[1:] for p in r['trajectory2mm']['points']];i=e['pointIndex'];cs=r['trajectory2mm']['cushions'];j=e['railOrdinal']-1
    indices=[0]+[c['pointIndex'] for c in cs[:j+1]]
    prefixLegs=[length(pts[a:b+1]) for a,b in zip(indices,indices[1:])]
    hi=cs[j+1]['pointIndex'] if j+1<len(cs) else len(pts)-1
    e['reviewMetrics']={'prefixMeters':length(pts[:i+1]),'remainingMeters':length(pts[i:]),
        'incomingLegMeters':prefixLegs[-1],'outgoingLegMeters':length(pts[i:hi+1]),
        'minPriorLegMeters':min(prefixLegs[:-1]) if j else None,
        'minPriorRailPocketDistanceMeters':min(math.dist(pts[k],p) for k in indices[1:-1] for p in pockets) if j else None,
        'observationPocketDistanceMeters':min(math.dist(pts[i],p) for p in pockets)}
    m=e['reviewMetrics']
    common={'velocity':r['velocity']<=filters['maxVelocity'],
      'sideSpin':abs(r['spinX'])<=filters['maxAbsSideSpin'],'verticalSpin':abs(r['spinY'])<=filters['maxAbsVerticalSpin'],
      'prefixLength':m['prefixMeters']<=filters['maxPrefixMetersByRail'][str(j+1)],
      'shortIncomingLeg':m['incomingLegMeters']>=filters['minIncomingLegMeters'],
      'shortPriorLeg':j==0 or m['minPriorLegMeters']>=filters['minPriorLegMeters'],
      'nearPriorPocket':j==0 or m['minPriorRailPocketDistanceMeters']>=filters['minPriorRailPocketDistanceMeters']}
    e['eligibility']={}
    for axis in eligibleByAxis:
        checks=dict(common)
        if axis=='outAngle':checks.update(shortOutgoingLeg=m['outgoingLegMeters']>=filters['afterMinOutgoingLegMeters'],shortRemainder=m['remainingMeters']>=filters['afterMinRemainingMeters'])
        e['eligibility'][axis]={'passed':all(checks.values()),'reasons':[k for k,v in checks.items() if not v]}
        if all(checks.values()):eligibleByAxis[axis].append(e)
    e['nearObservationPocket']=m['observationPocketDistanceMeters']<filters['nearObservationPocketWarningMeters']
    reviewAudit.append({'key':e['key'],'railOrdinal':e['railOrdinal'],**e['eligibility']})

summary={}
for ordinal in (1,3):
 ev=[e for e in events if e['railOrdinal']==ordinal]
 for axis in ('inAngle','outAngle'):
  good=[e for e in ev if e['eligibility'][axis]['passed'] and e[axis]<=45]
  summary[f'{ordinal}-{axis}']=dict(scanned=len(ev),passed=len(good),layouts=len({e['layout'] for e in good}),rejections=dict(collections.Counter(reason for e in ev for reason in e['eligibility'][axis]['reasons']+(['angle>45'] if e[axis]>45 else []))))
good=[e for e in events if any(e['eligibility'][a]['passed'] and e[a]<=45 for a in ['inAngle','outAngle'])]
(OUT/'scan-pool.json').write_text(json.dumps(good))
(OUT/'scan-audit.json').write_text(json.dumps(dict(summary=summary,unmeasurable=unmeasurable,layouts=len(middleLayouts),shards=len(scanShards),filters=filters,bindings=bindings,archiveIndexSHA256=sha(OLD/'index.json'),currentIndexSHA256=sha(NOW/'index.json')),indent=2))
print(json.dumps(summary,ensure_ascii=False),flush=True)
